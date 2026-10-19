-- UNO MONEY v6: data-driven packs (8 total), +100 cards (250), bank transfers, admin log + admin tools.
-- Run AFTER schema_v5_packs.sql. Keeps all data. Supabase: SQL Editor -> New query -> paste ALL -> Run. Safe to run twice.

create or replace function is_adm() returns boolean language sql security definer set search_path = public as $$
  select coalesce((select is_admin from profiles where id = auth.uid()), false) $$;
create or replace function cfgd(k text, d jsonb) returns jsonb language sql security definer set search_path = public as $$
  select coalesce((select value from settings where key = k), d) $$;

-- ---------- admin log ----------
create table if not exists admin_log (id bigserial primary key, at timestamptz default now(), msg text);
alter table admin_log enable row level security;
drop policy if exists admin_log_read on admin_log;
create policy admin_log_read on admin_log for select using (is_adm());
create or replace function adm_log(m text) returns void language sql security definer set search_path = public as $$
  insert into admin_log(msg) values ((select username from profiles where id = auth.uid()) || ': ' || m) $$;

-- ---------- packs table ----------
create table if not exists packs (k text primary key, name text not null, n int not null, w float[] not null, g int not null default 1, col text not null default '#3aa655', price int not null, active boolean not null default true, sort int not null default 0);
alter table packs enable row level security;
drop policy if exists packs_read on packs;
create policy packs_read on packs for select using (true);

insert into packs (k, name, n, w, g, col, price, sort) values
 ('A','Skip Pack',4,array[78,19,2.7,0.3,0,0],1,'#3aa655',8,1),
 ('B','Reverse Pack',5,array[40,40,16,3.8,0.2,0],2,'#1f6fd0',28,2),
 ('C','Wild Draw Four Pack',5,array[8,32,40,16,4,0],3,'#b14fe0',100,3),
 ('D','Ultra Wild Pack',5,array[0,0,32,47,19.8,1.2],4,'#ff4fd8',300,4),
 ('E','Draw Two Pack',3,array[75,22,3,0,0,0],1,'#e5352b',15,5),
 ('F','Rainbow Crate',6,array[30,42,24,4,0,0],2,'#f7d117',60,6),
 ('G','Mega Wild Box',12,array[10,30,38,17,4.5,0.5],3,'#4ff8ff',600,7),
 ('H','Mythic Vault',5,array[0,0,0,40,52,8],5,'#ff9bf0',1500,8)
on conflict (k) do nothing;
-- carry over any price the admin set before in the old settings array
update packs p set price = (select (value->>(i-1))::int from settings, (values ('A',1),('B',2),('C',3),('D',4)) v(k,i) where key = 'pack_prices' and v.k = p.k and jsonb_array_length(value) >= i)
 where k in ('A','B','C','D') and exists (select 1 from settings where key = 'pack_prices') and price in (8,28,100,300);

-- ---------- +100 cards (151..250) ----------
insert into cards (id, name, rarity, color, val, packs)
select i,
  (array['Zippy','Glow','Mellow','Fizzy','Puddly','Sparkly','Grumbly','Wiggly','Cosmic','Rusty'])[(i-151)%10+1] || ' ' || (array['Wombat','Gecko','Yak','Moth','Lemur','Otter','Heron','Stoat','Marmot','Ibis'])[(i-151)/10%10+1],
  rar, case when rar >= 5 then 4 else i%4 end,
  case rar when 1 then 1+i%2 when 2 then 2+i%3 when 3 then 5+i%5 when 4 then 20+(i%6)*5 when 5 then 70+(i%8)*12 else 300+(i%5)*300 end,
  case when rar <= 2 then 'EFG' when rar = 3 then 'FG' when rar = 4 then 'FGH' else 'GH' end
from (select i, case when i<=180 then 1 when i<=205 then 2 when i<=225 then 3 when i<=237 then 4 when i<=245 then 5 else 6 end as rar from generate_series(151,250) i) s
on conflict (id) do nothing;
update cards set packs = packs || 'H' where rarity >= 5 and id <= 150 and position('H' in packs) = 0;

-- ---------- table-driven open_pack ----------
create or replace function open_pack(p_pack text) returns json language plpgsql security definer set search_path = public as $$
declare
  pk packs%rowtype; w float[]; n int; g int; i int; j int; m int; tot float; r float; acc float; rar int; cid int; had int; best int := 1; tries int;
  outp json[] := '{}';
begin
  perform need_ok();
  select * into pk from packs where k = p_pack and active;
  if not found then raise exception 'Unknown or closed pack'; end if;
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
    had := null;
    select qty into had from card_inv where user_id = auth.uid() and card_id = cid;
    insert into card_inv values (auth.uid(), cid, 1) on conflict (user_id, card_id) do update set qty = card_inv.qty + 1;
    outp := array_append(outp, json_build_object('id', cid, 'new', had is null));
  end loop;
  perform log_it(format('opened %s, best pull: %s', pk.name, (array['common','uncommon','rare','epic','legendary','MYTHIC'])[best]));
  return array_to_json(outp);
