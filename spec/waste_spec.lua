-- cm_waste_tax. Every number here was agreed in the design conversation
-- before it was built, so the table is the specification rather than a
-- recording of whatever the code happened to do.
local function load_module(cards_per_dollar)
  _G.ChallengeMod = {}
  _G.G = { GAME = { modifiers = { cm_waste_tax = cards_per_dollar or 2 } } }
  assert(loadfile("smods/rules_waste.lua"))()
  return _G.ChallengeMod.Waste
end

local function card(debuffed)
  return { debuff = debuffed or nil }
end

--- A play of `played` cards of which `scored` contributed.
local function hand(played, scored)
  local cards, scoring = {}, {}
  for i = 1, played do
    cards[i] = card()
    if i <= scored then scoring[#scoring + 1] = cards[i] end
  end
  return cards, scoring
end

describe("the waste tax", function()
  local Waste

  before_each(function()
    Waste = load_module()
  end)

  local function charge(played, scored)
    local cards, scoring = hand(played, scored)
    return Waste.charge_for(Waste.count_played(cards, scoring))
  end

  -- The five-card table, as agreed.
  it("charges five-card plays by how much they waste", function()
    assert.equal(2, charge(5, 1), "High Card wastes 4")
    assert.equal(1, charge(5, 2), "Pair wastes 3")
    assert.equal(1, charge(5, 3), "Three of a Kind wastes 2")
    assert.equal(0, charge(5, 4), "Two Pair and Four of a Kind waste 1")
    assert.equal(0, charge(5, 5), "Straight, Flush, Full House waste nothing")
  end)

  -- Rounding down is what forgives a single stray card.
  it("does not charge for a single wasted card", function()
    assert.equal(0, charge(2, 1), "a two-card High Card is free")
    assert.equal(0, charge(3, 2), "a pair with one kicker is free")
    assert.equal(0, charge(1, 1), "a single card wastes nothing")
  end)

  it("charges smaller plays on the same scale", function()
    assert.equal(1, charge(3, 1), "three cards, one scores")
    assert.equal(1, charge(4, 1), "four cards, one scores")
    assert.equal(1, charge(4, 2), "four cards, two score")
    assert.equal(0, charge(4, 4), "four cards, all score")
  end)

  -- A boss's debuff is not the player's choice, so it must not be billed.
  it("never charges for a debuffed card", function()
    local cards = { card(), card(), card(true), card(true), card(true) }
    local scoring = { cards[1] }
    -- Four cards fall outside the scoring hand, but three are debuffed.
    assert.equal(1, Waste.count_played(cards, scoring))
    assert.equal(0, Waste.charge_for(Waste.count_played(cards, scoring)))
  end)

  it("never charges for discarding a debuffed card", function()
    assert.equal(0, Waste.count_discarded({ card(true), card(true) }))
  end)

  -- Discards waste every card in them: none contributed.
  it("charges discards at the same rate", function()
    assert.equal(0, Waste.charge_for(Waste.count_discarded({ card() })))
    assert.equal(1, Waste.charge_for(Waste.count_discarded({ card(), card() })))
    assert.equal(2, Waste.charge_for(Waste.count_discarded({ card(), card(), card(), card() })))
  end)

  it("charges nothing for a zero-card pass", function()
    assert.equal(0, Waste.charge_for(Waste.count_discarded({})))
  end)

  it("is off unless the rule is on", function()
    _G.G.GAME.modifiers.cm_waste_tax = nil
    assert.is_false(Waste.active())
    assert.equal(0, Waste.tax_play(hand(5, 1)))
  end)

  -- The value is the price, so a challenge can make waste cheaper or dearer.
  it("takes its rate from the modifier's value", function()
    Waste = load_module(3)
    assert.equal(3, Waste.cards_per_dollar())
    assert.equal(1, charge(5, 2), "3 wasted at 3-per-dollar is $1")
    assert.equal(0, charge(5, 3), "2 wasted at 3-per-dollar is free")
  end)

  it("falls back to two per dollar on a nonsense value", function()
    Waste = load_module(0)
    assert.equal(2, Waste.cards_per_dollar())
  end)
end)
