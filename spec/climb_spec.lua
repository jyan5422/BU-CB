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

local Climb
local function load_module()
  -- Via _G explicitly: the module reads these as globals, and busted's
  -- environment does not necessarily resolve a bare assignment to _G.
  _G.ChallengeMod = {}
  _G.G = { handlist = HANDLIST }
  assert(loadfile("smods/rules_climb.lua"))()
  Climb = _G.ChallengeMod.Climb
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
    assert.is_true(Climb.rank_of(card(2)) > Climb.rank_of(card(14)))
    assert.is_true(Climb.rank_of(card(2)) > Climb.rank_of(card(13)))
  end)

  it("puts the ace above the king", function()
    assert.is_true(Climb.rank_of(card(14)) > Climb.rank_of(card(13)))
  end)

  it("makes the 3 the lowest card", function()
    for _, id in ipairs({ 4, 5, 10, 11, 14, 2 }) do
      assert.is_true(Climb.rank_of(card(id)) > Climb.rank_of(card(3)))
    end
  end)

  it("orders the middle ranks normally", function()
    assert.is_true(Climb.rank_of(card(9)) > Climb.rank_of(card(8)))
    assert.is_true(Climb.rank_of(card(11)) > Climb.rank_of(card(10)))
  end)

  -- Stone cards and anything rankless: get_id() returns a random negative, so
  -- an unguarded comparison would use garbage.
  it("gives rankless cards no rank", function()
    assert.is_nil(Climb.rank_of({ base = {} }))
    assert.is_nil(Climb.rank_of({}))
    assert.is_nil(Climb.rank_of(nil))
    assert.is_nil(Climb.rank_of(card(-482913)))
  end)
end)

describe("Big 2 suit order", function()
  before_each(load_module)

  it("orders diamonds lowest and spades highest", function()
    assert.is_true(Climb.suit_of(card(5, "Spades")) > Climb.suit_of(card(5, "Hearts")))
    assert.is_true(Climb.suit_of(card(5, "Hearts")) > Climb.suit_of(card(5, "Clubs")))
    assert.is_true(Climb.suit_of(card(5, "Clubs")) > Climb.suit_of(card(5, "Diamonds")))
  end)

  it("is nil for a card with no suit", function()
    assert.is_nil(Climb.suit_of({ base = { id = 5 } }))
    assert.is_nil(Climb.suit_of(nil))
  end)
end)

