-- UNO MONEY v5: 150 cards, mythic rarity, 4th pack (Ultra Wild Pack). Run AFTER schema_v4_cards.sql. Keeps all your data.
-- Supabase: SQL Editor -> New query -> paste ALL -> Run. Safe to run twice.

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
  (75,'Storm Griffin',3,3,5,'AD'),
  (76,'Ruby Wyrmling',3,0,5,'AD'),
  (77,'Crystal Stag',3,1,6,'ABD'),
  (78,'Shadow Panther',3,2,7,'ABD'),
  (79,'Aurora Fox',3,3,8,'ABD'),
  (80,'Clockwork Dragonet',3,0,9,'ABD'),
  (81,'Sunscale Basilisk',3,1,10,'BCD'),
  (82,'Tidal Leviathan Jr',3,2,11,'BCD'),
  (83,'Phantom Heron',3,3,12,'BCD'),
  (84,'Magma Boar',3,0,13,'BCD'),
  (85,'Frostfang Wolf',3,1,14,'BD'),
  (86,'Thornback Hydra',3,2,15,'BD'),
  (87,'Starlit Unicorn',3,3,16,'C'),
  (88,'Ironclad Rhino',3,0,18,'C'),
  (89,'Inferno Phoenix',4,1,20,'AD'),
  (90,'Glacier Titan',4,2,22,'ABD'),
  (91,'Void Kraken',4,3,25,'BD'),
  (92,'Thunderlord Roc',4,0,28,'BCD'),
  (93,'Emerald Dragon',4,1,32,'BCD'),
  (94,'Mirage Sphinx',4,2,36,'C'),
  (95,'Eclipse Wolf',4,3,42,'C'),
  (96,'Tempest Manticore',4,0,50,'C'),
  (97,'Wildfire Dragon',5,4,60,'BCD'),
  (98,'Skipstep Phantom',5,4,80,'C'),
  (99,'Reverse Chimera',5,4,100,'C'),
  (100,'Draw Four Leviathan',5,4,130,'C'),
  (101,'Gumdrop Gremlin',1,1,1,'ABC'),
  (102,'Marsh Wisp',1,2,1,'ABC'),
  (103,'Biscuit Beetle',1,3,1,'ABC'),
  (104,'Thistle Tot',1,0,1,'ABC'),
  (105,'Pocket Panda',1,1,1,'AB'),
  (106,'Sniffle',1,2,1,'AB'),
  (107,'Dewdrop Drake',1,3,1,'AB'),
  (108,'Mitten Mouse',1,0,1,'AB'),
  (109,'Cobweb Cub',1,1,1,'A'),
  (110,'Twinkle Toad',1,2,2,'A'),
  (111,'Lollop',1,3,2,'A'),
  (112,'Fizzbit',1,0,2,'A'),
  (113,'Lava Lizard',2,1,2,'AB'),
  (114,'Breeze Bunny',2,2,2,'AB'),
  (115,'Slate Gargoyle',2,3,3,'AB'),
  (116,'Vine Viper',2,0,3,'ABC'),
  (117,'Aqua Axolotl',2,1,3,'ABC'),
  (118,'Prism Pika',2,2,4,'ABC'),
  (119,'Ash Armadillo',2,3,4,'BC'),
  (120,'Neon Newt',2,0,4,'BC'),
  (121,'Thorn Tiger',2,1,5,'BC'),
  (122,'Dune Dingo',2,2,5,'BC'),
  (123,'Glacial Gryphon',3,3,6,'A'),
  (124,'Solar Stag',3,0,7,'AB'),
  (125,'Nebula Narwhal',3,1,9,'AB'),
  (126,'Cobalt Cobra',3,2,11,'BC'),
  (127,'Bloodmoon Bat',3,3,13,'BCD'),
  (128,'Thunder Tortoise',3,0,15,'CD'),
  (129,'Mirror Mantis',3,1,17,'B'),
  (130,'Lotus Lynx',3,2,20,'CD'),
  (131,'Chrono Chimera',4,3,24,'CD'),
  (132,'Abyss Angler',4,0,28,'CD'),
  (133,'Sunfire Simurgh',4,1,32,'D'),
  (134,'Obsidian Oni',4,2,40,'D'),
  (135,'Rime Roc',4,3,46,'D'),
  (136,'Plasma Panther',4,0,55,'D'),
  (137,'Wild Eight Wyvern',5,4,70,'CD'),
  (138,'Skip Sphinx',5,4,90,'D'),
  (139,'Reverse Rex',5,4,115,'D'),
  (140,'Draw Two Dragon',5,4,150,'D'),
  (141,'Zero Sovereign',6,4,250,'D'),
  (142,'Omega Wildheart',6,4,300,'D'),
  (143,'Skip-Time Serpent',6,4,350,'D'),
  (144,'Reverse Eclipse',6,4,400,'D'),
  (145,'Draw Eight Colossus',6,4,500,'D'),
  (146,'Plus Ten Seraph',6,4,600,'D'),
  (147,'Chromatic Abyss',6,4,700,'D'),
  (148,'Wild Card Emperor',6,4,850,'D'),
  (149,'The Last Uno',6,4,1100,'D'),
  (150,'Infinite Reverse',6,4,1500,'D')
