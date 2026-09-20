-- cm_climb: the Big 2 trick rule.
--
-- The first hand played in a round fixes the trick's shape; every later hand
-- that round must match it and beat it. See docs/big-wee-design.md.
--
-- Exposed on ChallengeMod so a joker, daily or another challenge can reuse the
-- comparison without taking the rest of the Big Wee rule set.
ChallengeMod.Climb = ChallengeMod.Climb or {}
local Climb = ChallengeMod.Climb

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

-- For the player-facing reason: which printed rank a Big 2 weight came from.
local RANK_LABEL = {
  [1] = "3", [2] = "4", [3] = "5", [4] = "6", [5] = "7", [6] = "8",
  [7] = "9", [8] = "10", [9] = "J", [10] = "Q", [11] = "K", [12] = "A",
  [13] = "2",
}

local SUIT_LABEL = {}
for suit, weight in pairs(SUIT_ORDER) do SUIT_LABEL[weight] = suit end

function Climb.rank_name(weight)
  return weight and RANK_LABEL[weight] or nil
end

-- Rank and suit together, because suit is the tie-break: against a pair of 7s
-- "beat 7" looks impossible until you know which 7.
function Climb.card_name(rank, suit)
  local r = Climb.rank_name(rank)
  if not r then return nil end
  local s = suit and SUIT_LABEL[suit]
  return s and (r .. " of " .. s) or r
end

--- Big 2 suit weight of one card, or nil if it has no suit.
function Climb.suit_of(card)
  local suit = card and card.base and card.base.suit
  return suit and SUIT_ORDER[suit] or nil
end

--- Big 2 rank of one card, or nil if it has no printed rank.
-- Rankless cards (Stone) must never win a comparison: Card:get_id() returns a
-- large random negative for them, which would otherwise compare as garbage.
function Climb.rank_of(card)
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
function Climb.hand_rank(cards)
  local counts, suits = {}, {}
  for _, card in ipairs(cards or {}) do
    local r = Climb.rank_of(card)
    if r then
      counts[r] = (counts[r] or 0) + 1
      local sv = Climb.suit_of(card) or 0
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
function Climb.hand_tier(handname)
  if not (handname and G.handlist) then return nil end
  for i, name in ipairs(G.handlist) do
    if name == handname then return #G.handlist - i + 1 end
  end
  return nil
end

-- Hand type is compared at EVERY count, then rank breaks a tie.
--
-- An earlier version only compared type at 4+ cards, on the reasoning that
-- Big 2 ranks pairs and triples by rank alone. That is true only because Big 2
-- has no *illegal* two-card play -- two cards there are always a pair. Balatro
-- will happily play any two cards, so skipping the type check let King-3
-- ("High Card") beat a pair of 7s on the king's rank, and three junk cards
-- beat a triple. Comparing type first rejects those, and for two genuine pairs
-- the tiers are equal and it falls through to rank exactly as before.
local function ranked_by_tier(count)
  return count >= 1
end

--- Does a play beat the locked trick?
-- @param lock table|nil  the current lock, nil when leading
-- @param count number    cards in the play
-- @param handname string Balatro's name for the played hand
-- @param cards table     the played cards
-- @return boolean, string  whether it beats, and why (for the player alert)
function Climb.beats(lock, count, handname, cards)
  if not lock then return true, "lead" end

  -- Reasons are phrased to stand alone as the on-screen label, and all three
  -- lead with the verb: they name what to do next, not what went wrong.
  if count ~= lock.count then
    return false, ("Climb with %d card%s"):format(lock.count, lock.count == 1 and "" or "s")
  end

  if ranked_by_tier(count) then
    local tier, lock_tier = Climb.hand_tier(handname), Climb.hand_tier(lock.handname)
    if not tier or not lock_tier then return false, "unknown hand" end
    if tier > lock_tier then return true, "beats" end
    if tier < lock_tier then return false, ("Climb over %s"):format(tostring(lock.handname)) end
    -- Same hand type: rank splits the tie, as it does in Big 2.
  end

  -- Big 2 has no ties: an equal rank is split by the suit of the deciding
  -- card, so a pair of 7s does beat another pair of 7s if its high card's
  -- suit is higher.
  local rank, suit = Climb.hand_rank(cards)
  if not rank then return false, "no rank to compare" end
  if not lock.rank then return true, "beats" end
  if above(rank, suit, lock.rank, lock.suit) then return true, "beats" end
  -- Name the card to beat: "too low" leaves the player guessing, and the Big 2
  -- order is the part that surprises people (a 2 outranks everything).
  return false, ("Climb over %s"):format(Climb.card_name(lock.rank, lock.suit) or "the last hand")
end

-- The lock lives on G.GAME.current_round, but the game does NOT replace that
-- table between rounds -- it mutates named fields, so a key of our own would
-- survive and block the next round's opening hand. It is therefore stamped
-- with the round number and treated as stale when the stamp no longer matches.
function Climb.get_lock()
  local round = G.GAME and G.GAME.current_round
  local lock = round and round.cm_climb_state
  if not lock then return nil end
  -- Stamped with G.GAME.round, a monotonic counter the game bumps per round.
  -- An earlier attempt keyed off any_hand_drawn, but new_round clears that and
  -- the deal immediately sets it true again, so by the time a hand is played it
  -- is indistinguishable from the previous round's -- the lock survived and
  -- rejected the first hand of every new round.
  if lock.round ~= (G.GAME and G.GAME.round) then
    round.cm_climb_state = nil
    return nil
  end
  return lock
