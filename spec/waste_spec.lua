-- cm_waste_tax. Every number here was agreed in the design conversation
-- before it was built, so the table is the specification rather than a
-- recording of whatever the code happened to do.
local function load_module(cards_per_dollar, scoring_for_discard)
  _G.ChallengeMod = {}
  _G.G = {
    GAME = { modifiers = { cm_waste_tax = cards_per_dollar or 2 } },
    -- Discards are judged by the game's own hand detector, so the stub has to
    -- answer like it does: text plus a poker_hands table keyed by that text.
    FUNCS = {
      get_poker_hand_info = function(cards)
        local scoring = scoring_for_discard and scoring_for_discard(cards) or {}
        return "Stub Hand", "Stub Hand", { ["Stub Hand"] = { scoring } }
      end,
    },
  }
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
    Waste = load_module(2, function() return {} end)
    assert.equal(0, Waste.count_discarded({ card(true), card(true) }))
  end)

  -- A discard is judged exactly as a play is: the tax measures junk, and a
  -- real combination is not junk wherever it goes.
  it("charges a junk discard like a junk play", function()
    -- Nothing in the discarded set scores.
    Waste = load_module(2, function() return {} end)
    assert.equal(2, Waste.charge_for(Waste.count_discarded({ card(), card(), card(), card(), card() })))
    assert.equal(0, Waste.charge_for(Waste.count_discarded({ card() })))
  end)

  it("does not charge for discarding a real hand", function()
    -- Every discarded card belongs to the combination.
    Waste = load_module(2, function(cards) return cards end)
    assert.equal(0, Waste.charge_for(Waste.count_discarded(
      { card(), card(), card(), card(), card() })),
      "binning a flush is a choice, not waste")
  end)

  it("charges a discard only for the cards outside the combination", function()
    -- A pair plus three unrelated cards: two score, three do not.
    Waste = load_module(2, function(cards) return { cards[1], cards[2] } end)
    assert.equal(1, Waste.charge_for(Waste.count_discarded(
      { card(), card(), card(), card(), card() })))
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

-- Two forced alerts at once overprint each other, and "below the play area"
-- is only clear of the hand while something is actually in the play area.
-- Seen in play: "-$1 Wasted" printed across the hand, on top of "pass".
describe("announcing the charge", function()
  local module

  setup(function()
    local f = assert(io.open("smods/rules_climb_wiring.lua"))
    module = f:read("*a")
    f:close()
  end)

  it("folds the discard charge into the pass message", function()
    assert.is_truthy(module:match('Pass  %-%$'),
      "a pass should carry its own cost, not trigger a second alert")
  end)

  it("places the charge by whether anything was played", function()
    assert.is_truthy(module:match("under_play = has_play"),
      "below the play area is only safe when the play area holds cards")
  end)
end)

describe("silent charging", function()
  local Waste

  before_each(function()
    _G.ChallengeMod = {}
    _G.G = { GAME = { modifiers = { cm_waste_tax = 2 } } }
    assert(loadfile("smods/rules_waste.lua"))()
    Waste = _G.ChallengeMod.Waste
  end)

  it("still takes the money when silent", function()
    local taken = 0
    _G.ease_dollars = function(mod) taken = taken + mod end
    Waste.charge(2, true)
    assert.equal(-2, taken, "silent must mean unannounced, not unbilled")
  end)
end)

-- Every rule that has something to say about a selection says it in the same
-- place at the same moment, so they must share one message. As separate forced
-- alerts the shed payout and the waste charge printed over each other.
describe("the selection announcement", function()
  local module

  setup(function()
    local f = assert(io.open("smods/rules_climb_wiring.lua"))
    module = f:read("*a")
    f:close()
  end)

  it("composes one message instead of one alert per rule", function()
    assert.is_truthy(module:match("selection_flash"))
    local body = module:match("function ChallengeMod%.Climb%.selection_flash(.-)\nend")
    assert.is_truthy(body, "selection_flash not found")
    local alerts = select(2, body:gsub("alert%(", ""))
    assert.equal(1, alerts, "exactly one alert, however many rules contribute")
  end)

  it("says nothing when no rule has anything to say", function()
    assert.is_truthy(module:match('if text == "" then return end'))
  end)

  -- Two selections in a row that are worth the same thing should not re-flash.
  it("only speaks when the message changes", function()
    assert.is_truthy(module:match("if text == selection_flashed then return end"))
  end)
end)
