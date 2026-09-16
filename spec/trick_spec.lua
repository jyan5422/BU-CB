-- The Big 2 trick comparison. Pure logic, so it is tested directly rather
-- than through the mod load: this is where the edge cases live.
-- The module needs only ChallengeMod and G.handlist, so the full mod harness
-- is not involved. Built in a helper rather than at file scope because busted
-- shares globals between spec files and load_spec.lua resets them.
local HANDLIST = {
  "Flush Five",
  "Flush House",
  "Five of a Kind",
  "Straight Flush",
  "Four of a Kind",
  "Full House",
  "Flush",
  "Straight",
  "Three of a Kind",
  "Two Pair",
  "Pair",
  "High Card",
}

local Trick
local function load_module()
  -- Via _G explicitly: the module reads these as globals, and busted's
  -- environment does not necessarily resolve a bare assignment to _G.
  _G.ChallengeMod = {}
  _G.G = { handlist = HANDLIST }
  assert(loadfile("smods/rules_trick.lua"))()
  Trick = _G.ChallengeMod.Trick
end

-- base.id is the printed rank: 2..10 as themselves, J=11, Q=12, K=13, A=14.
-- Suits default to Diamonds, the lowest, so tests that do not care about suit
-- cannot accidentally win on one.
local function card(id, suit)
  return { base = { id = id, suit = suit or "Diamonds" } }
