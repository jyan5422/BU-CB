-- cm_wrap_straights: 2AKQJ counts as a straight.
--
-- SMODS already threads a wrap flag through straight detection --
-- get_straight(hand, SMODS.four_fingers('straight'), SMODS.shortcut(),
-- SMODS.wrap_around_straight()) -- and composes it with Four Fingers and
-- Shortcut itself, so overriding the one predicate is enough and those
-- interactions are handled upstream.
local wrap_ref = SMODS.wrap_around_straight

function SMODS.wrap_around_straight()
  if G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_wrap_straights then
    return true
  end
  return wrap_ref and wrap_ref() or false
end
