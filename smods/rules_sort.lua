-- cm_rank_chips also reorders the hand, so sorting by rank puts the cards in
-- Big 2 order: 3 lowest through K, A, then 2 highest.
--
-- Without this the sort still uses vanilla order, so a 2 sits at the far end
-- from where its power suggests and it is easy to misread which card beats
-- which -- exactly the "I forgot 2 is bigger than 5" mistake.
--
-- Rides Card:get_nominal, which CardArea:sort compares. Note that get_highest
-- also uses it to pick the High Card scorer, so under this rule a 2 scores as
-- the high card over an ace. That follows from 2 being the highest card and is
-- intended, but it is a real scoring change, not only a cosmetic one.
local get_nominal_ref = Card.get_nominal

-- Only the 2 needs moving. Vanilla nominals already sort correctly for
-- everything else -- J, Q and K share a nominal of 10 and are separated by
-- face_nominal, which is left alone, and the ace is 11. The 2 is the one card
-- whose printed value puts it at the wrong end.
local BIG_TWO_NOMINAL = {
  [2] = 15, -- above the ace's 11, so it sorts to the top
}

function Card:get_nominal(mod)
  local base = get_nominal_ref(self, mod)

  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_rank_chips) then
    return base
  end

  local id = self.base and self.base.id
  local replacement = id and BIG_TWO_NOMINAL[id]
  if not replacement then return base end

  -- Suit sorting multiplies the rank by 10000 and adds the suit, so the
  -- substitution has to keep that shape or suit sorting breaks.
  if mod == "suit" then
    return base + (replacement - id) * 10000
  end
  return base + (replacement - id)
end