end
local function hand(...)
  local t = {}
  for _, id in ipairs({ ... }) do t[#t + 1] = card(id) end
  return t
end

describe("Big 2 rank order", function()
  before_each(load_module)
  it("makes the 2 the highest card", function()
    assert.is_true(Trick.rank_of(card(2)) > Trick.rank_of(card(14)))
    assert.is_true(Trick.rank_of(card(2)) > Trick.rank_of(card(13)))
  end)

  it("puts the ace above the king", function()
    assert.is_true(Trick.rank_of(card(14)) > Trick.rank_of(card(13)))
  end)

  it("makes the 3 the lowest card", function()
    for _, id in ipairs({ 4, 5, 10, 11, 14, 2 }) do
      assert.is_true(Trick.rank_of(card(id)) > Trick.rank_of(card(3)))
    end
  end)

  it("orders the middle ranks normally", function()
    assert.is_true(Trick.rank_of(card(9)) > Trick.rank_of(card(8)))
    assert.is_true(Trick.rank_of(card(11)) > Trick.rank_of(card(10)))
  end)

  -- Stone cards and anything rankless: get_id() returns a random negative, so
  -- an unguarded comparison would use garbage.
  it("gives rankless cards no rank", function()
    assert.is_nil(Trick.rank_of({ base = {} }))
    assert.is_nil(Trick.rank_of({}))
    assert.is_nil(Trick.rank_of(nil))
    assert.is_nil(Trick.rank_of(card(-482913)))
  end)
end)

describe("Big 2 suit order", function()
  before_each(load_module)

  it("orders diamonds lowest and spades highest", function()
    assert.is_true(Trick.suit_of(card(5, "Spades")) > Trick.suit_of(card(5, "Hearts")))
    assert.is_true(Trick.suit_of(card(5, "Hearts")) > Trick.suit_of(card(5, "Clubs")))
    assert.is_true(Trick.suit_of(card(5, "Clubs")) > Trick.suit_of(card(5, "Diamonds")))
  end)

  it("is nil for a card with no suit", function()
    assert.is_nil(Trick.suit_of({ base = { id = 5 } }))
    assert.is_nil(Trick.suit_of(nil))
  end)
end)

describe("hand rank", function()
  before_each(load_module)
  it("takes the highest card in the hand", function()
    assert.equal(Trick.rank_of(card(2)), (Trick.hand_rank(hand(5, 7, 2, 3))))
    assert.equal(Trick.rank_of(card(14)), (Trick.hand_rank(hand(14, 13, 3))))
  end)

  -- Big 2 decides a hand by its defining group, not its top card.
  it("decides a full house by its triple, not its top card", function()
    -- 3-3-3-9-9: the triple of 3s carries it, so it is a "three".
    local rank = Trick.hand_rank({ card(3), card(3), card(3), card(9), card(9) })
    assert.equal(Trick.rank_of(card(3)), rank)
  end)

  it("decides four of a kind by its quad, not its kicker", function()
    -- 5-5-5-5-K: the king is only a kicker.
    local rank = Trick.hand_rank({ card(5), card(5), card(5), card(5), card(13) })
    assert.equal(Trick.rank_of(card(5)), rank)
  end)

  it("decides a pair by the pair, not the odd card", function()
    local rank = Trick.hand_rank({ card(4), card(4), card(14) })
    assert.equal(Trick.rank_of(card(4)), rank)
  end)

  -- The deciding card is the highest rank, and among equals the highest suit.
  it("picks the highest suit among equal top ranks", function()
    local rank, suit = Trick.hand_rank({ card(9, "Clubs"), card(9, "Spades"), card(3) })
    assert.equal(Trick.rank_of(card(9)), rank)
    assert.equal(Trick.suit_of(card(9, "Spades")), suit)
  end)

  it("ignores rankless cards among ranked ones", function()
    local h = hand(7)
    h[#h + 1] = { base = {} }
    assert.equal(Trick.rank_of(card(7)), (Trick.hand_rank(h)))
  end)

  it("is nil for an all-rankless hand", function()
    assert.is_nil((Trick.hand_rank({ { base = {} }, { base = {} } })))
    assert.is_nil((Trick.hand_rank({})))
    assert.is_nil((Trick.hand_rank(nil)))
  end)
end)

describe("hand tier", function()
  before_each(load_module)
  it("ranks stronger hands higher", function()
    assert.is_true(Trick.hand_tier("Full House") > Trick.hand_tier("Flush"))
    assert.is_true(Trick.hand_tier("Flush") > Trick.hand_tier("Straight"))
    assert.is_true(Trick.hand_tier("Four of a Kind") > Trick.hand_tier("Full House"))
  end)

  it("puts High Card at the bottom", function()
    assert.equal(1, Trick.hand_tier("High Card"))
  end)

  it("is nil for an unknown hand", function()
    assert.is_nil(Trick.hand_tier("Nonsense"))
    assert.is_nil(Trick.hand_tier(nil))
  end)
end)

describe("beating the trick", function()
  before_each(load_module)
  it("allows anything when leading", function()
    assert.is_true(Trick.beats(nil, 1, "High Card", hand(3)))
    assert.is_true(Trick.beats(nil, 5, "High Card", hand(3, 4, 6, 8, 9)))
  end)

  it("requires the same card count", function()
    local lock = { count = 2, handname = "Pair", rank = Trick.rank_of(card(5)) }
    local ok, why = Trick.beats(lock, 1, "High Card", hand(14))
    assert.is_false(ok)
    assert.is_truthy(why:match("2 cards"))
    assert.is_false(Trick.beats(lock, 3, "Three of a Kind", hand(7, 7, 7)))
  end)

  -- Singles, pairs and triples compare by rank alone.
  it("compares small hands by rank", function()
    local lock = { count = 2, handname = "Pair", rank = Trick.rank_of(card(5)) }
    assert.is_true(Trick.beats(lock, 2, "Pair", hand(7, 7)))
    assert.is_false(Trick.beats(lock, 2, "Pair", hand(4, 4)))
  end)

  -- Big 2 has no ties: every card is distinct, so suit always decides.
  it("breaks an equal rank by suit", function()
    local lock = { count = 2, handname = "Pair", rank = Trick.rank_of(card(7)), suit = Trick.suit_of(card(7, "Clubs")) }
    -- Spade 7 beats club 7.
    assert.is_true(Trick.beats(lock, 2, "Pair", { card(7, "Spades"), card(7, "Diamonds") }))
    -- Diamond 7 does not beat club 7.
    assert.is_false(Trick.beats(lock, 2, "Pair", { card(7, "Diamonds"), card(7, "Diamonds") }))
  end)

  it("cannot be beaten by an identical hand", function()
    local lock = { count = 2, handname = "Pair", rank = Trick.rank_of(card(7)), suit = Trick.suit_of(card(7, "Spades")) }
    assert.is_false(Trick.beats(lock, 2, "Pair", { card(7, "Spades"), card(7, "Hearts") }))
  end)

  it("lets a pair of 2s beat a pair of aces", function()
    local lock = { count = 2, handname = "Pair", rank = Trick.rank_of(card(14)) }
    assert.is_true(Trick.beats(lock, 2, "Pair", hand(2, 2)))
  end)

  -- Five-card hands compare by hand type first: this is the Two Pair and
  -- Four of a Kind case that locking on hand name could not express.
  it("compares five-card hands by tier", function()
    local lock = { count = 5, handname = "Straight", rank = Trick.rank_of(card(9)) }
    assert.is_true(Trick.beats(lock, 5, "Flush", hand(3, 4, 5, 6, 8)))
    assert.is_false(Trick.beats(lock, 5, "High Card", hand(14, 13, 12, 10, 8)))
  end)

  -- Two full houses: the triples decide, so a triple of 4s beats a triple of
  -- 3s even though the loser holds a higher pair.
  it("compares full houses by their triples", function()
    local lock = {
      count = 5,
      handname = "Full House",
      rank = Trick.rank_of(card(4)),
      suit = Trick.suit_of(card(4)),
    }
    -- Triple 5s over pair 3s beats triple 4s.
    assert.is_true(Trick.beats(lock, 5, "Full House",
      { card(5), card(5), card(5), card(3), card(3) }))
    -- Triple 3s with a pair of kings does not, despite the kings.
    assert.is_false(Trick.beats(lock, 5, "Full House",
      { card(3), card(3), card(3), card(13), card(13) }))
  end)

  it("breaks a five-card tier tie by rank then suit", function()
    local lock = {
      count = 5,
      handname = "Flush",
      rank = Trick.rank_of(card(9)),
      suit = Trick.suit_of(card(9, "Clubs")),
    }
    assert.is_true(Trick.beats(lock, 5, "Flush", { card(9, "Spades"), card(8), card(7), card(5), card(3) }))
    assert.is_false(Trick.beats(lock, 5, "Flush", { card(9, "Diamonds"), card(8), card(7), card(5), card(3) }))
  end)

  it("falls back to rank when the tiers match", function()
    local lock = { count = 5, handname = "Flush", rank = Trick.rank_of(card(9)) }
    assert.is_true(Trick.beats(lock, 5, "Flush", hand(13, 8, 7, 5, 3)))
    assert.is_false(Trick.beats(lock, 5, "Flush", hand(8, 7, 6, 5, 3)))
  end)

  it("ranks four-card plays by tier too", function()
    local lock = { count = 4, handname = "Two Pair", rank = Trick.rank_of(card(9)) }
    assert.is_true(Trick.beats(lock, 4, "Four of a Kind", hand(3, 3, 3, 3)))
    assert.is_false(Trick.beats(lock, 4, "High Card", hand(14, 12, 9, 7)))
  end)

  it("refuses a hand with nothing to compare", function()
    local lock = { count = 1, handname = "High Card", rank = Trick.rank_of(card(5)) }
    local ok, why = Trick.beats(lock, 1, "High Card", { { base = {} } })
    assert.is_false(ok)
    assert.is_truthy(why:match("no rank"))
  end)
end)

describe("the lock", function()
  before_each(function()
    load_module()
    G.GAME = { current_round = {}, modifiers = {} }
  end)

  it("records what was played", function()
    Trick.set_lock(2, "Pair", hand(7, 7))
    local lock = Trick.get_lock()
    assert.equal(2, lock.count)
    assert.equal("Pair", lock.handname)
    assert.equal(Trick.rank_of(card(7)), lock.rank)
    assert.equal(Trick.suit_of(card(7)), lock.suit)
  end)

  it("clears on demand", function()
    Trick.set_lock(2, "Pair", hand(7, 7))
    Trick.clear_lock()
    assert.is_nil(Trick.get_lock())
  end)

  -- It lives on current_round, which the game itself resets each round.
  it("lives on current_round so a new round starts clean", function()
    Trick.set_lock(2, "Pair", hand(7, 7))
    G.GAME.current_round = {}
    assert.is_nil(Trick.get_lock())
  end)

  it("survives a missing G.GAME", function()
    G.GAME = nil
    assert.has_no_errors(function()
      Trick.set_lock(2, "Pair", hand(7, 7))
      Trick.clear_lock()
    end)
    assert.is_nil(Trick.get_lock())
  end)

  it("is only active with the modifier on", function()
    G.GAME = { modifiers = {} }
    assert.is_falsy(Trick.active())
    G.GAME.modifiers.cm_trick_lock = true
    assert.is_true(Trick.active())
  end)
end)

describe("the shed bonus", function()
  before_each(load_module)
  it("pays nothing for going out on junk", function()
    assert.is_nil(Trick.shed_xmult("High Card"))
  end)

  it("pays the agreed anchors", function()
    assert.equal(3.0, Trick.shed_xmult("Straight"))
    assert.equal(4.5, Trick.shed_xmult("Four of a Kind"))
    assert.equal(1.5, Trick.shed_xmult("Pair"))
    assert.equal(6.5, Trick.shed_xmult("Flush Five"))
  end)

  it("pays more for stronger hands", function()
    assert.is_true(Trick.shed_xmult("Full House") > Trick.shed_xmult("Flush"))
    assert.is_true(Trick.shed_xmult("Flush") > Trick.shed_xmult("Straight"))
  end)

  it("is nil for an unknown hand", function()
    assert.is_nil(Trick.shed_xmult("Nonsense"))
    assert.is_nil(Trick.shed_xmult(nil))
  end)
end)

describe("Big 2 chip bonuses", function()
  local Chips

  before_each(function()
    _G.ChallengeMod = {}
    _G.G = { handlist = HANDLIST, GAME = { modifiers = {} } }
    _G.Card = { get_chip_bonus = function() return 0 end }
    assert(loadfile("smods/rules_chips.lua"))()
    Chips = _G.ChallengeMod.Chips
  end)

  -- is_suit rather than base.suit, so Wild cards count as what they are now.
  local function card(id, suit)
    return {
      base = { id = id, suit = suit },
      is_suit = function(_, s) return s == suit end,
    }
  end

  it("does nothing unless the modifiers are on", function()
    assert.equal(0, Chips.bonus(card(2, "Spades")))
  end)

  it("lifts the 2 to the top", function()
    G.GAME.modifiers.cm_rank_chips = true
    -- 2 base + 12 = 14, above an ace's 11 + 4 = 15? No: the ace is highest by
    -- chips, the 2 by rank. Chips only need the 2 to outscore a king.
    assert.equal(12, Chips.bonus(card(2)))
    assert.equal(3, Chips.bonus(card(13)))
    assert.equal(4, Chips.bonus(card(14)))
  end)

  it("leaves the number cards alone", function()
    G.GAME.modifiers.cm_rank_chips = true
    for _, id in ipairs({ 3, 5, 9, 10 }) do
      assert.equal(0, Chips.bonus(card(id)))
    end
  end)

  it("pays suits in Big 2 order", function()
    G.GAME.modifiers.cm_suit_chips = true
    assert.equal(3, Chips.bonus(card(9, "Spades")))
    assert.equal(2, Chips.bonus(card(9, "Hearts")))
    assert.equal(1, Chips.bonus(card(9, "Clubs")))
    assert.equal(0, Chips.bonus(card(9, "Diamonds")))
  end)

  it("adds rank and suit together", function()
    G.GAME.modifiers.cm_rank_chips = true
    G.GAME.modifiers.cm_suit_chips = true
    assert.equal(15, Chips.bonus(card(2, "Spades")))
  end)

  -- Stone cards have no printed rank or suit.
  it("gives rankless, suitless cards nothing", function()
    G.GAME.modifiers.cm_rank_chips = true
    G.GAME.modifiers.cm_suit_chips = true
    assert.equal(0, Chips.bonus({ base = {} }))
    assert.equal(0, Chips.bonus({}))
  end)
end)
