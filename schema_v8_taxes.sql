-- UNO MONEY v8: TAXES on everything. Run AFTER schema_v7. Keeps all data. Safe to run twice.
-- Taxes: send, receive, trade, gamble (daily, on net winnings), sell, market, bank, pack, and a daily income tax.
-- All rates are admin settings (0.05 = 5%). Taxes are removed from the economy and logged in tax_log.

insert into settings (key, value) values ('tax_on','true'),('tax_send','0.02'),('tax_recv','0.01'),('tax_trade','0.03'),('tax_gamble','0.10'),('tax_sell','0.05'),('tax_market','0.03'),('tax_bank','0.05'),('tax_pack','0.05'),('tax_income','0.05')
on conflict (key) do nothing;

create table if not exists tax_log (id bigserial primary key, at timestamptz default now(), user_id uuid, kind text not null, base int not null, rate float not null, amt int not null);
alter table tax_log enable row level security;
drop policy if exists tax_read on tax_log;
create policy tax_read on tax_log for select using (user_id = auth.uid() or is_adm());
create table if not exists day_ledger (user_id uuid, day date, net int not null default 0, gamble int not null default 0, settled boolean not null default false, primary key (user_id, day));
alter table day_ledger enable row level security;

create or replace function tday() returns date language sql stable as $$ select (now() at time zone 'utc')::date $$;
create or replace function trate(k text, d float) returns float language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::float from settings where key = k), d) $$;
create or replace function tcalc(p_base int, p_key text, p_def float) returns int language sql stable security definer set search_path = public as $$
  select case when coalesce((select (value #>> '{}')::boolean from settings where key = 'tax_on'), true) then floor(p_base * trate(p_key, p_def))::int else 0 end $$;

-- take tax from a player (capped at their balance; the tax itself is not counted as income)
create or replace function take_tax(p_uid uuid, p_kind text, p_base int, p_rate float) returns int language plpgsql security definer set search_path = public as $$
declare amt int; bal int;
begin
  if not coalesce((select (value #>> '{}')::boolean from settings where key = 'tax_on'), true) then return 0; end if;
  amt := floor(p_base * p_rate)::int; if amt <= 0 then return 0; end if;
  select balance into bal from profiles where id = p_uid;
  amt := least(amt, greatest(coalesce(bal, 0), 0)); if amt <= 0 then return 0; end if;
  perform set_config('uno.notax', '1', true);
  update profiles set balance = balance - amt where id = p_uid;
  perform set_config('uno.notax', '0', true);
  insert into tax_log (user_id, kind, base, rate, amt) values (p_uid, p_kind, p_base, p_rate, amt);
  return amt;
end $$;

-- earnings tracker: every balance change adds to today's net (admin edits on other players are ignored)
create or replace function ledger_trg() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.balance = old.balance or coalesce(current_setting('uno.notax', true), '0') = '1' then return new; end if;
  if auth.uid() is not null and auth.uid() <> new.id and is_adm() then return new; end if;
  insert into day_ledger (user_id, day, net) values (new.id, tday(), new.balance - old.balance)
  on conflict (user_id, day) do update set net = day_ledger.net + (new.balance - old.balance);
  return new;
end $$;
drop trigger if exists ledger on profiles;
create trigger ledger after update of balance on profiles for each row execute function ledger_trg();

create or replace function gamble_note(d int) returns void language sql security definer set search_path = public as $$
  insert into day_ledger (user_id, day, gamble) values (auth.uid(), tday(), d) on conflict (user_id, day) do update set gamble = day_ledger.gamble + d $$;

create or replace function tax_apply(p_kind text, p_delta int) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_kind = 'gamble' then perform gamble_note(p_delta); return; end if;
  if p_delta > 0 then perform take_tax(auth.uid(), p_kind, p_delta, trate('tax_' || p_kind, case p_kind when 'sell' then 0.05 when 'bank' then 0.05 else 0.03 end)); end if;
end $$;

-- daily settlement: income tax on net gain + gamble tax on net winnings, for every finished day
create or replace function settle_tax(u uuid, incl_today boolean default false) returns int language plpgsql security definer set search_path = public as $$
declare r record; tot int := 0;
begin
  for r in select * from day_ledger where user_id = u and not settled and (day < tday() or incl_today) loop
    tot := tot + take_tax(u, 'income', greatest(r.net, 0), trate('tax_income', 0.05));
    tot := tot + take_tax(u, 'gamble', greatest(r.gamble, 0), trate('tax_gamble', 0.10));
    update day_ledger set settled = true where user_id = u and day = r.day;
  end loop;
  return tot;
end $$;
create or replace function settle_my_tax() returns int language plpgsql security definer set search_path = public as $$
begin return settle_tax(auth.uid(), false); end $$;
create or replace function admin_run_tax(p_today boolean default false) returns int language plpgsql security definer set search_path = public as $$
declare u uuid; tot int := 0;
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  for u in select id from profiles loop tot := tot + settle_tax(u, p_today); end loop;
  perform adm_log('ran daily tax, collected ' || tot);
  return tot;
end $$;

create or replace function tax_summary() returns json language sql security definer set search_path = public as $$
  select json_build_object(
    'mine', coalesce((select json_object_agg(kind, s) from (select kind, sum(amt) s from tax_log where user_id = auth.uid() group by kind) x), '{}'::json),
    'all', case when is_adm() then coalesce((select json_object_agg(kind, s) from (select kind, sum(amt) s from tax_log group by kind) y), '{}'::json) else null end,
    'today', coalesce((select json_build_object('net', net, 'gamble', gamble) from day_ledger where user_id = auth.uid() and day = tday()), json_build_object('net', 0, 'gamble', 0)),
    'recent', coalesce((select json_agg(z) from (select at, kind, base, amt from tax_log where user_id = auth.uid() order by id desc limit 8) z), '[]'::json)) $$;

-- value of a list of cards (shiny counts double) for the trade tax
create or replace function items_value(items jsonb) returns int language sql stable security definer set search_path = public as $$
  select coalesce(sum(c.val * coalesce((e->>'q')::int, 1) * case when coalesce((e->>'s')::boolean, false) then 2 else 1 end), 0)::int
  from jsonb_array_elements(items) e join cards c on c.id = (e->>'id')::int $$;

-- ---------- taxed bank transfer ----------
create or replace function send_money(p_to uuid, p_amt int, p_note text default '') returns json language plpgsql security definer set search_path = public as $$
declare sent int; me_owed int; tname text; stax int; rtax int;
begin
  perform need_ok();
  if not (cfgd('tr_on','true')#>>'{}')::boolean then raise exception 'Sending is closed right now'; end if;
  if p_to is null or p_to = auth.uid() then raise exception 'Pick another player'; end if;
  if p_amt is null or p_amt < (cfgd('tr_min','1')#>>'{}')::int then raise exception 'Amount is too small'; end if;
  if p_amt > (cfgd('tr_max','1000')#>>'{}')::int then raise exception 'Amount is over the per-send limit'; end if;
  select username into tname from profiles where id = p_to and not banned;
  if tname is null then raise exception 'That player cannot receive cards'; end if;
  select owed into me_owed from profiles where id = auth.uid();
  if (cfgd('tr_debt','true')#>>'{}')::boolean and me_owed > 0 then raise exception 'Repay your loan before sending'; end if;
  select coalesce(sum(amt),0) into sent from transfers where from_id = auth.uid() and at > now() - interval '24 hours' and not reversed;
  if sent + p_amt > (cfgd('tr_daily','500')#>>'{}')::int then raise exception 'Daily send limit reached'; end if;
  stax := tcalc(p_amt, 'tax_send', 0.02);
  update profiles set balance = balance - p_amt where id = auth.uid() and balance >= p_amt + stax;
  if not found then raise exception 'Not enough cards (you need % plus % send tax)', p_amt, stax; end if;
  perform take_tax(auth.uid(), 'send', p_amt, trate('tax_send', 0.02));
  update profiles set balance = balance + p_amt where id = p_to;
  rtax := take_tax(p_to, 'recv', p_amt, trate('tax_recv', 0.01));
  insert into transfers (from_id, to_id, amt, fee, note) values (auth.uid(), p_to, p_amt, rtax, left(coalesce(p_note,''), 60));
  perform log_it(format('sent %s cards to %s', p_amt, tname));
  return json_build_object('sent', p_amt, 'send_tax', stax, 'recv_tax', rtax);
end $$;

-- ---------- taxed trades ----------
create or replace function trade_accept(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare t trades%rowtype; fx int; tx int;
begin
  perform need_ok();
  select * into t from trades where id = p_id and status = 'open' for update;
  if not found or t.to_id <> auth.uid() then raise exception 'That offer is no longer available'; end if;
  if not (cfgd('trades_on','true')#>>'{}')::boolean then raise exception 'Trading is closed right now'; end if;
  if not items_ok(t.from_id, t.give) or not items_ok(t.to_id, t.want) then raise exception 'One side no longer has those cards'; end if;
  fx := tcalc(items_value(t.give) + t.give_money, 'tax_trade', 0.03);
  tx := tcalc(items_value(t.want) + t.want_money, 'tax_trade', 0.03);
  if (select balance from profiles where id = t.from_id) < t.give_money + fx then raise exception 'The offerer cannot afford the money and trade tax'; end if;
  if (select balance from profiles where id = t.to_id) < t.want_money + tx then raise exception 'You need % cards for the money and trade tax', t.want_money + tx; end if;
  perform move_items(t.give, t.from_id, t.to_id); perform move_items(t.want, t.to_id, t.from_id);
  update profiles set balance = balance - t.give_money + t.want_money where id = t.from_id;
  update profiles set balance = balance + t.give_money - t.want_money where id = t.to_id;
  perform take_tax(t.from_id, 'trade', items_value(t.give) + t.give_money, trate('tax_trade', 0.03));
  perform take_tax(t.to_id, 'trade', items_value(t.want) + t.want_money, trate('tax_trade', 0.03));
  update trades set status = 'done' where id = p_id;
  perform log_it('completed a trade');
end $$;

-- ---------- new games record winnings for the daily gamble tax ----------
create or replace function bet_take(p_key text, p_stake int) returns void language plpgsql security definer set search_path = public as $$
begin
  perform need_ok();
  if not (cfgd(p_key,'true')#>>'{}')::boolean then raise exception 'This game is closed right now'; end if;
  if p_stake is null or p_stake < 1 or p_stake > (cfgd('max_bet','1000')#>>'{}')::int then raise exception 'Bet between 1 and the max bet'; end if;
  update profiles set balance = balance - p_stake where id = auth.uid() and balance >= p_stake;
  if not found then raise exception 'Not enough cards'; end if;
  perform gamble_note(-p_stake);
end $$;
create or replace function bet_pay(p_stake int, p_amt int, p_game text) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_amt > 0 then update profiles set balance = balance + p_amt where id = auth.uid(); perform gamble_note(p_amt); end if;
  if p_amt >= p_stake * 5 and p_amt >= 10 then perform log_it(format('won %s in %s', p_amt, p_game)); end if;
end $$;

create or replace function open_pack(p_pack text) returns json language plpgsql security definer set search_path = public as $$
declare
  pk packs%rowtype; w float[]; n int; g int; i int; j int; m int; tot float; r float; acc float; rar int; cid int; had int; best int := 1; tries int; shiny boolean; ptax int;
  outp json[] := '{}';
begin
  perform need_ok();
  select * into pk from packs where k = p_pack and active;
  if not found then raise exception 'Unknown or closed pack'; end if;
  if (pk.starts_at is not null and now() < pk.starts_at) or (pk.ends_at is not null and now() > pk.ends_at) then raise exception 'This pack is not available right now'; end if;
  if not (cfg('packs_on')#>>'{}')::boolean then raise exception 'Packs are closed right now'; end if;
  w := pk.w; n := pk.n; g := pk.g;
  ptax := tcalc(pk.price, 'tax_pack', 0.05);
  update profiles set balance = balance - pk.price where id = auth.uid() and balance >= pk.price + ptax;
  if not found then raise exception 'Not enough cards (pack costs % + % tax)', pk.price, ptax; end if;
  perform take_tax(auth.uid(), 'pack', pk.price, trate('tax_pack', 0.05));
  for i in 1..n loop
    m := 1; if i = n and best < g then m := g; end if;
    tries := 0;
    loop
      tries := tries + 1;
      tot := 0; for j in m..6 loop tot := tot + w[j]; end loop;
      r := random() * tot; acc := 0; rar := 6;
      for j in m..6 loop acc := acc + w[j]; if r < acc then rar := j; exit; end if; end loop;
      cid := null;
      select id into cid from cards where rarity = rar and position(p_pack in packs) > 0 order by random() limit 1;
      exit when cid is not null or tries > 50;
    end loop;
    if cid is null then select id into cid from cards where position(p_pack in packs) > 0 order by random() limit 1; end if;
    if cid is null then raise exception 'This pack has no cards yet'; end if;
    select rarity into rar from cards where id = cid;
    best := greatest(best, rar);
    had := own_qty(auth.uid(), cid, false) + own_qty(auth.uid(), cid, true);
    shiny := random() < (cfgd('shiny_odds','0.02')#>>'{}')::float;
    if shiny then insert into shiny_inv values (auth.uid(), cid, 1) on conflict (user_id, card_id) do update set qty = shiny_inv.qty + 1;
    else insert into card_inv values (auth.uid(), cid, 1) on conflict (user_id, card_id) do update set qty = card_inv.qty + 1; end if;
    outp := array_append(outp, json_build_object('id', cid, 'new', had = 0, 'shiny', shiny));
    if shiny then perform log_it('pulled a SHINY card!'); end if;
  end loop;
  perform log_it(format('opened %s, best pull: %s', pk.name, (array['common','uncommon','rare','epic','legendary','MYTHIC'])[best]));
  return array_to_json(outp);
end $$;

-- ---------- wrap your existing functions (their code is untouched; the originals become <name>_raw and are locked) ----------
create or replace function tax_wrap(p_name text, p_kind text) returns text language plpgsql security definer set search_path = public as $$
declare f record; raw text := p_name || '_raw'; fwd text; callsql text; ret text;
begin
  select p.proargnames as an, p.pronargs as na, p.proretset as rs, pg_get_function_arguments(p.oid) as ad, pg_get_function_result(p.oid) as rt, pg_get_function_identity_arguments(p.oid) as ia, obj_description(p.oid, 'pg_proc') as cm
    into f from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name order by p.oid limit 1;
  if not found then return p_name || ': not found (skipped)'; end if;
  if f.cm = 'taxwrap' then return p_name || ': already wrapped'; end if;
  if f.rs then return p_name || ': returns a set (skipped)'; end if;
  if f.na > 0 then
    if f.an is null or exists (select 1 from unnest(f.an) x where x = '') then return p_name || ': unnamed args (skipped)'; end if;
    select string_agg(format('%I := %I', x, x), ', ') into fwd from unnest(f.an) x;
  else fwd := ''; end if;
  execute format('alter function public.%I(%s) rename to %I', p_name, f.ia, raw);
  execute format('revoke all on function public.%I(%s) from public, anon, authenticated', raw, f.ia);
  if f.rt = 'void' then callsql := format('perform public.%I(%s);', raw, fwd); ret := 'return;';
  else callsql := format('_r := public.%I(%s);', raw, fwd); ret := 'return _r;'; end if;
  execute format($d$create function public.%I(%s) returns %s language plpgsql security definer set search_path = public as $b$
declare _b0 int; _b1 int; %s
begin
  select balance into _b0 from profiles where id = auth.uid();
  %s
  select balance into _b1 from profiles where id = auth.uid();
  perform tax_apply(%L, coalesce(_b1, 0) - coalesce(_b0, 0));
  %s
end $b$$d$, p_name, f.ad, f.rt, case when f.rt = 'void' then '' else '_r ' || f.rt || ';' end, callsql, p_kind, ret);
  execute format('comment on function public.%I(%s) is %L', p_name, f.ia, 'taxwrap');
  execute format('grant execute on function public.%I(%s) to anon, authenticated', p_name, f.ia);
  return p_name || ': wrapped as ' || p_kind;
end $$;

do $$
declare t text; res text;
begin
  foreach t in array array['play_egg:gamble','color_spin:gamble','hl_deal:gamble','hl_guess:gamble','play_slots:gamble','create_duel:gamble','accept_duel:gamble','cancel_duel:gamble','sell_card:sell','sell_dupes:sell','take_loan:bank','trade:market'] loop
    res := tax_wrap(split_part(t, ':', 1), split_part(t, ':', 2));
    raise notice '%', res;
  end loop;
end $$;
