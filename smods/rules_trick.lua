-- cm_trick_lock: the Big 2 trick rule.
--
-- The first hand played in a round fixes the trick's shape; every later hand
-- that round must match it and beat it. See docs/big-wee-design.md.
--
-- Exposed on ChallengeMod so a joker, daily or another challenge can reuse the
-- comparison without taking the rest of the Big Wee rule set.
ChallengeMod.Trick = ChallengeMod.Trick or {}
local Trick = ChallengeMod.Trick

-- Big 2 rank order, low to high: 3..10, J, Q, K, A, 2. Keyed by base.id, the
-- printed rank, which enhancements, editions and our own chip bonuses never
-- touch -- so a steel 5 still compares as a 5 and scoring cannot skew a
-- comparison.
local RANK_ORDER = {
  [3] = 1,
  [4] = 2,
  [5] = 3,
  [6] = 4,
  [7] = 5,
  [8] = 6,
  [9] = 7,
  [10] = 8,
  [11] = 9, -- Jack
  [12] = 10, -- Queen
  [13] = 11, -- King
  [14] = 12, -- Ace
  [2] = 13, -- the Big Two
}

-- Big 2 suit order, low to high: diamonds, clubs, hearts, spades. Big 2 has no
-- ties -- every card is distinct -- so suit always breaks an equal rank.
local SUIT_ORDER = {
  Diamonds = 1,
  Clubs = 2,
  Hearts = 3,
  Spades = 4,
}

--- Big 2 suit weight of one card, or nil if it has no suit.
function Trick.suit_of(card)
  local suit = card and card.base and card.base.suit
  return suit and SUIT_ORDER[suit] or nil
end

--- Big 2 rank of one card, or nil if it has no printed rank.
-- Rankless cards (Stone) must never win a comparison: Card:get_id() returns a
-- large random negative for them, which would otherwise compare as garbage.
function Trick.rank_of(card)
  local id = card and card.base and card.base.id
  return id and RANK_ORDER[id] or nil
end

--- The deciding card of a hand: highest rank, and among equals the highest
-- suit. Returned as a sortable pair so callers never compare rank alone.
--
-- Big 2 decides a hand by its defining GROUP, not its highest card: a full
-- house 3-3-3-9-9 is a "three" because the triple carries it, and four of a
-- kind 5-5-5-5-K is a "five", the king being only a kicker. Taking the top
-- card would rank both by the wrong card, so the largest group wins and ties
-- between equal-sized groups fall back to rank.
-- @return number|nil rank, number|nil suit
function Trick.hand_rank(cards)
  local counts, suits = {}, {}
  for _, card in ipairs(cards or {}) do
    local r = Trick.rank_of(card)
    if r then
      counts[r] = (counts[r] or 0) + 1
      local sv = Trick.suit_of(card) or 0
      if not suits[r] or sv > suits[r] then suits[r] = sv end
    end
  end

  local best_rank, best_count
  for rank, count in pairs(counts) do
    if not best_rank
      or count > best_count
      or (count == best_count and rank > best_rank)
    then
      best_rank, best_count = rank, count
    end
  end

  if not best_rank then return nil end
  return best_rank, suits[best_rank]
end

--- Is (rank_a, suit_a) strictly above (rank_b, suit_b)?
local function above(rank_a, suit_a, rank_b, suit_b)
  if rank_a ~= rank_b then return rank_a > rank_b end
  return (suit_a or 0) > (suit_b or 0)
end

--- Hand strength, bigger is stronger.
-- G.handlist is ordered strongest first, so the index is inverted to keep the
-- same "bigger wins" direction as the rank comparison.
function Trick.hand_tier(handname)
  if not (handname and G.handlist) then return nil end
  for i, name in ipairs(G.handlist) do
    if name == handname then return #G.handlist - i + 1 end
  end
  return nil
end

-- Big 2 compares singles, pairs and triples by rank, and five-card hands by
-- which hand they are. Four-card plays are not a Big 2 shape but Balatro
-- offers them, so they get their own bucket, ranked the same way as fives.
local function ranked_by_tier(count)
  return count >= 4
end

--- Does a play beat the locked trick?
-- @param lock table|nil  the current lock, nil when leading
-- @param count number    cards in the play
-- @param handname string Balatro's name for the played hand
-- @param cards table     the played cards
-- @return boolean, string  whether it beats, and why (for the player alert)
function Trick.beats(lock, count, handname, cards)
  if not lock then return true, "lead" end

  if count ~= lock.count then
    return false, ("needs %d card%s"):format(lock.count, lock.count == 1 and "" or "s")
  end

  if ranked_by_tier(count) then
    local tier, lock_tier = Trick.hand_tier(handname), Trick.hand_tier(lock.handname)
    if not tier or not lock_tier then return false, "unknown hand" end
    if tier > lock_tier then return true, "beats" end
    if tier < lock_tier then return false, ("needs to beat %s"):format(tostring(lock.handname)) end
    -- Same hand type: rank splits the tie, as it does in Big 2.
  end

  -- Big 2 has no ties: an equal rank is split by the suit of the deciding
  -- card, so a pair of 7s does beat another pair of 7s if its high card's
  -- suit is higher.
  local rank, suit = Trick.hand_rank(cards)
  if not rank then return false, "no rank to compare" end
  if not lock.rank then return true, "beats" end
  if above(rank, suit, lock.rank, lock.suit) then return true, "beats" end
  return false, "too low"
end

-- The lock lives on G.GAME.current_round, which the game already clears at the
-- start of each round, so it resets per blind with no work from us.
function Trick.get_lock()
  return G.GAME and G.GAME.current_round and G.GAME.current_round.cm_trick
end

function Trick.set_lock(count, handname, cards)
  if not (G.GAME and G.GAME.current_round) then return end
  local rank, suit = Trick.hand_rank(cards)
  G.GAME.current_round.cm_trick = {
    count = count,
    handname = handname,
    rank = rank,
    suit = suit,
  }
end

function Trick.clear_lock()
  if G.GAME and G.GAME.current_round then
    G.GAME.current_round.cm_trick = nil
  end
end

function Trick.active()
  return G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_trick_lock == true
end

--- Xmult for going out on `handname`; nil when there is no bonus.
-- 1 + (tier-1) * 0.5 puts High Card on exactly 1x, so dumping junk to get out
-- pays nothing while a hand held back deliberately pays properly.
function Trick.shed_xmult(handname)
  local tier = Trick.hand_tier(handname)
  if not tier then return nil end
  local x = 1 + (tier - 1) * 0.5
  if x <= 1 then return nil end
  return x
end
