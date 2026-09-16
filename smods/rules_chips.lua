-- cm_rank_chips and cm_suit_chips: Big 2 values as chips.
--
-- Both ride Card:get_chip_bonus, which already adds ability.perma_bonus -- the
-- same field Hiker writes to. These affect SCORE only; comparison reads
-- base.id and base.suit, so a chip bonus can never change who wins a trick.
ChallengeMod.Chips = ChallengeMod.Chips or {}
local Chips = ChallengeMod.Chips

-- Target minus base, so chip value tracks Big 2's rank order: 3..10 unchanged,
-- J 11, Q 12, K 13, A 15, and the 2 highest at 14. Ace and 2 sit above the
-- king, which vanilla chips do not express.
local RANK_BONUS = {
  [2] = 12, -- 2 -> 14
  [11] = 1, -- J -> 11
  [12] = 2, -- Q -> 12
  [13] = 3, -- K -> 13
  [14] = 4, -- A -> 15
}

local SUIT_BONUS = {
  Spades = 3,
  Hearts = 2,
  Clubs = 1,
  Diamonds = 0,
}

function Chips.rank_bonus(card)
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_rank_chips) then return 0 end
  local id = card and card.base and card.base.id
  return id and RANK_BONUS[id] or 0
end

-- Goes through Card:is_suit rather than reading base.suit, so Wild cards count
-- as whatever they currently are.
function Chips.suit_bonus(card)
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_suit_chips) then return 0 end
  if not (card and card.is_suit) then return 0 end
  for suit, bonus in pairs(SUIT_BONUS) do
    if bonus > 0 and card:is_suit(suit) then return bonus end
  end
  return 0
end

function Chips.bonus(card)
  return Chips.rank_bonus(card) + Chips.suit_bonus(card)
end

-- Stone cards and the like have no printed rank or suit, so they get nothing:
-- RANK_BONUS misses on a nil id and is_suit answers false.
local get_chip_bonus_ref = Card.get_chip_bonus
function Card:get_chip_bonus()
  return get_chip_bonus_ref(self) + ChallengeMod.Chips.bonus(self)
end
