-- Run this once in Supabase: SQL Editor -> New query -> paste -> Run

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null,
  balance int not null default 0 check (balance >= 0)
);
create table holdings (
  user_id uuid references profiles on delete cascade,
  symbol text, qty int not null check (qty >= 0),
  primary key (user_id, symbol)
);
create table inventory (
  user_id uuid references profiles on delete cascade,
  item text, emoji text, qty int not null check (qty >= 0),
  primary key (user_id, item)
);
create table shop_items (
  id bigserial primary key,
  seller uuid references profiles on delete cascade,
  item text not null, emoji text not null,
  fair int not null, price int not null check (price > 0),
  qty int not null check (qty > 0)
);

alter table profiles enable row level security;
alter table holdings enable row level security;
alter table inventory enable row level security;
alter table shop_items enable row level security;
create policy "see all profiles" on profiles for select to authenticated using (true);
create policy "see own holdings" on holdings for select to authenticated using (user_id = auth.uid());
create policy "see own inventory" on inventory for select to authenticated using (user_id = auth.uid());
create policy "see all shop items" on shop_items for select to authenticated using (true);
-- No insert/update/delete policies: everything changes only through the functions below.

create function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, username) values (new.id, new.raw_user_meta_data->>'username');
  return new;
end $$;
create trigger on_signup after insert on auth.users for each row execute function handle_new_user();

-- Add (+) or remove (-) cards when you physically trade real Uno cards
create function adjust_balance(delta int) returns int language plpgsql security definer set search_path = public as $$
declare nb int;
begin
  update profiles set balance = balance + delta where id = auth.uid() and balance + delta >= 0 returning balance into nb;
  if nb is null then raise exception 'Not enough cards'; end if;
  return nb;
end $$;

-- Critter Eggs (the "gambling"): ~99% payback overall. Rolled on the server so it can't be rigged from the browser.
create function play_egg(stake int) returns json language plpgsql security definer set search_path = public as $$
declare r float := random(); m int; pay int;
begin
  if stake < 1 then raise exception 'Stake at least 1'; end if;
  update profiles set balance = balance - stake where id = auth.uid() and balance >= stake;
  if not found then raise exception 'Not enough cards'; end if;
  m := case when r < 0.55 then 0 when r < 0.77 then 1 when r < 0.90 then 2 when r < 0.97 then 3 else 10 end;
  pay := stake * m;
  update profiles set balance = balance + pay where id = auth.uid();
  return json_build_object('mult', m, 'payout', pay);
end $$;

-- Stock trade: qty > 0 buys, qty < 0 sells, at the price the page shows
create function trade(sym text, qty int, price int) returns void language plpgsql security definer set search_path = public as $$
begin
  if qty = 0 or price < 1 then raise exception 'Bad trade'; end if;
  if qty > 0 then
    update profiles set balance = balance - qty * price where id = auth.uid() and balance >= qty * price;
    if not found then raise exception 'Not enough cards'; end if;
    insert into holdings values (auth.uid(), sym, qty) on conflict (user_id, symbol) do update set qty = holdings.qty + excluded.qty;
  else
    update holdings set qty = qty + trade.qty where user_id = auth.uid() and symbol = sym and holdings.qty >= -trade.qty;
    if not found then raise exception 'You do not own that many'; end if;
    update profiles set balance = balance - qty * price where id = auth.uid();
  end if;
end $$;

create function list_item(p_item text, p_emoji text, p_fair int, p_price int, p_qty int) returns void language sql security definer set search_path = public as $$
  insert into shop_items (seller, item, emoji, fair, price, qty) values (auth.uid(), p_item, p_emoji, p_fair, p_price, p_qty);
$$;

create function unlist_item(p_id bigint) returns void language sql security definer set search_path = public as $$
  delete from shop_items where id = p_id and seller = auth.uid();
$$;

-- Buy from your brother's shelf
create function buy_item(p_id bigint, n int) returns void language plpgsql security definer set search_path = public as $$
declare s shop_items;
begin
  select * into s from shop_items where id = p_id for update;
  if s.id is null or s.qty < n or n < 1 then raise exception 'Not enough in stock'; end if;
  if s.seller = auth.uid() then raise exception 'That is your own item'; end if;
  update profiles set balance = balance - s.price * n where id = auth.uid() and balance >= s.price * n;
  if not found then raise exception 'Not enough cards'; end if;
  update profiles set balance = balance + s.price * n where id = s.seller;
  insert into inventory values (auth.uid(), s.item, s.emoji, n) on conflict (user_id, item) do update set qty = inventory.qty + excluded.qty;
  if s.qty = n then delete from shop_items where id = p_id; else update shop_items set qty = qty - n where id = p_id; end if;
end $$;

-- The simulated market buys one of YOUR items
create function market_sell(p_id bigint) returns void language plpgsql security definer set search_path = public as $$
declare s shop_items;
begin
  select * into s from shop_items where id = p_id and seller = auth.uid() for update;
  if s.id is null then return; end if;
  update profiles set balance = balance + s.price where id = auth.uid();
  if s.qty = 1 then delete from shop_items where id = p_id; else update shop_items set qty = qty - 1 where id = p_id; end if;
end $$;
