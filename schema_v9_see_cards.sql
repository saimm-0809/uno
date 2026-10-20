-- UNO MONEY v9: let players see what cards another player owns (for easier trading).
-- Run AFTER schema_v8_taxes.sql. Safe to run twice. Only card ids and counts are shared (no balances).
create or replace function player_cards(p_uid uuid) returns json language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Log in first'; end if;
  return json_build_object(
    'plain', coalesce((select json_object_agg(card_id, qty) from card_inv where user_id = p_uid and qty > 0), '{}'::json),
    'shiny', coalesce((select json_object_agg(card_id, qty) from shiny_inv where user_id = p_uid and qty > 0), '{}'::json));
end $$;
