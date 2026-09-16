-- cm_no_redraw: deal the hand once per round, never refill it.
--
-- The opening deal and every later refill go through the same function
-- (G.FUNCS.draw_from_deck_to_hand), so blocking all of them would start each
-- round with an empty hand. This tracks whether the round has dealt yet, and
-- only the first deal is allowed through.
ChallengeMod.Draw = ChallengeMod.Draw or {}
local Draw = ChallengeMod.Draw

local function active()
  return G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_no_redraw == true
end

--- Should this draw be allowed? Called from the patch in
--- lovely/cm_no_redraw.toml, which zeroes the draw limit when this is false.
function Draw.allow()
  if not active() then return true end
  -- Booster packs draw into the hand for their own selection UI; blocking
  -- those would leave the pack empty and unselectable.
  if G.STATE == G.STATES.TAROT_PACK
    or G.STATE == G.STATES.SPECTRAL_PACK
    or G.STATE == G.STATES.SMODS_BOOSTER_OPENED
  then
    return true
  end
  return not (G.GAME.current_round and G.GAME.current_round.cm_dealt)
end

-- Marking the deal as done has to happen after the cards land, so it is driven
-- off the hand being non-empty rather than off the draw call itself -- the
-- opening deal is spread over several events.
local update_ref = Game.update
function Game:update(dt)
  if update_ref then update_ref(self, dt) end

  if active() and G.GAME.current_round and G.hand and #G.hand.cards > 0 then
    G.GAME.current_round.cm_dealt = true
  end
end
