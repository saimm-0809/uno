-- UNO MONEY v7: shiny cards, showcase, player trading, 4 new betting games, limited-time packs, more admin tools.
-- Run AFTER schema_v6_packs_bank_admin.sql. Keeps all data. Safe to run twice.

insert into settings (key, value) values ('g_flip','true'),('g_dice','true'),('g_boxes','true'),('g_wheel','true'),('trades_on','true'),('trade_max','10000'),('shiny_odds','0.02')
on conflict (key) do nothing;

-- ---------- shiny + showcase ----------
create table if not exists shiny_inv (user_id uuid, card_id int, qty int not null default 0, primary key (user_id, card_id));
alter table shiny_inv enable row level security;
drop policy if exists shiny_read on shiny_inv;
create policy shiny_read on shiny_inv for select using (user_id = auth.uid() or is_adm());

create table if not exists showcase (user_id uuid primary key, items jsonb not null default '[]');
alter table showcase enable row level security;
drop policy if exists showcase_read on showcase;
create policy showcase_read on showcase for select using (true);

create or replace function own_qty(u uuid, cid int, sh boolean) returns int language sql security definer set search_path = public as $$
  select case when sh then coalesce((select qty from shiny_inv where user_id = u and card_id = cid), 0)
              else coalesce((select qty from card_inv where user_id = u and card_id = cid), 0) end $$;

create or replace function items_ok(u uuid, items jsonb) returns boolean language plpgsql security definer set search_path = public as $$
declare t record;
begin
  if jsonb_typeof(items) <> 'array' or jsonb_array_length(items) > 12 then return false; end if;
  for t in select (e->>'id')::int as id, coalesce((e->>'s')::boolean, false) as s, sum(coalesce((e->>'q')::int, 1)) as q from jsonb_array_elements(items) e group by 1, 2 loop
    if t.q < 1 or own_qty(u, t.id, t.s) < t.q then return false; end if;
  end loop;
  return true;
end $$;

create or replace function set_showcase(p_items jsonb) returns void language plpgsql security definer set search_path = public as $$
declare e jsonb;
begin
  perform need_ok();
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) > 3 then raise exception 'Pick up to 3 cards'; end if;
  for e in select * from jsonb_array_elements(p_items) loop
    if own_qty(auth.uid(), (e->>'id')::int, coalesce((e->>'s')::boolean, false)) < 1 then raise exception 'You do not own one of those cards'; end if;
  end loop;
  insert into showcase (user_id, items) values (auth.uid(), p_items) on conflict (user_id) do update set items = excluded.items;
end $$;

-- ---------- limited-time packs ----------
alter table packs add column if not exists starts_at timestamptz;
alter table packs add column if not exists ends_at timestamptz;
drop function if exists admin_save_pack(text, text, int, float[], int, text, int, boolean);
create or replace function admin_save_pack(p_k text, p_name text, p_n int, p_w float[], p_g int, p_col text, p_price int, p_active boolean, p_starts timestamptz default null, p_ends timestamptz default null) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  if array_length(p_w,1) <> 6 or p_n < 1 or p_n > 30 or p_price < 1 or p_g not between 1 and 6 or length(p_k) <> 1 then raise exception 'Bad pack values'; end if;
  insert into packs (k, name, n, w, g, col, price, active, sort, starts_at, ends_at) values (upper(p_k), p_name, p_n, p_w, p_g, p_col, p_price, p_active, coalesce((select max(sort) from packs),0)+1, p_starts, p_ends)
  on conflict (k) do update set name = excluded.name, n = excluded.n, w = excluded.w, g = excluded.g, col = excluded.col, price = excluded.price, active = excluded.active, starts_at = excluded.starts_at, ends_at = excluded.ends_at;
  perform adm_log('saved pack ' || upper(p_k) || ' ' || p_name);
end $$;

-- ---------- open_pack with shiny + schedule ----------
create or replace function open_pack(p_pack text) returns json language plpgsql security definer set search_path = public as $$
declare
  pk packs%rowtype; w float[]; n int; g int; i int; j int; m int; tot float; r float; acc float; rar int; cid int; had int; best int := 1; tries int; shiny boolean;
  outp json[] := '{}';
