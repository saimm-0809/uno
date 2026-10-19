-- UNO MONEY v4: creature card packs. Run AFTER schema_v3_update.sql. Keeps all your data.
-- Supabase: SQL Editor -> New query -> paste ALL -> Run. Safe to run twice.

create table if not exists cards (id int primary key, name text not null, rarity int not null, color int not null, val int not null, packs text not null);
create table if not exists card_inv (user_id uuid references profiles on delete cascade, card_id int references cards, qty int not null check (qty > 0), primary key (user_id, card_id));
alter table cards enable row level security;
alter table card_inv enable row level security;
drop policy if exists c1 on cards; drop policy if exists c2 on card_inv;
create policy c1 on cards for select to authenticated using (true);
create policy c2 on card_inv for select to authenticated using (user_id = auth.uid());

insert into cards (id, name, rarity, color, val, packs) values
  (1,'Blipper',1,1,1,'ABC'),
  (2,'Moss Mole',1,2,1,'ABC'),
  (3,'Puddle Pup',1,3,1,'ABC'),
  (4,'Fuzzwick',1,0,1,'ABC'),
  (5,'Snaggle',1,1,1,'ABC'),
  (6,'Noodlebug',1,2,1,'ABC'),
  (7,'Pebblet',1,3,1,'ABC'),
  (8,'Wobblin',1,0,1,'ABC'),
  (9,'Drizzlet',1,1,1,'ABC'),
  (10,'Crumbat',1,2,1,'ABC'),
  (11,'Tuffet',1,3,1,'AB'),
  (12,'Gloopy',1,0,1,'AB'),
  (13,'Squeakle',1,1,1,'AB'),
  (14,'Dustbun',1,2,1,'AB'),
  (15,'Mumbo',1,3,1,'AB'),
  (16,'Pipsqueak',1,0,1,'AB'),
  (17,'Ticklet',1,1,1,'AB'),
  (18,'Burrowl',1,2,1,'AB'),
  (19,'Sprocket Rat',1,3,1,'AB'),
  (20,'Lintling',1,0,1,'AB'),
  (21,'Bramblet',1,1,1,'AB'),
  (22,'Muddle',1,2,1,'AB'),
  (23,'Quibble',1,3,1,'AB'),
  (24,'Snorfle',1,0,1,'AB'),
  (25,'Thimble Newt',1,1,1,'AB'),
  (26,'Boggin',1,2,1,'AB'),
  (27,'Fluffle',1,3,1,'AB'),
  (28,'Pixel Moth',1,0,1,'AB'),
  (29,'Cobbler Crab',1,1,1,'AB'),
  (30,'Hiccup',1,2,1,'AB'),
  (31,'Zonk',1,3,1,'A'),
  (32,'Mudlark',1,0,1,'A'),
  (33,'Twiglet',1,1,1,'A'),
  (34,'Gobbo',1,2,1,'A'),
  (35,'Plinko',1,3,1,'A'),
  (36,'Nubbin',1,0,1,'A'),
  (37,'Rumble Snail',1,1,1,'A'),
  (38,'Soot Sprite',1,2,1,'A'),
  (39,'Yarnling',1,3,1,'A'),
  (40,'Dribble',1,0,1,'A'),
  (41,'Cinder Cub',1,1,2,'A'),
  (42,'Fidget',1,2,2,'A'),
  (43,'Mossy Grub',1,3,2,'A'),
  (44,'Pudding Slug',1,0,2,'A'),
  (45,'Tatterwing',1,1,2,'A'),
  (46,'Clunk',1,2,2,'A'),
  (47,'Waddle',1,3,2,'A'),
  (48,'Bibbit',1,0,2,'A'),
  (49,'Scrumble',1,1,2,'A'),
  (50,'Crinkle',1,2,2,'A'),
  (51,'Thunder Pup',2,3,2,'AB'),
  (52,'Frost Fox',2,0,2,'AB'),
  (53,'Ember Newt',2,1,2,'AB'),
  (54,'Tide Otter',2,2,2,'AB'),
  (55,'Gale Finch',2,3,2,'AB'),
  (56,'Spark Lynx',2,0,2,'AB'),
  (57,'Bramble Bear',2,1,2,'AB'),
  (58,'Moon Moth',2,2,2,'AB'),
  (59,'Rust Golem',2,3,3,'ABC'),
  (60,'Echo Bat',2,0,3,'ABC'),
  (61,'Shell Knight',2,1,3,'ABC'),
  (62,'Sand Viper',2,2,3,'ABC'),
  (63,'Glimmer Stag',2,3,3,'ABC'),
  (64,'Ink Octo',2,0,3,'ABC'),
  (65,'Quill Boar',2,1,3,'ABC'),
  (66,'Dusk Hound',2,2,3,'ABC'),
  (67,'Coral Imp',2,3,4,'BC'),
  (68,'Lantern Toad',2,0,4,'BC'),
  (69,'Siren Eel',2,1,4,'BC'),
  (70,'Maple Wolf',2,2,4,'BC'),
  (71,'Cloud Ram',2,3,4,'BC'),
  (72,'Jelly King',2,0,4,'BC'),
  (73,'Pepper Drake',2,1,5,'BC'),
  (74,'Opal Owl',2,2,5,'BC'),
  (75,'Storm Griffin',3,3,5,'A'),
  (76,'Ruby Wyrmling',3,0,5,'A'),
  (77,'Crystal Stag',3,1,6,'AB'),
  (78,'Shadow Panther',3,2,7,'AB'),
  (79,'Aurora Fox',3,3,8,'AB'),
  (80,'Clockwork Dragonet',3,0,9,'AB'),
  (81,'Sunscale Basilisk',3,1,10,'BC'),
  (82,'Tidal Leviathan Jr',3,2,11,'BC'),
  (83,'Phantom Heron',3,3,12,'BC'),
  (84,'Magma Boar',3,0,13,'BC'),
  (85,'Frostfang Wolf',3,1,14,'B'),
  (86,'Thornback Hydra',3,2,15,'B'),
  (87,'Starlit Unicorn',3,3,16,'C'),
  (88,'Ironclad Rhino',3,0,18,'C'),
  (89,'Inferno Phoenix',4,1,20,'A'),
  (90,'Glacier Titan',4,2,22,'AB'),
  (91,'Void Kraken',4,3,25,'B'),
  (92,'Thunderlord Roc',4,0,28,'BC'),
  (93,'Emerald Dragon',4,1,32,'BC'),
  (94,'Mirage Sphinx',4,2,36,'C'),
  (95,'Eclipse Wolf',4,3,42,'C'),
  (96,'Tempest Manticore',4,0,50,'C'),
  (97,'Wildfire Dragon',5,4,60,'BC'),
  (98,'Skipstep Phantom',5,4,80,'C'),
  (99,'Reverse Chimera',5,4,100,'C'),
  (100,'Draw Four Leviathan',5,4,130,'C')
