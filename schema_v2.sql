-- UNO MONEY database v2
-- Run in Supabase: SQL Editor -> New query -> paste ALL -> Run.
-- Safe to run on top of v1: game data is reset, accounts are kept, the oldest account becomes admin.

drop trigger if exists on_signup on auth.users;
drop table if exists game_log, shop_items, inventory, holdings, settings cascade;
drop table if exists profiles cascade;
drop function if exists handle_new_user(), adjust_balance(int), play_egg(int), trade(text,int,int),
  list_item(text,text,int,int,int), unlist_item(bigint), buy_item(bigint,int), market_sell(bigint) cascade;

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null,
  balance int not null default 0 check (balance >= 0),
  owed int not null default 0 check (owed >= 0),
  is_admin boolean not null default false,
  banned boolean not null default false,
  forced_mult int
);
create table holdings (user_id uuid references profiles on delete cascade, symbol text, qty int not null check (qty >= 0), primary key (user_id, symbol));
create table inventory (user_id uuid references profiles on delete cascade, item text, qty int not null check (qty >= 0), primary key (user_id, item));
create table shop_items (id bigserial primary key, seller uuid references profiles on delete cascade, item text not null, fair int not null, price int not null check (price > 0), qty int not null check (qty > 0));
create table settings (key text primary key, value jsonb not null);
create table game_log (id bigserial primary key, at timestamptz default now(), username text, msg text);

alter table profiles enable row level security;
alter table holdings enable row level security;
alter table inventory enable row level security;
alter table shop_items enable row level security;
alter table settings enable row level security;
alter table game_log enable row level security;
create policy r1 on profiles for select to authenticated using (true);
create policy r2 on holdings for select to authenticated using (user_id = auth.uid());
create policy r3 on inventory for select to authenticated using (user_id = auth.uid());
create policy r4 on shop_items for select to authenticated using (true);
create policy r5 on settings for select to authenticated using (true);
create policy r6 on game_log for select to authenticated using (true);
-- No write policies: all changes go through the functions below.

insert into settings values
 ('egg_enabled','true'),('max_bet','1000'),('egg_odds','[55,22,13,7,3]'),
 ('market_open','true'),('market_mult','1'),('stock_mult','{}'),('freeze_at','0'),('demand','1'),
 ('banner','""'),('loan_enabled','true'),('loan_rate','0.1'),('loan_limit','50');

-- helpers
create function me_admin() returns boolean language sql stable security definer set search_path = public as
$$ select coalesce((select is_admin from profiles where id = auth.uid()), false) $$;
create function need_admin() returns void language plpgsql security definer set search_path = public as
$$ begin if not me_admin() then raise exception 'Admins only'; end if; end $$;
create function need_ok() returns void language plpgsql security definer set search_path = public as
$$ begin if (select banned from profiles where id = auth.uid()) then raise exception 'Your account is frozen'; end if; end $$;
create function cfg(k text) returns jsonb language sql stable security definer set search_path = public as
$$ select value from settings where key = k $$;
create function log_it(m text) returns void language sql security definer set search_path = public as
$$ insert into game_log (username, msg) values ((select username from profiles where id = auth.uid()), m) $$;

-- accounts
create function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, username, is_admin)
  values (new.id, coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1)), not exists (select 1 from profiles));
  return new;
end $$;
create trigger on_signup after insert on auth.users for each row execute function handle_new_user();

insert into profiles (id, username)
  select id, coalesce(raw_user_meta_data->>'username', split_part(email,'@',1)) from auth.users order by created_at on conflict do nothing;
update profiles set is_admin = true where id = (select id from auth.users order by created_at limit 1);

-- cards
create function adjust_balance(delta int) returns int language plpgsql security definer set search_path = public as $$
declare nb int;
begin
  perform need_ok();
  update profiles set balance = balance + delta where id = auth.uid() and balance + delta >= 0 returning balance into nb;
  if nb is null then raise exception 'Not enough cards'; end if;
  perform log_it(format('moved %s real cards %s', abs(delta), case when delta > 0 then 'in' else 'out' end));
  return nb;
end $$;

