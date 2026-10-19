-- UNO MONEY v3 update. Run AFTER schema_v2.sql. Keeps all your data.
-- Supabase: SQL Editor -> New query -> paste ALL -> Run.

alter table holdings add column if not exists cost int not null default 0;

insert into settings values ('g_hl','true'),('g_color','true'),('g_slots','true'),('g_duel','true') on conflict do nothing;

create table if not exists hl_games (user_id uuid primary key references profiles on delete cascade, stake int not null, card int not null);
create table if not exists duels (
  id bigserial primary key, creator uuid references profiles on delete cascade, stake int not null,
  status text not null default 'open', opponent uuid, winner uuid, at timestamptz default now());
alter table hl_games enable row level security;
alter table duels enable row level security;
drop policy if exists h1 on hl_games; drop policy if exists d1 on duels;
create policy h1 on hl_games for select to authenticated using (user_id = auth.uid());
create policy d1 on duels for select to authenticated using (true);

-- Only admins move real cards in or out
drop function if exists adjust_balance(int);
create or replace function admin_add_balance(p_uid uuid, p_delta int) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  update profiles set balance = greatest(balance + p_delta, 0) where id = p_uid;
  perform log_it(format('ADMIN %s %s cards %s %s', case when p_delta >= 0 then 'gave' else 'took' end, abs(p_delta), case when p_delta >= 0 then 'to' else 'from' end, (select username from profiles where id = p_uid)));
end $$;

