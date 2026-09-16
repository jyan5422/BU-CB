-- cm_no_redraw: deal the hand once per round, never refill it.
--
-- The opening deal and every later refill go through the same function
-- (G.FUNCS.draw_from_deck_to_hand), so blocking every draw would start each
-- round with an empty hand. Only the first deal of a round is allowed through.
ChallengeMod.Draw = ChallengeMod.Draw or {}
local Draw = ChallengeMod.Draw

-- Truthy rather than == true: the modifier holds the hand size bonus when one
-- is given, so a numeric value still means the rule is on.
local function active()
  return G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_no_redraw and true or false
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

-- cm_no_redraw carries a value: the hand size bonus applied on top of whatever
-- the deck and challenge already give. Written as a bonus rather than a flat
-- size so it composes -- base 8 becomes 13, and a Painted Deck's +2 becomes 15
-- rather than being overridden.
--
-- Applied to starting_params, which start_run reads to size the hand area, so
-- it has to land before that. evaluate_rules runs inside the rule loop, which
-- is earlier in start_run than the hand is built.
function Draw.hand_bonus()
  if not active() then return 0 end
  local v = G.GAME.modifiers.cm_no_redraw
  return type(v) == "number" and v or 0
end
