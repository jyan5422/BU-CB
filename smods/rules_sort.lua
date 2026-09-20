-- cm_rank_chips also reorders the hand, so sorting by rank puts the cards in
-- Big 2 order: 3 lowest through K, A, then 2 highest.
--
-- Without this the sort still uses vanilla order, so a 2 sits at the far end
-- from where its power suggests and it is easy to misread which card beats
-- which -- exactly the "I forgot 2 is bigger than 5" mistake.
--
-- Rides Card:get_nominal, which CardArea:sort compares. Note that get_highest
-- also uses it to pick the High Card scorer, so under this rule a 2 scores as
-- the high card over an ace. That follows from 2 being the highest rank and is
-- intended, but it is a real scoring change, not only a cosmetic one.
local get_nominal_ref = Card.get_nominal

-- Only the 2 needs moving. Vanilla nominals already order everything else --
-- J, Q and K share a nominal of 10 and separate via face_nominal, and the ace
-- is 11. The 2 is the one card whose printed value puts it at the wrong end.
--
-- The target is a NOMINAL, not a sort value: get_nominal returns
-- 10*nominal + suit_nominal*mult + 10*face_nominal, so a shift has to be
-- scaled by the same 10 or it disappears against the suit contribution. An
-- earlier version added 13 to the result, which left a 2 on 37 against an
-- ace on 118.
--
-- The value has an UPPER bound as well as a lower one. Sorting by suit passes
-- mult = 10000, and suit_nominal steps by 0.01 per suit, so each suit occupies
-- a band 100 wide. Ranks fill [30, 110] of their band (a 3 up to an ace), so a
-- replacement above 12 pushes the 2 past the next band's floor and it sorts
-- into the neighbouring suit -- observed as a 2 of hearts sitting among the
-- spades. 11.5 clears the ace's 11 and stays inside the band.
local BIG_TWO_NOMINAL = {
  [2] = 11.5,
}

function Card:get_nominal(mod)
  local base = get_nominal_ref(self, mod)

  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_rank_chips) then
    return base
  end

  local id = self.base and self.base.id
  local replacement = id and BIG_TWO_NOMINAL[id]
  if not replacement then return base end

  -- nominal is multiplied by 10 in both modes, and rank_mult zeroes it for
  -- rankless cards -- in which case there is nothing to reorder.
  if SMODS.has_no_rank and SMODS.has_no_rank(self) then return base end
  local nominal = self.base and self.base.nominal
  if not nominal then return base end
  return base + 10 * (replacement - nominal)
end