-- shared stake helper for the new games
create or replace function take_stake(p_stake int, k text) returns void language plpgsql security definer set search_path = public as $$
begin
  perform need_ok();
  if not coalesce((cfg('g_' || k)#>>'{}')::boolean, true) then raise exception 'That game is closed right now'; end if;
  if p_stake < 1 or p_stake > (cfg('max_bet')#>>'{}')::int then raise exception 'Bet between 1 and %', cfg('max_bet')#>>'{}'; end if;
  update profiles set balance = balance - p_stake where id = auth.uid() and balance >= p_stake;
  if not found then raise exception 'Not enough cards'; end if;
end $$;

-- stock trades now track cost basis (for profit and loss)
create or replace function trade(p_sym text, p_qty int, p_price int) returns void language plpgsql security definer set search_path = public as $$
begin
  perform need_ok();
  if not (cfg('market_open')#>>'{}')::boolean then raise exception 'The market is closed'; end if;
  if p_qty = 0 or p_price < 1 then raise exception 'Bad trade'; end if;
  if p_qty > 0 then
    update profiles set balance = balance - p_qty * p_price where id = auth.uid() and balance >= p_qty * p_price;
    if not found then raise exception 'Not enough cards'; end if;
    insert into holdings values (auth.uid(), p_sym, p_qty, p_qty * p_price)
      on conflict (user_id, symbol) do update set qty = holdings.qty + excluded.qty, cost = holdings.cost + excluded.cost;
  else
    update holdings set cost = cost - round(cost::numeric * (-p_qty) / qty)::int, qty = qty + p_qty
      where user_id = auth.uid() and symbol = p_sym and qty >= -p_qty;
    if not found then raise exception 'You do not own that many'; end if;
    update profiles set balance = balance - p_qty * p_price where id = auth.uid();
  end if;
  perform log_it(format('%s %s %s at %s', case when p_qty > 0 then 'bought' else 'sold' end, abs(p_qty), p_sym, p_price));
end $$;

-- GAME: Higher or Lower
create or replace function hl_deal(p_stake int) returns int language plpgsql security definer set search_path = public as $$
declare c int := floor(random() * 10);
begin
  if exists (select 1 from hl_games where user_id = auth.uid()) then raise exception 'Finish your current card first'; end if;
  perform take_stake(p_stake, 'hl');
  insert into hl_games values (auth.uid(), p_stake, c);
  return c;
end $$;
create or replace function hl_guess(p_dir text) returns json language plpgsql security definer set search_path = public as $$
declare g hl_games; b int := floor(random() * 10); p float; pay int := 0; res text;
begin
  select * into g from hl_games where user_id = auth.uid() for update;
  if g.user_id is null then raise exception 'No card dealt'; end if;
  p := case when p_dir = 'high' then (9 - g.card) / 10.0 else g.card / 10.0 end;
  if p = 0 then raise exception 'That guess cannot win'; end if;
  if b = g.card then res := 'push'; pay := g.stake;
  elsif (p_dir = 'high' and b > g.card) or (p_dir = 'low' and b < g.card) then res := 'win'; pay := floor(g.stake * 0.96 / p);
  else res := 'lose'; end if;
  update profiles set balance = balance + pay where id = auth.uid();
  delete from hl_games where user_id = auth.uid();
  perform log_it(format('played higher or lower: bet %s, got back %s', g.stake, pay));
  return json_build_object('first', g.card, 'second', b, 'result', res, 'payout', pay);
end $$;

-- GAME: Color Spin
create or replace function color_spin(p_stake int, p_pick text) returns json language plpgsql security definer set search_path = public as $$
declare s int := floor(random() * 25); col text; pay int := 0;
begin
  if p_pick not in ('red','yellow','green','blue') then raise exception 'Pick a color'; end if;
  perform take_stake(p_stake, 'color');
  col := case when s = 24 then 'wild' else (array['red','yellow','green','blue'])[s % 4 + 1] end;
  if col = p_pick or col = 'wild' then pay := floor(p_stake * 34 / 10); end if;
  update profiles set balance = balance + pay where id = auth.uid();
  perform log_it(format('played color spin: bet %s, won %s', p_stake, pay));
  return json_build_object('slot', s, 'color', col, 'payout', pay);
end $$;

-- GAME: Uno Slots (symbols 1-4 colors, 5 wild, 6 plus four). About 95% payback.
create or replace function pick_sym() returns int language sql as $$
  select case when r < 16 then r / 4 + 1 when r < 18 then 5 else 6 end from (select floor(random() * 19)::int as r) x
$$;
create or replace function play_slots(p_stake int) returns json language plpgsql security definer set search_path = public as $$
declare a int := pick_sym(); b int := pick_sym(); c int := pick_sym(); m int := 0;
begin
  perform take_stake(p_stake, 'slots');
  if a = b and b = c then m := case when a <= 4 then 12 when a = 5 then 30 else 100 end;
  elsif a = b or b = c or a = c then m := 1; end if;
  update profiles set balance = balance + p_stake * m where id = auth.uid();
  perform log_it(format('played slots: bet %s, won %s', p_stake, p_stake * m));
  return json_build_object('reels', json_build_array(a, b, c), 'mult', m, 'payout', p_stake * m);
end $$;

-- GAME: Duels (player vs player coin flip, no house cut)
create or replace function create_duel(p_stake int) returns void language plpgsql security definer set search_path = public as $$
begin
  perform take_stake(p_stake, 'duel');
  insert into duels (creator, stake) values (auth.uid(), p_stake);
  perform log_it(format('opened a duel for %s', p_stake));
end $$;
create or replace function accept_duel(p_id bigint) returns json language plpgsql security definer set search_path = public as $$
declare d duels; w uuid;
begin
  select * into d from duels where id = p_id for update;
  if d.id is null or d.status <> 'open' then raise exception 'That duel is gone'; end if;
  if d.creator = auth.uid() then raise exception 'You cannot duel yourself'; end if;
  perform take_stake(d.stake, 'duel');
  w := case when random() < 0.5 then d.creator else auth.uid() end;
  update profiles set balance = balance + d.stake * 2 where id = w;
  update duels set status = 'done', opponent = auth.uid(), winner = w where id = p_id;
  perform log_it(format('accepted a duel for %s and %s', d.stake, case when w = auth.uid() then 'won' else 'lost' end));
  return json_build_object('winner', (select username from profiles where id = w), 'won', w = auth.uid(), 'stake', d.stake);
end $$;
create or replace function cancel_duel(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare d duels;
begin
  select * into d from duels where id = p_id and creator = auth.uid() and status = 'open' for update;
  if d.id is null then raise exception 'Nothing to cancel'; end if;
  update profiles set balance = balance + d.stake where id = auth.uid();
  update duels set status = 'cancelled' where id = p_id;
end $$;
create or replace function admin_cancel_duel(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare d duels;
begin perform need_admin();
  select * into d from duels where id = p_id and status = 'open' for update;
  if d.id is null then return; end if;
  update profiles set balance = balance + d.stake where id = d.creator;
  update duels set status = 'cancelled' where id = p_id;
end $$;

create or replace function admin_reset_all() returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  update profiles set balance = 0, owed = 0, forced_mult = null;
  delete from holdings where true; delete from inventory where true; delete from shop_items where true;
  delete from hl_games where true; delete from duels where true;
  perform log_it('ADMIN reset everyone'); end $$;