describe("hand rank", function()
  before_each(load_module)
  it("takes the highest card in the hand", function()
    assert.equal(Climb.rank_of(card(2)), (Climb.hand_rank(hand(5, 7, 2, 3))))
    assert.equal(Climb.rank_of(card(14)), (Climb.hand_rank(hand(14, 13, 3))))
  end)

  -- Big 2 decides a hand by its defining group, not its top card.
  it("decides a full house by its triple, not its top card", function()
    -- 3-3-3-9-9: the triple of 3s carries it, so it is a "three".
    local rank = Climb.hand_rank({ card(3), card(3), card(3), card(9), card(9) })
    assert.equal(Climb.rank_of(card(3)), rank)
  end)

  it("decides four of a kind by its quad, not its kicker", function()
    -- 5-5-5-5-K: the king is only a kicker.
    local rank = Climb.hand_rank({ card(5), card(5), card(5), card(5), card(13) })
    assert.equal(Climb.rank_of(card(5)), rank)
  end)

  it("decides a pair by the pair, not the odd card", function()
    local rank = Climb.hand_rank({ card(4), card(4), card(14) })
    assert.equal(Climb.rank_of(card(4)), rank)
  end)

  -- The deciding card is the highest rank, and among equals the highest suit.
  it("picks the highest suit among equal top ranks", function()
    local rank, suit = Climb.hand_rank({ card(9, "Clubs"), card(9, "Spades"), card(3) })
    assert.equal(Climb.rank_of(card(9)), rank)
    assert.equal(Climb.suit_of(card(9, "Spades")), suit)
  end)

  it("ignores rankless cards among ranked ones", function()
    local h = hand(7)
    h[#h + 1] = { base = {} }
    assert.equal(Climb.rank_of(card(7)), (Climb.hand_rank(h)))
  end)

  it("is nil for an all-rankless hand", function()
    assert.is_nil((Climb.hand_rank({ { base = {} }, { base = {} } })))
    assert.is_nil((Climb.hand_rank({})))
    assert.is_nil((Climb.hand_rank(nil)))
  end)
end)

describe("hand tier", function()
  before_each(load_module)
  it("ranks stronger hands higher", function()
    assert.is_true(Climb.hand_tier("Full House") > Climb.hand_tier("Flush"))
    assert.is_true(Climb.hand_tier("Flush") > Climb.hand_tier("Straight"))
    assert.is_true(Climb.hand_tier("Four of a Kind") > Climb.hand_tier("Full House"))
  end)

  it("puts High Card at the bottom", function()
    assert.equal(1, Climb.hand_tier("High Card"))
  end)

  it("is nil for an unknown hand", function()
    assert.is_nil(Climb.hand_tier("Nonsense"))
    assert.is_nil(Climb.hand_tier(nil))
  end)
end)

describe("beating the trick", function()
  before_each(load_module)
  it("allows anything when leading", function()
    assert.is_true(Climb.beats(nil, 1, "High Card", hand(3)))
    assert.is_true(Climb.beats(nil, 5, "High Card", hand(3, 4, 6, 8, 9)))
  end)

  it("requires the same card count", function()
    local lock = { count = 2, handname = "Pair", rank = Climb.rank_of(card(5)) }
    local ok, why = Climb.beats(lock, 1, "High Card", hand(14))
    assert.is_false(ok)
    assert.is_truthy(why:match("2 cards"))
    assert.is_false(Climb.beats(lock, 3, "Three of a Kind", hand(7, 7, 7)))
  end)

  -- Singles, pairs and triples compare by rank alone.
  it("compares small hands by rank", function()
    local lock = { count = 2, handname = "Pair", rank = Climb.rank_of(card(5)) }
    assert.is_true(Climb.beats(lock, 2, "Pair", hand(7, 7)))
    assert.is_false(Climb.beats(lock, 2, "Pair", hand(4, 4)))
  end)

  -- Big 2 has no ties: every card is distinct, so suit always decides.
  it("breaks an equal rank by suit", function()
    local lock = { count = 2, handname = "Pair", rank = Climb.rank_of(card(7)), suit = Climb.suit_of(card(7, "Clubs")) }
    -- Spade 7 beats club 7.
    assert.is_true(Climb.beats(lock, 2, "Pair", { card(7, "Spades"), card(7, "Diamonds") }))
    -- Diamond 7 does not beat club 7.
    assert.is_false(Climb.beats(lock, 2, "Pair", { card(7, "Diamonds"), card(7, "Diamonds") }))
  end)

  it("cannot be beaten by an identical hand", function()
    local lock = { count = 2, handname = "Pair", rank = Climb.rank_of(card(7)), suit = Climb.suit_of(card(7, "Spades")) }
    assert.is_false(Climb.beats(lock, 2, "Pair", { card(7, "Spades"), card(7, "Hearts") }))
  end)

  it("lets a pair of 2s beat a pair of aces", function()
    local lock = { count = 2, handname = "Pair", rank = Climb.rank_of(card(14)) }
    assert.is_true(Climb.beats(lock, 2, "Pair", hand(2, 2)))
  end)

  -- Five-card hands compare by hand type first: this is the Two Pair and
  -- Four of a Kind case that locking on hand name could not express.
  it("compares five-card hands by tier", function()
    local lock = { count = 5, handname = "Straight", rank = Climb.rank_of(card(9)) }
    assert.is_true(Climb.beats(lock, 5, "Flush", hand(3, 4, 5, 6, 8)))
    assert.is_false(Climb.beats(lock, 5, "High Card", hand(14, 13, 12, 10, 8)))
  end)

  -- Two full houses: the triples decide, so a triple of 4s beats a triple of
  -- 3s even though the loser holds a higher pair.
  it("compares full houses by their triples", function()
    local lock = {
      count = 5,
      handname = "Full House",
      rank = Climb.rank_of(card(4)),
      suit = Climb.suit_of(card(4)),
    }
    -- Triple 5s over pair 3s beats triple 4s.
    assert.is_true(Climb.beats(lock, 5, "Full House",
      { card(5), card(5), card(5), card(3), card(3) }))
    -- Triple 3s with a pair of kings does not, despite the kings.
    assert.is_false(Climb.beats(lock, 5, "Full House",
      { card(3), card(3), card(3), card(13), card(13) }))
  end)

  it("breaks a five-card tier tie by rank then suit", function()
    local lock = {
      count = 5,
      handname = "Flush",
      rank = Climb.rank_of(card(9)),
      suit = Climb.suit_of(card(9, "Clubs")),
    }
    assert.is_true(Climb.beats(lock, 5, "Flush", { card(9, "Spades"), card(8), card(7), card(5), card(3) }))
    assert.is_false(Climb.beats(lock, 5, "Flush", { card(9, "Diamonds"), card(8), card(7), card(5), card(3) }))
  end)

  it("falls back to rank when the tiers match", function()
    local lock = { count = 5, handname = "Flush", rank = Climb.rank_of(card(9)) }
    assert.is_true(Climb.beats(lock, 5, "Flush", hand(13, 8, 7, 5, 3)))
    assert.is_false(Climb.beats(lock, 5, "Flush", hand(8, 7, 6, 5, 3)))
  end)

  it("ranks four-card plays by tier too", function()
    local lock = { count = 4, handname = "Two Pair", rank = Climb.rank_of(card(9)) }
    assert.is_true(Climb.beats(lock, 4, "Four of a Kind", hand(3, 3, 3, 3)))
    assert.is_false(Climb.beats(lock, 4, "High Card", hand(14, 12, 9, 7)))
  end)

  it("refuses a hand with nothing to compare", function()
    local lock = { count = 1, handname = "High Card", rank = Climb.rank_of(card(5)) }
    local ok, why = Climb.beats(lock, 1, "High Card", { { base = {} } })
    assert.is_false(ok)
    assert.is_truthy(why:match("no rank"))
  end)
end)

describe("the lock", function()
  before_each(function()
    load_module()
    -- The lock is stamped with G.GAME.round, so the fixture needs one.
    G.GAME = { round = 1, current_round = {}, modifiers = {} }
  end)

  it("records what was played", function()
    Climb.set_lock(2, "Pair", hand(7, 7))
    local lock = Climb.get_lock()
    assert.equal(2, lock.count)
    assert.equal("Pair", lock.handname)
    assert.equal(Climb.rank_of(card(7)), lock.rank)
    assert.equal(Climb.suit_of(card(7)), lock.suit)
  end)

  -- Same bug as the draw flag: current_round is mutated field by field
  -- between rounds, so a lock of our own survived and rejected the next
  -- round's opening hand.
  -- The bug this replaced: keying off any_hand_drawn did not work, because
  -- new_round clears it and the deal sets it true again, so a lock from the
  -- previous round looked current and rejected the first hand.
  it("expires when the round number changes", function()
    Climb.set_lock(2, "Pair", hand(7, 7))
    assert.is_truthy(Climb.get_lock())
    G.GAME.round = 2
    assert.is_nil(Climb.get_lock())
  end)

  it("clears on demand", function()
    Climb.set_lock(2, "Pair", hand(7, 7))
    Climb.clear_lock()
    assert.is_nil(Climb.get_lock())
  end)

  -- It lives on current_round, which the game itself resets each round.
  it("lives on current_round so a new round starts clean", function()
    Climb.set_lock(2, "Pair", hand(7, 7))
    G.GAME.current_round = {}
    assert.is_nil(Climb.get_lock())
  end)

  it("survives a missing G.GAME", function()
    G.GAME = nil
    assert.has_no_errors(function()
      Climb.set_lock(2, "Pair", hand(7, 7))
      Climb.clear_lock()
    end)
    assert.is_nil(Climb.get_lock())
  end)

  it("is only active with the modifier on", function()
    G.GAME = { modifiers = {} }
    assert.is_falsy(Climb.active())
    G.GAME.modifiers.cm_climb = true
    assert.is_true(Climb.active())
  end)
end)

describe("the shed bonus", function()
  before_each(load_module)

  it("pays nothing for going out on junk", function()
    assert.is_nil(Climb.shed_xmult("High Card"))
  end)

  -- Keyed on what the hand contains, so a pair is X2 wherever it appears.
  it("pays X2 for a pair, two pair or a flush", function()
    assert.equal(2, Climb.shed_xmult("Pair"))
    assert.equal(2, Climb.shed_xmult("Two Pair"))
    assert.equal(2, Climb.shed_xmult("Flush"))
  end)

  it("pays X3 for a triple, a straight or a full house", function()
    assert.equal(3, Climb.shed_xmult("Three of a Kind"))
    assert.equal(3, Climb.shed_xmult("Straight"))
    -- A full house contains a triple; it outranks a straight but pays the same.
    assert.equal(3, Climb.shed_xmult("Full House"))
  end)

  it("pays X4 for four of a kind and anything above it", function()
    for _, h in ipairs({ "Four of a Kind", "Straight Flush", "Five of a Kind",
                         "Flush House", "Flush Five" }) do
      assert.equal(4, Climb.shed_xmult(h), h .. " should pay X4")
    end
  end)

  it("is nil for an unknown hand", function()
    assert.is_nil(Climb.shed_xmult("Nonsense"))
    assert.is_nil(Climb.shed_xmult(nil))
  end)

  -- The rule text quotes the ceiling, so it lies silently if this drifts.
  it("tops out at the X4 the rule text promises", function()
    local max = 0
    for _, h in ipairs(G.handlist) do
      local x = Climb.shed_xmult(h)
      if x and x > max then max = x end
    end
    assert.equal(4, max)
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

  -- Chips must agree with the rank order: the 2 is the highest card, so it
  -- also scores most. An earlier version scored the ace above it.
  it("makes the 2 score highest", function()
    G.GAME.modifiers.cm_rank_chips = true
    local function total(id, base) return base + Chips.bonus(card(id)) end
    assert.equal(15, total(2, 2))
    assert.equal(14, total(14, 11))
    assert.equal(13, total(13, 10))
    assert.is_true(total(2, 2) > total(14, 11), "the 2 must outscore the ace")
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
    -- +13 rank, +3 spades: a 2 of spades scores 2 + 16 = 18.
    assert.equal(16, Chips.bonus(card(2, "Spades")))
  end)

  -- Stone cards have no printed rank or suit.
  it("gives rankless, suitless cards nothing", function()
    G.GAME.modifiers.cm_rank_chips = true
    G.GAME.modifiers.cm_suit_chips = true
    assert.equal(0, Chips.bonus({ base = {} }))
    assert.equal(0, Chips.bonus({}))
  end)
end)

describe("no redraw", function()
  local Draw

  before_each(function()
    _G.ChallengeMod = {}
    _G.Game = { update = function() end }
    _G.G = {
      handlist = HANDLIST,
      GAME = { modifiers = {}, current_round = {} },
      STATES = { TAROT_PACK = 1, SPECTRAL_PACK = 2, SMODS_BOOSTER_OPENED = 3, SELECTING_HAND = 4 },
      STATE = 4,
      hand = { cards = {} },
    }
    assert(loadfile("smods/rules_draw.lua"))()
    Draw = _G.ChallengeMod.Draw
  end)

  it("allows everything when off", function()
    G.GAME.current_round.any_hand_drawn = true
    assert.is_true(Draw.allow())
  end)

  -- The modifier holds the hand size bonus, so its value is a number rather
  -- than true. Testing == true would silently disable the whole rule.
  it("is still active when the value is a number", function()
    G.GAME.modifiers.cm_no_redraw = 5
    G.GAME.current_round.any_hand_drawn = true
    assert.is_false(Draw.allow())
  end)

  it("reports the hand size bonus", function()
    G.GAME.modifiers.cm_no_redraw = 5
    assert.equal(5, Draw.hand_bonus())
  end)

  it("reports no bonus when given a bare true", function()
    G.GAME.modifiers.cm_no_redraw = true
    assert.equal(0, Draw.hand_bonus())
  end)

  it("reports no bonus when off", function()
    assert.equal(0, Draw.hand_bonus())
  end)

  -- The opening deal goes through the same function as every refill, so
  -- blocking all draws would start the round with an empty hand.
  it("allows the opening deal", function()
    G.GAME.modifiers.cm_no_redraw = true
    assert.is_true(Draw.allow())
  end)

  it("blocks refills once the round has dealt", function()
    G.GAME.modifiers.cm_no_redraw = true
    G.GAME.current_round.any_hand_drawn = true
    assert.is_false(Draw.allow())
  end)

  -- Booster packs draw into the hand for their selection UI.
  it("still fills booster packs", function()
    G.GAME.modifiers.cm_no_redraw = true
    G.GAME.current_round.any_hand_drawn = true
    for _, state in ipairs({ G.STATES.TAROT_PACK, G.STATES.SPECTRAL_PACK, G.STATES.SMODS_BOOSTER_OPENED }) do
      G.STATE = state
      assert.is_true(Draw.allow(), "booster pack draw was blocked")
    end
  end)

  -- The bug this replaced: current_round is mutated field by field between
  -- rounds, not replaced, so a key of our own survived and blocked the next
  -- round's opening deal. any_hand_drawn is the game's own flag and is one of
  -- the fields it clears, so a new round deals again.
  it("deals again next round", function()
    G.GAME.modifiers.cm_no_redraw = true
    G.GAME.current_round.any_hand_drawn = true
    assert.is_false(Draw.allow())
    -- What the game actually does at the start of a round.
    G.GAME.current_round.any_hand_drawn = nil
    assert.is_true(Draw.allow())
  end)
end)

-- Printed nominals, needed because the wrapper reads base.nominal.
local NOMINAL_FOR = {
  [5] = 5, [10] = 10, [11] = 10, [12] = 10, [13] = 10, [14] = 11, [2] = 2,
}

describe("Big 2 sort order", function()
  local nominal

  before_each(function()
    _G.ChallengeMod = {}
    _G.G = { handlist = HANDLIST, GAME = { modifiers = {} } }
    -- Mirrors the real formula: 10*nominal + suit terms + 10*face_nominal.
    -- A stub returning a bare nominal is what let a too-small shift pass --
    -- adding 13 to a raw 2 looks like it beats 11, but against the scaled
    -- values it does not.
    local NOMINAL = {
      [5] = 5, [10] = 10, [11] = 10, [12] = 10, [13] = 10, [14] = 11, [2] = 2,
    }
    local FACE = { [11] = 0.1, [12] = 0.2, [13] = 0.3, [14] = 0.4 }
    _G.SMODS = { has_no_rank = function() return false end }
    _G.Card = {
      get_nominal = function(self, mod)
        local n = NOMINAL[self.base.id] or 0
        local suit = mod == "suit" and 4 * 10000 or 4
        return 10 * n + suit + 10 * (FACE[self.base.id] or 0)
      end,
    }
    assert(loadfile("smods/rules_sort.lua"))()
    nominal = function(id, mod)
      return _G.Card.get_nominal({ base = { id = id, nominal = NOMINAL_FOR[id] } }, mod)
    end
  end)

  it("leaves the order alone when off", function()
    assert.equal(24, nominal(2))
  end)

  -- The mistake this fixes: a 2 sitting next to the 3s, so it reads as the
  -- weakest card when it is the strongest.
  it("sorts the 2 above the ace", function()
    G.GAME.modifiers.cm_rank_chips = true
    assert.is_true(nominal(2) > nominal(14))
  end)

  it("moves only the 2", function()
    local plain = {}
    for _, id in ipairs({ 5, 10, 11, 12, 13, 14 }) do plain[id] = nominal(id) end
    G.GAME.modifiers.cm_rank_chips = true
    for _, id in ipairs({ 5, 10, 11, 12, 13, 14 }) do
      assert.equal(plain[id], nominal(id), "rank " .. id .. " should be untouched")
    end
  end)

  -- Suit sorting multiplies rank by 10000, so the shift has to scale with it.
  it("keeps suit sorting consistent", function()
    G.GAME.modifiers.cm_rank_chips = true
    assert.is_true(nominal(2, "suit") > nominal(14, "suit"))
  end)
end)

describe("alert rate limiting", function()
  -- Selection-change hints fire faster than an attention_text holds, so
  -- several used to sit on top of each other and become unreadable. This
  -- mirrors the limiter in rules_climb_wiring.lua.
  local shown, alert_until, now

  local function alert(text, opts)
    opts = opts or {}
    local hold = opts.hold or 0.9
    if not opts.force and now < alert_until then return end
    alert_until = math.max(alert_until, now) + hold
    shown = shown + 1
  end

  before_each(function()
    shown, alert_until, now = 0, 0, 0
  end)

  it("shows one hint for a burst of selection changes", function()
    for _ = 1, 10 do alert("beat 9") end
    assert.equal(1, shown)
  end)

  -- A committed action must always be reported, even mid-window.
  it("lets a forced alert through", function()
    alert("beat 9")
    alert("does not beat it", { force = true })
    assert.equal(2, shown)
  end)

  it("extends the window so forced alerts do not overlap", function()
    alert("does not beat it", { hold = 1.6, force = true })
    local first = alert_until
    alert("pass", { hold = 1.2, force = true })
    assert.is_true(alert_until > first)
  end)

  it("resumes hints once the window passes", function()
    alert("beat 9")
    now = alert_until + 0.1
    alert("beat 9")
    assert.equal(2, shown)
  end)
end)

describe("an empty hand ends the round", function()
  -- Observed in play: 0/13 cards, 1 hand, 0 discards. With no cards there is
  -- nothing to play, and with no discards nothing to pass with, so the round
  -- could neither be played nor ended. The design doc called for this and the
  -- code never did it.
  local function read(path)
    local f = assert(io.open(path))
    local s = f:read("*a")
    f:close()
    return s
  end

  it("zeroes hands_left so the game's own resolution runs", function()
    local patch = read("lovely/cm_no_redraw_resolve.toml")
    assert.is_truthy(patch:match("hands_left = 0"),
      "must end the round when the hand is empty")
    assert.is_truthy(patch:match("#G%.hand%.cards == 0"),
      "must key off an empty hand")
    assert.is_truthy(patch:match("cm_no_redraw"),
      "must only apply when the no-redraw rule is on")
  end)

  -- It has to run before the game's check, or the decision is already made.
  it("runs before the round resolution", function()
    local patch = read("lovely/cm_no_redraw_resolve.toml")
    assert.is_truthy(patch:match('position = "before"'))
    assert.is_truthy(patch:match("G%.GAME%.chips %- G%.GAME%.blind%.chips >= 0"),
      "anchor moved; it must sit on the round resolution branch")
  end)
end)

describe("the shed multiplier applies on every scoring pass", function()
  -- The trace showed the same played hand banking twice: 576 with the bonus,
  -- then 192 without. The later value wins, so a guard that refused to
  -- re-apply meant the un-multiplied score was the one kept.
  local Climb

  before_each(function()
    _G.ChallengeMod = {}
    _G.G = {
      handlist = HANDLIST,
      GAME = {
        modifiers = { cm_shed_bonus = true },
        current_round = { hands_played = 1 },
        last_hand_played = "Three of a Kind",
        round = 1,
      },
      hand = { cards = {} },
    }
    assert(loadfile("smods/rules_climb.lua"))()
    Climb = _G.ChallengeMod.Climb
  end)

  it("returns the same multiplier when asked repeatedly", function()
    local first = Climb.shed_xmult(G.GAME.last_hand_played)
    local second = Climb.shed_xmult(G.GAME.last_hand_played)
    assert.equal(3, first)
    assert.equal(first, second, "a second scoring pass must get the same bonus")
  end)

  -- The announcement is the part that must not repeat.
  it("keeps the announcement separate from the multiplier", function()
    local f = assert(io.open("smods/rules_climb_wiring.lua"))
    local src = f:read("*a")
    f:close()
    assert.is_truthy(src:match("shed_announce"),
      "the flash needs its own once-per-hand guard")
    assert.is_nil(src:match("shed_applied == this_hand"),
      "the multiplier must not be guarded per hand; the later pass wins")
  end)
end)