begin
  perform need_ok();
  select * into pk from packs where k = p_pack and active;
  if not found then raise exception 'Unknown or closed pack'; end if;
  if (pk.starts_at is not null and now() < pk.starts_at) or (pk.ends_at is not null and now() > pk.ends_at) then raise exception 'This pack is not available right now'; end if;
  if not (cfg('packs_on')#>>'{}')::boolean then raise exception 'Packs are closed right now'; end if;
  w := pk.w; n := pk.n; g := pk.g;
  update profiles set balance = balance - pk.price where id = auth.uid() and balance >= pk.price;
  if not found then raise exception 'Not enough cards'; end if;
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

-- ---------- trading ----------
create table if not exists trades (id bigserial primary key, at timestamptz default now(), from_id uuid, to_id uuid, give jsonb not null default '[]', want jsonb not null default '[]', give_money int not null default 0, want_money int not null default 0, status text not null default 'open');
alter table trades enable row level security;
drop policy if exists trades_read on trades;
create policy trades_read on trades for select using (from_id = auth.uid() or to_id = auth.uid() or is_adm());

create or replace function move_items(p_items jsonb, f uuid, t uuid) returns void language plpgsql security definer set search_path = public as $$
declare x record;
begin
  for x in select (e->>'id')::int as id, coalesce((e->>'s')::boolean, false) as s, sum(coalesce((e->>'q')::int, 1)) as q from jsonb_array_elements(p_items) e group by 1, 2 loop
    if x.s then
      update shiny_inv set qty = qty - x.q where user_id = f and card_id = x.id; delete from shiny_inv where user_id = f and card_id = x.id and qty <= 0;
      insert into shiny_inv values (t, x.id, x.q) on conflict (user_id, card_id) do update set qty = shiny_inv.qty + x.q;
    else
      update card_inv set qty = qty - x.q where user_id = f and card_id = x.id; delete from card_inv where user_id = f and card_id = x.id and qty <= 0;
      insert into card_inv values (t, x.id, x.q) on conflict (user_id, card_id) do update set qty = card_inv.qty + x.q;
    end if;
  end loop;
end $$;

create or replace function trade_offer(p_to uuid, p_give jsonb, p_want jsonb, p_gm int, p_wm int) returns void language plpgsql security definer set search_path = public as $$
declare mx int := (cfgd('trade_max','10000')#>>'{}')::int;
begin
  perform need_ok();
  if not (cfgd('trades_on','true')#>>'{}')::boolean then raise exception 'Trading is closed right now'; end if;
  if p_to is null or p_to = auth.uid() or not exists (select 1 from profiles where id = p_to and not banned) then raise exception 'Pick another player'; end if;
  p_gm := coalesce(p_gm, 0); p_wm := coalesce(p_wm, 0);
  if p_gm < 0 or p_wm < 0 or p_gm > mx or p_wm > mx then raise exception 'Money part must be 0 to %', mx; end if;
  if jsonb_array_length(p_give) = 0 and p_gm = 0 then raise exception 'Offer something'; end if;
  if jsonb_array_length(p_want) = 0 and p_wm = 0 then raise exception 'Ask for something'; end if;
  if not items_ok(auth.uid(), p_give) then raise exception 'You do not own what you are offering'; end if;
  if (select balance from profiles where id = auth.uid()) < p_gm then raise exception 'Not enough cards for the money part'; end if;
  if (select count(*) from trades where from_id = auth.uid() and status = 'open') >= 10 then raise exception 'You have too many open offers'; end if;
  insert into trades (from_id, to_id, give, want, give_money, want_money) values (auth.uid(), p_to, p_give, p_want, p_gm, p_wm);
end $$;

create or replace function trade_accept(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare t trades%rowtype;
begin
  perform need_ok();
  select * into t from trades where id = p_id and status = 'open' for update;
  if not found or t.to_id <> auth.uid() then raise exception 'That offer is no longer available'; end if;
  if not (cfgd('trades_on','true')#>>'{}')::boolean then raise exception 'Trading is closed right now'; end if;
  if not items_ok(t.from_id, t.give) or not items_ok(t.to_id, t.want) then raise exception 'One side no longer has those cards'; end if;
  if (select balance from profiles where id = t.from_id) < t.give_money or (select balance from profiles where id = t.to_id) < t.want_money then raise exception 'Not enough cards for the money part'; end if;
  perform move_items(t.give, t.from_id, t.to_id); perform move_items(t.want, t.to_id, t.from_id);
  update profiles set balance = balance - t.give_money + t.want_money where id = t.from_id;
  update profiles set balance = balance + t.give_money - t.want_money where id = t.to_id;
  update trades set status = 'done' where id = p_id;
  perform log_it('completed a trade');
end $$;

create or replace function trade_cancel(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
begin
  update trades set status = case when from_id = auth.uid() then 'cancelled' else 'declined' end
   where id = p_id and status = 'open' and (from_id = auth.uid() or to_id = auth.uid());
  if not found then raise exception 'That offer is no longer open'; end if;
end $$;

create or replace function admin_cancel_trade(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  update trades set status = 'cancelled' where id = p_id and status = 'open';
  perform adm_log('cancelled trade #' || p_id);
end $$;

create or replace function admin_give_shiny(p_uid uuid, p_card int) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  insert into shiny_inv values (p_uid, p_card, 1) on conflict (user_id, card_id) do update set qty = shiny_inv.qty + 1;
  perform adm_log('gave shiny #' || p_card || ' to ' || (select username from profiles where id = p_uid));
end $$;

-- ---------- new betting games (server decides everything) ----------
create or replace function bet_take(p_key text, p_stake int) returns void language plpgsql security definer set search_path = public as $$
begin
  perform need_ok();
  if not (cfgd(p_key,'true')#>>'{}')::boolean then raise exception 'This game is closed right now'; end if;
  if p_stake is null or p_stake < 1 or p_stake > (cfgd('max_bet','1000')#>>'{}')::int then raise exception 'Bet between 1 and the max bet'; end if;
  update profiles set balance = balance - p_stake where id = auth.uid() and balance >= p_stake;
  if not found then raise exception 'Not enough cards'; end if;
end $$;

create or replace function bet_pay(p_stake int, p_amt int, p_game text) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_amt > 0 then update profiles set balance = balance + p_amt where id = auth.uid(); end if;
  if p_amt >= p_stake * 5 and p_amt >= 10 then perform log_it(format('won %s in %s', p_amt, p_game)); end if;
end $$;

create or replace function play_flip(p_stake int, p_pick text) returns json language plpgsql security definer set search_path = public as $$
declare win boolean := random() < 0.5; pay int; face text;
begin
  if p_pick not in ('heads','tails') then raise exception 'Pick heads or tails'; end if;
  perform bet_take('g_flip', p_stake);
  face := case when win then p_pick when p_pick = 'heads' then 'tails' else 'heads' end;
  pay := case when win then round(p_stake * 1.9) else 0 end;
  perform bet_pay(p_stake, pay, 'Penny Flip');
  return json_build_object('face', face, 'win', win, 'payout', pay);
end $$;

create or replace function play_dice(p_stake int, p_chance int) returns json language plpgsql security definer set search_path = public as $$
declare roll int := floor(random() * 100)::int + 1; pay int;
begin
  if p_chance not between 5 and 90 then raise exception 'Chance must be 5 to 90'; end if;
  perform bet_take('g_dice', p_stake);
  pay := case when roll <= p_chance then round(p_stake * 95.0 / p_chance) else 0 end;
  perform bet_pay(p_stake, pay, 'Lucky Dice');
  return json_build_object('roll', roll, 'win', roll <= p_chance, 'payout', pay);
end $$;

create or replace function play_boxes(p_stake int, p_pick int) returns json language plpgsql security definer set search_path = public as $$
declare prize int := floor(random() * 3)::int + 1; pay int;
begin
  if p_pick not between 1 and 3 then raise exception 'Pick box 1, 2 or 3'; end if;
  perform bet_take('g_boxes', p_stake);
  pay := case when prize = p_pick then round(p_stake * 2.85) else 0 end;
  perform bet_pay(p_stake, pay, 'Mystery Boxes');
  return json_build_object('prize', prize, 'win', prize = p_pick, 'payout', pay);
end $$;

create or replace function play_wheel(p_stake int) returns json language plpgsql security definer set search_path = public as $$
declare slots float[] := array[0,0,0,0,0,0,0,0,0,0,0,0.5,0.5,1,1,1.5,2,2,10]; mult float; pay int;
begin
  perform bet_take('g_wheel', p_stake);
  mult := slots[floor(random() * 19)::int + 1];
  pay := round(p_stake * mult);
  perform bet_pay(p_stake, pay, 'Prize Wheel');
  return json_build_object('mult', mult, 'payout', pay);
end $$;