end $$;

-- ---------- bank transfers ----------
create table if not exists transfers (id bigserial primary key, at timestamptz default now(), from_id uuid, to_id uuid, amt int not null, fee int not null default 0, note text, reversed boolean not null default false);
alter table transfers enable row level security;
drop policy if exists transfers_read on transfers;
create policy transfers_read on transfers for select using (from_id = auth.uid() or to_id = auth.uid() or is_adm());

insert into settings (key, value) values ('tr_on','true'),('tr_fee','0'),('tr_min','1'),('tr_max','1000'),('tr_daily','500'),('tr_debt','true')
on conflict (key) do nothing;

create or replace function send_money(p_to uuid, p_amt int, p_note text default '') returns json language plpgsql security definer set search_path = public as $$
declare fee int; sent int; me_owed int; tname text;
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
  fee := floor(p_amt * (cfgd('tr_fee','0')#>>'{}')::float);
  update profiles set balance = balance - p_amt where id = auth.uid() and balance >= p_amt;
  if not found then raise exception 'Not enough cards'; end if;
  update profiles set balance = balance + (p_amt - fee) where id = p_to;
  insert into transfers (from_id, to_id, amt, fee, note) values (auth.uid(), p_to, p_amt, fee, left(coalesce(p_note,''), 60));
  perform log_it(format('sent %s cards to %s', p_amt, tname));
  return json_build_object('sent', p_amt, 'fee', fee);
end $$;

-- ---------- admin tools (all check is_adm) ----------
create or replace function admin_set2(p_key text, p_val jsonb) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  insert into settings (key, value) values (p_key, p_val) on conflict (key) do update set value = excluded.value;
  perform adm_log('set ' || p_key || ' = ' || left(p_val::text, 60));
end $$;

create or replace function admin_save_card(p_id int, p_name text, p_rar int, p_col int, p_val int, p_packs text) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  if p_rar not between 1 and 6 or p_col not between 0 and 4 or p_val < 0 or length(trim(p_name)) = 0 then raise exception 'Bad card values'; end if;
  insert into cards (id, name, rarity, color, val, packs) values (p_id, trim(p_name), p_rar, p_col, p_val, upper(p_packs))
  on conflict (id) do update set name = excluded.name, rarity = excluded.rarity, color = excluded.color, val = excluded.val, packs = excluded.packs;
  perform adm_log('saved card #' || p_id || ' ' || p_name);
end $$;

create or replace function admin_delete_card(p_id int) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  delete from card_inv where card_id = p_id; delete from cards where id = p_id;
  perform adm_log('deleted card #' || p_id);
end $$;

create or replace function admin_save_pack(p_k text, p_name text, p_n int, p_w float[], p_g int, p_col text, p_price int, p_active boolean) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  if array_length(p_w,1) <> 6 or p_n < 1 or p_n > 30 or p_price < 1 or p_g not between 1 and 6 or length(p_k) <> 1 then raise exception 'Bad pack values'; end if;
  insert into packs (k, name, n, w, g, col, price, active, sort) values (upper(p_k), p_name, p_n, p_w, p_g, p_col, p_price, p_active, coalesce((select max(sort) from packs),0)+1)
  on conflict (k) do update set name = excluded.name, n = excluded.n, w = excluded.w, g = excluded.g, col = excluded.col, price = excluded.price, active = excluded.active;
  perform adm_log('saved pack ' || upper(p_k) || ' ' || p_name);
end $$;

create or replace function admin_reverse_transfer(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare t transfers%rowtype;
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  select * into t from transfers where id = p_id and not reversed;
  if not found then raise exception 'Already reversed or missing'; end if;
  update profiles set balance = balance - (t.amt - t.fee) where id = t.to_id;
  update profiles set balance = balance + t.amt where id = t.from_id;
  update transfers set reversed = true where id = p_id;
  perform adm_log('reversed transfer #' || p_id);
end $$;

create or replace function admin_give_pack(p_uid uuid, p_pack text, p_count int default 1) returns void language plpgsql security definer set search_path = public as $$
declare pk packs%rowtype; i int; j int; cid int; rar int; tot float; r float; acc float;
begin
  if not is_adm() then raise exception 'Admins only'; end if;
  select * into pk from packs where k = p_pack; if not found then raise exception 'Unknown pack'; end if;
  for i in 1..least(p_count,20) loop
    for j in 1..pk.n loop
      tot := 0; for rar in 1..6 loop tot := tot + pk.w[rar]; end loop;
      r := random()*tot; acc := 0; rar := 6;
      for cid in 1..6 loop acc := acc + pk.w[cid]; if r < acc then rar := cid; exit; end if; end loop;
      select id into cid from cards where rarity = rar and position(p_pack in packs) > 0 order by random() limit 1;
      if cid is not null then insert into card_inv values (p_uid, cid, 1) on conflict (user_id, card_id) do update set qty = card_inv.qty + 1; end if;
    end loop;
  end loop;
  perform adm_log('gave ' || p_count || 'x ' || pk.name || ' to ' || (select username from profiles where id = p_uid));
end $$;