end

function Climb.set_lock(count, handname, cards)
  if not (G.GAME and G.GAME.current_round) then return end
  local rank, suit = Climb.hand_rank(cards)
  G.GAME.current_round.cm_climb_state = {
    count = count,
    handname = handname,
    rank = rank,
    suit = suit,
    round = G.GAME.round,
  }
end

function Climb.clear_lock()
  if G.GAME and G.GAME.current_round then
    G.GAME.current_round.cm_climb_state = nil
  end
end

function Climb.active()
  return G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_climb == true
end

--- Xmult for going out on `handname`; nil when there is no bonus.
--
-- Keyed on what the hand contains rather than Balatro's tier index, which
-- keeps the numbers small and predictable: a pair is worth X2 whether it is a
-- bare pair, two pair or inside a flush. The earlier version scaled 1.5 to 6.5
-- across twelve tiers, which was finer-grained than anyone could read.
--
-- A full house is X3 for its triple, even though it outranks a straight, and
-- everything at four of a kind or above is X4 -- those are rare enough that
-- splitting them further would not be noticed.
local SHED_XMULT = {
  ["Pair"] = 2,
  ["Two Pair"] = 2,
  ["Three of a Kind"] = 3,
  ["Straight"] = 3,
  -- A flush pays X3, not the X2 its lack of a group would suggest. It sits
  -- above both the straight and the triple in Balatro's own order, so paying
  -- less than either put a dip in the curve -- and it is harder to assemble
  -- from a five-card hand than two pair, which was matching it.
  ["Flush"] = 3,
  ["Full House"] = 3,
  ["Four of a Kind"] = 4,
  ["Straight Flush"] = 4,
  ["Five of a Kind"] = 4,
  ["Flush House"] = 4,
  ["Flush Five"] = 4,
}

function Climb.shed_xmult(handname)
  return handname and SHED_XMULT[handname] or nil
end

--- Multiplier the mult preview should show for the current selection.
--
-- The preview reads G.GAME.hands[name].mult, which knows nothing about the
-- shed bonus, so a selection that would empty the hand showed its ordinary
-- mult and the payout only appeared after committing.
--
-- Returns 1 unless every card in hand is selected, since that is the condition
-- the bonus itself checks. Display only -- the bonus is applied during scoring.
function Climb.shed_preview_xmult(area, handname)
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_shed_bonus) then return 1 end
  if not (area and area.highlighted and G.hand) then return 1 end
  if #G.hand.cards == 0 or #area.highlighted ~= #G.hand.cards then return 1 end
  -- A hand that will be thrown away pays nothing, so promising a bonus for it
  -- is a lie the player spends a hand to discover. Seen in play as
  -- "Hand will not score / Climb with 5 cards" above a cheerful "X3 Shed".
  --
  -- G.boss_throw_hand is the game's own verdict on the current selection, set
  -- from debuff_hand a few lines earlier in the same parse_highlighted pass --
  -- so it covers a boss's refusal as well as the climb's, and needs no second
  -- evaluation of our own.
  if G.boss_throw_hand then return 1 end
  return Climb.shed_xmult(handname) or 1
end

--- Subtext for the game's "Hand will not score" warning: the reason the
--- selection is illegal, plus the way out.
---
--- Rendered as a row of its own, added by lovely/cm_climb_warning_row.toml.
--- It was first appended to the blind's own debuff text, but DynaText shrinks
--- to fit maxw = 9, so the joined string came out smaller than either half
--- would alone. Without any of this the player is told the hand will not score
--- but never why -- the most confusing thing about the rule in playtesting.
--- Where an alert should be drawn.
---
--- Two anchors, for two situations. Centred on the room is right while the
--- player is still choosing, when the middle of the screen is empty. Once a
--- hand is committed the cards fly to the middle, and centred text draws
--- UNDERNEATH them -- seen in play as "Must beat 2 of Diamonds" rendering
--- behind the played ace. A committed message therefore uses the same anchor
--- as the game's own play_area_status_text: top-aligned above the play area.
---
--- Split out from the alert itself so the rule is assertable; the alert has to
--- touch attention_text and cannot be called from a spec.
function Climb.alert_placement(opts)
  opts = opts or {}
  if opts.over_play then
    return { align = "tm", y = opts.y or -1 }
  end
  return { align = "cm", y = opts.y or 0 }
end

function Climb.selection_subtext()
  local why = Climb.last_reason
  if not why then return nil end
  -- Only while that warning is actually up. get_loc_debuff_text is also called
  -- by Blind:alert_debuff when a boss blind starts, and a reason left over
  -- from the previous round would be appended to the boss's own text there --
  -- advice about a climb the player has not begun. G.boss_throw_hand is set
  -- and cleared per selection by the game itself, so it is exactly the flag
  -- that says the warning is showing.
  if not (G and G.boss_throw_hand) then return nil end
  -- Any discard clears the trick, so that is the escape -- but only while one
  -- is left. With none the hint is advice the player cannot take, so the
  -- requirement is shown on its own.
  local round = G.GAME and G.GAME.current_round
  local discards = round and round.discards_left or 0
  if discards <= 0 then return why end
  return why .. ", discard to reset"
end
