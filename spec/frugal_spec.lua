-- cm_frugal_bonus. Strict: one unscored card forfeits the whole payment.
-- Paying per scoring card regardless would reward playing rather than playing
-- clean, which is the distinction the rule exists to draw.
local function load_modules(rate)
  _G.ChallengeMod = {}
  _G.G = { GAME = { modifiers = { cm_frugal_bonus = rate or 2, cm_waste_tax = 2 } } }
  assert(loadfile("smods/rules_waste.lua"))()
  assert(loadfile("smods/rules_frugal.lua"))()
  return _G.ChallengeMod.Frugal, _G.ChallengeMod.Waste
end

local function card(debuffed)
  return { debuff = debuffed or nil }
end

local function hand(played, scored)
  local cards, scoring = {}, {}
  for i = 1, played do
    cards[i] = card()
    if i <= scored then scoring[#scoring + 1] = cards[i] end
  end
  return cards, scoring
end

describe("the frugality bonus", function()
  local Frugal

  before_each(function()
    Frugal = load_modules()
  end)

  local function earns(played, scored)
    return Frugal.reward(hand(played, scored))
  end

  -- The agreed table.
  it("pays a fully scoring hand by its size", function()
    assert.equal(2, earns(5, 5), "straight, flush, full house")
    assert.equal(2, earns(4, 4), "two pair or quads played as four")
    assert.equal(1, earns(3, 3), "a triple")
    assert.equal(1, earns(2, 2), "a pair")
    assert.equal(0, earns(1, 1), "a single pays nothing, so dribbling is not income")
  end)

  -- Strict. This is the whole point: one stray card and the payment is gone.
  it("pays nothing when any card is unscored", function()
    assert.equal(0, earns(5, 4), "two pair or quads played as five")
    assert.equal(0, earns(5, 3), "three of a kind")
    assert.equal(0, earns(5, 2), "pair")
    assert.equal(0, earns(5, 1), "high card")
    assert.equal(0, earns(3, 2), "a pair with a kicker")
  end)

  -- A boss's debuff is not a choice, so it must not forfeit the payment any
  -- more than it triggers the fine.
  it("is not forfeited by a debuffed card outside the scoring hand", function()
    local cards = { card(), card(), card(true) }
    local scoring = { cards[1], cards[2] }
    assert.equal(1, Frugal.reward(cards, scoring))
  end)

  it("still pays for a debuffed card inside the combination", function()
    local cards = { card(), card(true) }
    assert.equal(1, Frugal.reward(cards, cards), "the player chose the combination")
  end)

  it("is off unless the rule is on", function()
    _G.G.GAME.modifiers.cm_frugal_bonus = nil
    assert.is_false(Frugal.active())
    assert.equal(0, Frugal.pay_play(hand(5, 5)))
  end)

  it("takes its own rate, not the tax's", function()
    Frugal = load_modules(3)
    assert.equal(3, Frugal.cards_per_dollar())
    assert.equal(1, earns(3, 3))
    assert.equal(0, earns(2, 2))
  end)
end)

-- Under the strict rule the fine and the payment can never both apply: zero
-- unscored cards means no fine, two or more means no payment. The messaging
-- relies on that to show one signed figure.
describe("the two halves together", function()
  local Frugal, Waste

  before_each(function()
    Frugal, Waste = load_modules()
  end)

  it("never fines and pays for the same hand", function()
    for played = 1, 5 do
      for scored = 1, played do
        local cards, scoring = hand(played, scored)
        local fine = Waste.charge_for(Waste.count_played(cards, scoring))
        local pay = Frugal.reward(cards, scoring)
        assert.is_true(fine == 0 or pay == 0,
          ("%d played, %d scored: fined %d and paid %d"):format(played, scored, fine, pay))
      end
    end
  end)

  -- The net table from the design conversation.
  it("nets as agreed on five-card plays", function()
    local function net(scored)
      local cards, scoring = hand(5, scored)
      return Frugal.reward(cards, scoring)
        - Waste.charge_for(Waste.count_played(cards, scoring))
    end
    assert.equal(2, net(5), "straight, flush, full house")
    assert.equal(0, net(4), "two pair, four of a kind")
    assert.equal(-1, net(3), "three of a kind")
    assert.equal(-1, net(2), "pair")
    assert.equal(-2, net(1), "high card")
  end)
end)
