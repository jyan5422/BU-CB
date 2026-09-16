-- cm_no_redraw: deal the hand once per round, never refill it.
--
-- The opening deal and every later refill go through the same function
-- (G.FUNCS.draw_from_deck_to_hand), so blocking every draw would start each
-- round with an empty hand. Only the first deal of a round is allowed through.
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

  -- any_hand_drawn is the game's own per-round flag: set once the blind's
  -- first hand is drawn, and cleared with the rest of current_round at the
  -- start of each round. A flag of our own did not work -- current_round is
  -- mutated field by field between rounds rather than replaced, so a custom
  -- key survived and blocked the next round's opening deal.
  return not (G.GAME.current_round and G.GAME.current_round.any_hand_drawn)
end