on conflict (id) do update set name = excluded.name, rarity = excluded.rarity, color = excluded.color, val = excluded.val, packs = excluded.packs;

insert into settings values ('pack_prices','[8,28,100]'),('packs_on','true') on conflict do nothing;

-- Open a pack. A = Skip Pack (4 cards), B = Reverse Pack (5 cards, 1 uncommon+), C = Wild Draw Four Pack (5 cards, 1 rare+)
create or replace function open_pack(p_pack text) returns json language plpgsql security definer set search_path = public as $$
declare
  idx int := case p_pack when 'A' then 1 when 'B' then 2 when 'C' then 3 else 0 end;
  w float[]; n int; g int; price int; i int; j int; m int; tot float; r float; acc float; rar int; cid int; had int; best int := 1;
  outp json[] := '{}';
begin
  perform need_ok();
  if idx = 0 then raise exception 'Unknown pack'; end if;
  if not (cfg('packs_on')#>>'{}')::boolean then raise exception 'Packs are closed right now'; end if;
  price := (cfg('pack_prices')->>(idx - 1))::int;
  if idx = 1 then w := array[78,19,2.7,0.3,0]; n := 4; g := 1;
  elsif idx = 2 then w := array[40,40,16,3.8,0.2]; n := 5; g := 2;
  else w := array[8,32,40,16,4]; n := 5; g := 3; end if;
  update profiles set balance = balance - price where id = auth.uid() and balance >= price;
  if not found then raise exception 'Not enough cards'; end if;
  for i in 1..n loop
    m := 1; if i = n and best < g then m := g; end if;
    loop
      tot := 0; for j in m..5 loop tot := tot + w[j]; end loop;
      r := random() * tot; acc := 0; rar := 5;
      for j in m..5 loop acc := acc + w[j]; if r < acc then rar := j; exit; end if; end loop;
      select id into cid from cards where rarity = rar and position(p_pack in packs) > 0 order by random() limit 1;
      exit when cid is not null;
    end loop;
    best := greatest(best, rar);
    had := null;
    select qty into had from card_inv where user_id = auth.uid() and card_id = cid;
    insert into card_inv values (auth.uid(), cid, 1) on conflict (user_id, card_id) do update set qty = card_inv.qty + 1;
    outp := array_append(outp, json_build_object('id', cid, 'new', had is null));
  end loop;
  perform log_it(format('opened pack %s, best pull: %s', p_pack, (array['common','uncommon','rare','epic','legendary'])[best]));
  return array_to_json(outp);
end $$;

create or replace function sell_card(p_card int, p_qty int) returns void language plpgsql security definer set search_path = public as $$
declare have int; v int;
begin
  perform need_ok();
  select qty into have from card_inv where user_id = auth.uid() and card_id = p_card for update;
  if have is null or p_qty < 1 or p_qty > have then raise exception 'You do not have that many'; end if;
  select val into v from cards where id = p_card;
  if p_qty = have then delete from card_inv where user_id = auth.uid() and card_id = p_card;
  else update card_inv set qty = qty - p_qty where user_id = auth.uid() and card_id = p_card; end if;
  update profiles set balance = balance + v * p_qty where id = auth.uid();
  perform log_it(format('sold %s x%s for %s', (select name from cards where id = p_card), p_qty, v * p_qty));
end $$;

create or replace function sell_dupes() returns int language plpgsql security definer set search_path = public as $$
declare tot int;
begin
  perform need_ok();
  select coalesce(sum((ci.qty - 1) * c.val), 0) into tot from card_inv ci join cards c on c.id = ci.card_id where ci.user_id = auth.uid() and ci.qty > 1;
  update card_inv set qty = 1 where user_id = auth.uid() and qty > 1;
  update profiles set balance = balance + tot where id = auth.uid();
  if tot > 0 then perform log_it(format('sold duplicate cards for %s', tot)); end if;
  return tot;
end $$;

create or replace function admin_set_card(p_uid uuid, p_card int, p_qty int) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  if p_qty <= 0 then delete from card_inv where user_id = p_uid and card_id = p_card;
  else insert into card_inv values (p_uid, p_card, p_qty) on conflict (user_id, card_id) do update set qty = excluded.qty; end if;
  perform log_it('ADMIN set cards'); end $$;

-- leaderboard now includes card collection value
create or replace function leaderboard() returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
    'id', p.id, 'username', p.username, 'balance', p.balance, 'owed', p.owed,
    'hold', (select coalesce(json_object_agg(symbol, qty), '{}'::json) from holdings h where h.user_id = p.id),
    'inv', (select coalesce(json_agg(json_build_object('item', item, 'qty', qty)), '[]'::json) from inventory i where i.user_id = p.id),
    'cards', (select coalesce(json_object_agg(card_id::text, qty), '{}'::json) from card_inv ci where ci.user_id = p.id),
    'cardval', (select coalesce(sum(ci.qty * c.val), 0) from card_inv ci join cards c on c.id = ci.card_id where ci.user_id = p.id)
  )), '[]'::json) from profiles p
$$;

create or replace function admin_wipe_user(p_uid uuid) returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  update profiles set balance = 0, owed = 0, forced_mult = null where id = p_uid;
  delete from holdings where user_id = p_uid; delete from inventory where user_id = p_uid; delete from shop_items where seller = p_uid; delete from card_inv where user_id = p_uid;
  perform log_it('ADMIN wiped a player'); end $$;

create or replace function admin_reset_all() returns void language plpgsql security definer set search_path = public as $$
begin perform need_admin();
  update profiles set balance = 0, owed = 0, forced_mult = null;
  delete from holdings where true; delete from inventory where true; delete from shop_items where true; delete from card_inv where true;
  delete from hl_games where true; delete from duels where true;
  perform log_it('ADMIN reset everyone'); end $$;