-- eggs (the game)
create function play_egg(stake int) returns json language plpgsql security definer set search_path = public as $$
declare w jsonb := cfg('egg_odds'); tot float := 0; r float; acc float := 0; mults int[] := array[0,1,2,3,10]; m int := 0; pay int; f int; i int;
begin
  perform need_ok();
  if not (cfg('egg_enabled')#>>'{}')::boolean then raise exception 'Eggs are closed right now'; end if;
  if stake < 1 or stake > (cfg('max_bet')#>>'{}')::int then raise exception 'Bet between 1 and %', cfg('max_bet')#>>'{}'; end if;
  update profiles set balance = balance - stake where id = auth.uid() and balance >= stake;
  if not found then raise exception 'Not enough cards'; end if;
  select forced_mult into f from profiles where id = auth.uid();
  if f is not null then
    m := f; update profiles set forced_mult = null where id = auth.uid();
  else
    for i in 0..4 loop tot := tot + (w->>i)::float; end loop;
    r := random() * tot;
    for i in 0..4 loop acc := acc + (w->>i)::float; if r < acc then m := mults[i+1]; exit; end if; end loop;
  end if;
  pay := stake * m;
  update profiles set balance = balance + pay where id = auth.uid();
  perform log_it(format('hatched an egg: bet %s, won %s', stake, pay));
  return json_build_object('mult', m, 'payout', pay);
end $$;

-- stocks
create function trade(p_sym text, p_qty int, p_price int) returns void language plpgsql security definer set search_path = public as $$
begin
  perform need_ok();
  if not (cfg('market_open')#>>'{}')::boolean then raise exception 'The market is closed'; end if;
  if p_qty = 0 or p_price < 1 then raise exception 'Bad trade'; end if;
  if p_qty > 0 then
    update profiles set balance = balance - p_qty * p_price where id = auth.uid() and balance >= p_qty * p_price;
    if not found then raise exception 'Not enough cards'; end if;
    insert into holdings values (auth.uid(), p_sym, p_qty) on conflict (user_id, symbol) do update set qty = holdings.qty + excluded.qty;
  else
    update holdings set qty = qty + p_qty where user_id = auth.uid() and symbol = p_sym and qty >= -p_qty;
    if not found then raise exception 'You do not own that many'; end if;
    update profiles set balance = balance - p_qty * p_price where id = auth.uid();
  end if;
  perform log_it(format('%s %s %s at %s', case when p_qty > 0 then 'bought' else 'sold' end, abs(p_qty), p_sym, p_price));
end $$;

-- shop
create function list_item(p_item text, p_fair int, p_price int, p_qty int) returns void language plpgsql security definer set search_path = public as $$
begin
  perform need_ok();
  insert into shop_items (seller, item, fair, price, qty) values (auth.uid(), p_item, p_fair, p_price, p_qty);
  perform log_it(format('listed %s x%s for %s', p_item, p_qty, p_price));
end $$;
create function unlist_item(p_id bigint) returns void language sql security definer set search_path = public as
$$ delete from shop_items where id = p_id and seller = auth.uid() $$;
create function buy_item(p_id bigint, n int) returns void language plpgsql security definer set search_path = public as $$
declare s shop_items;
begin
  perform need_ok();
  select * into s from shop_items where id = p_id for update;
  if s.id is null or n < 1 or s.qty < n then raise exception 'Not enough in stock'; end if;
  if s.seller = auth.uid() then raise exception 'That is your own item'; end if;
  update profiles set balance = balance - s.price * n where id = auth.uid() and balance >= s.price * n;
  if not found then raise exception 'Not enough cards'; end if;
  update profiles set balance = balance + s.price * n where id = s.seller;
  insert into inventory values (auth.uid(), s.item, n) on conflict (user_id, item) do update set qty = inventory.qty + excluded.qty;
  if s.qty = n then delete from shop_items where id = p_id; else update shop_items set qty = qty - n where id = p_id; end if;
  perform log_it(format('bought %s x%s for %s', s.item, n, s.price * n));
end $$;
create function market_sell(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare s shop_items;
begin
  select * into s from shop_items where id = p_id and seller = auth.uid() for update;
  if s.id is null then return; end if;
  update profiles set balance = balance + s.price where id = auth.uid();
  if s.qty = 1 then delete from shop_items where id = p_id; else update shop_items set qty = qty - 1 where id = p_id; end if;
  perform log_it(format('the market bought %s for %s', s.item, s.price));
end $$;

-- bank
create function take_loan(amt int) returns void language plpgsql security definer set search_path = public as $$
declare rate float := (cfg('loan_rate')#>>'{}')::float; lim int := (cfg('loan_limit')#>>'{}')::int; add int;
begin
  perform need_ok();
  if not (cfg('loan_enabled')#>>'{}')::boolean then raise exception 'The bank is closed'; end if;
  if amt < 1 then raise exception 'Borrow at least 1'; end if;
  add := ceil(amt * (1 + rate));
  update profiles set owed = owed + add, balance = balance + amt where id = auth.uid() and owed + add <= lim;
  if not found then raise exception 'Over the loan limit (max owed: %)', lim; end if;
  perform log_it(format('borrowed %s (owes %s more)', amt, add));
end $$;
create function repay_loan(amt int) returns void language plpgsql security definer set search_path = public as $$
begin
  perform need_ok();
  update profiles set owed = owed - amt, balance = balance - amt where id = auth.uid() and amt > 0 and amt <= owed and balance >= amt;
  if not found then raise exception 'Check your balance and how much you owe'; end if;
  perform log_it(format('repaid %s', amt));
end $$;

-- leaderboard data (everyone's holdings, so net worth can be computed)
create function leaderboard() returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
    'id', p.id, 'username', p.username, 'balance', p.balance, 'owed', p.owed,
    'hold', (select coalesce(json_object_agg(symbol, qty), '{}'::json) from holdings h where h.user_id = p.id),
    'inv', (select coalesce(json_agg(json_build_object('item', item, 'qty', qty)), '[]'::json) from inventory i where i.user_id = p.id)
  )), '[]'::json) from profiles p
$$;

-- ADMIN
create function admin_set_balance(p_uid uuid, p_amt int) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin(); update profiles set balance = greatest(p_amt, 0) where id = p_uid; perform log_it(format('ADMIN set balance of %s to %s', (select username from profiles where id = p_uid), p_amt)); end $$;
create function admin_set_owed(p_uid uuid, p_amt int) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin(); update profiles set owed = greatest(p_amt, 0) where id = p_uid; perform log_it('ADMIN set a loan'); end $$;
create function admin_set_holding(p_uid uuid, p_sym text, p_qty int) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  if p_qty <= 0 then delete from holdings where user_id = p_uid and symbol = p_sym;
  else insert into holdings values (p_uid, p_sym, p_qty) on conflict (user_id, symbol) do update set qty = excluded.qty; end if;
  perform log_it('ADMIN set shares'); end $$;
create function admin_set_item(p_uid uuid, p_item text, p_qty int) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  if p_qty <= 0 then delete from inventory where user_id = p_uid and item = p_item;
  else insert into inventory values (p_uid, p_item, p_qty) on conflict (user_id, item) do update set qty = excluded.qty; end if;
  perform log_it('ADMIN set items'); end $$;
create function admin_set_flags(p_uid uuid, p_admin boolean, p_banned boolean) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  if p_uid = auth.uid() and not p_admin then raise exception 'You cannot remove your own admin'; end if;
  update profiles set is_admin = p_admin, banned = p_banned where id = p_uid; perform log_it('ADMIN changed account flags'); end $$;
create function admin_force_egg(p_uid uuid, p_mult int) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin(); update profiles set forced_mult = p_mult where id = p_uid; end $$;
create function admin_rename(p_uid uuid, p_name text) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin(); update profiles set username = p_name where id = p_uid; end $$;
create function admin_wipe_user(p_uid uuid) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  update profiles set balance = 0, owed = 0, forced_mult = null where id = p_uid;
  delete from holdings where user_id = p_uid; delete from inventory where user_id = p_uid; delete from shop_items where seller = p_uid;
  perform log_it('ADMIN wiped a player'); end $$;
create function admin_delete_user(p_uid uuid) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  if p_uid = auth.uid() then raise exception 'You cannot delete yourself'; end if;
  delete from auth.users where id = p_uid; perform log_it('ADMIN deleted an account'); end $$;
create function admin_remove_shelf(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin(); delete from shop_items where id = p_id; end $$;
create function admin_clear_shelves() returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin(); delete from shop_items where true; perform log_it('ADMIN cleared all shelves'); end $$;
create function admin_set(p_key text, p_val jsonb) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  insert into settings values (p_key, p_val) on conflict (key) do update set value = excluded.value;
  perform log_it(format('ADMIN changed setting %s', p_key)); end $$;
create function admin_reset_all() returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  update profiles set balance = 0, owed = 0, forced_mult = null;
  delete from holdings where true; delete from inventory where true; delete from shop_items where true;
  perform log_it('ADMIN reset everyone'); end $$;
create function admin_clear_log() returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin(); delete from game_log where true; end $$;