on conflict (id) do update set name = excluded.name, rarity = excluded.rarity, color = excluded.color, val = excluded.val, packs = excluded.packs;

-- add the 4th pack price (only if it is not there yet)
update settings set value = value || '[300]'::jsonb where key = 'pack_prices' and jsonb_array_length(value) = 3;

-- Packs: A Skip (4 cards), B Reverse (5, 1 uncommon+), C Wild Draw Four (5, 1 rare+), D Ultra Wild (5, 1 epic+, 1.2% mythic per card)
create or replace function open_pack(p_pack text) returns json language plpgsql security definer set search_path = public as $$
declare
  idx int := case p_pack when 'A' then 1 when 'B' then 2 when 'C' then 3 when 'D' then 4 else 0 end;
  w float[]; n int; g int; price int; i int; j int; m int; tot float; r float; acc float; rar int; cid int; had int; best int := 1;
  outp json[] := '{}';
begin
  perform need_ok();
  if idx = 0 then raise exception 'Unknown pack'; end if;
  if not (cfg('packs_on')#>>'{}')::boolean then raise exception 'Packs are closed right now'; end if;
  price := (cfg('pack_prices')->>(idx - 1))::int;
  if idx = 1 then w := array[78,19,2.7,0.3,0,0]; n := 4; g := 1;
  elsif idx = 2 then w := array[40,40,16,3.8,0.2,0]; n := 5; g := 2;
  elsif idx = 3 then w := array[8,32,40,16,4,0]; n := 5; g := 3;
  else w := array[0,0,32,47,19.8,1.2]; n := 5; g := 4; end if;
  update profiles set balance = balance - price where id = auth.uid() and balance >= price;
  if not found then raise exception 'Not enough cards'; end if;
  for i in 1..n loop
    m := 1; if i = n and best < g then m := g; end if;
    loop
      tot := 0; for j in m..6 loop tot := tot + w[j]; end loop;
      r := random() * tot; acc := 0; rar := 6;
      for j in m..6 loop acc := acc + w[j]; if r < acc then rar := j; exit; end if; end loop;
      select id into cid from cards where rarity = rar and position(p_pack in packs) > 0 order by random() limit 1;
      exit when cid is not null;
    end loop;
    best := greatest(best, rar);
    had := null;
    select qty into had from card_inv where user_id = auth.uid() and card_id = cid;
    insert into card_inv values (auth.uid(), cid, 1) on conflict (user_id, card_id) do update set qty = card_inv.qty + 1;
    outp := array_append(outp, json_build_object('id', cid, 'new', had is null));
  end loop;
  perform log_it(format('opened pack %s, best pull: %s', p_pack, (array['common','uncommon','rare','epic','legendary','MYTHIC'])[best]));
  return array_to_json(outp);
end $$;
