-- Custom blind curves have to respect the chosen stake.
--
-- cm_scaling replaces vanilla get_blind_amount's table wholesale, so it never
-- read G.GAME.modifiers.scaling -- the field stakes raise. That was invisible
-- while stake was hardcoded to 1 and became real the moment stake was
-- selectable: Stake Finals on Gold was using White-stake blinds.
local harness = require("spec.harness")

-- The vanilla curves, used ONLY to assert the ratio the code derives at
-- runtime. The code itself measures the real function rather than copying
-- these, so a change upstream shows up as a failure here rather than silently
-- diverging in play.
local VANILLA = {
  [1] = { 300, 800, 2000, 5000, 11000, 20000, 35000, 50000 },
  [2] = { 300, 900, 2600, 8000, 20000, 36000, 60000, 100000 },
  [3] = { 300, 1000, 3200, 9000, 25000, 60000, 110000, 200000 },
}

local CUSTOM = { 100, 300, 900, 2000, 5000, 9000, 15000, 25000 }

describe("custom blind scaling and stakes", function()
  local blind_amount

  before_each(function()
    harness.load()
    -- The mod wraps whatever get_blind_amount was global when it loaded, so
    -- what is exercised here is its override over the harness's vanilla copy.
    blind_amount = _G.get_blind_amount
    _G.G.GAME = _G.G.GAME or {}
    _G.G.GAME.modifiers = _G.G.GAME.modifiers or {}
  end)

  local function amount_at(ante, scaling)
    _G.G.GAME.modifiers.cm_scaling = CUSTOM
    _G.G.GAME.modifiers.scaling = scaling
    _G.G.GAME.modifiers.cm_all_blind_increase = nil
    return blind_amount(ante)
  end

  -- The default path must not move. Every existing challenge is tuned at
  -- White stake and those numbers are the design.
  it("leaves a custom curve alone at white stake", function()
    for ante = 1, 8 do
      assert.equal(CUSTOM[ante], amount_at(ante, 1),
        "ante " .. ante .. " must be untouched at scaling 1")
    end
  end)

  it("leaves a custom curve alone when no stake scaling is set", function()
    for ante = 1, 8 do
      assert.equal(CUSTOM[ante], amount_at(ante, nil))
    end
  end)

  -- The point of the feature: a custom curve gets as much harder between
  -- stakes as a vanilla one does, per ante rather than by a flat factor.
  it("raises a custom curve by the vanilla ratio", function()
    for _, scaling in ipairs({ 2, 3 }) do
      for ante = 2, 8 do
        local expected = CUSTOM[ante] * (VANILLA[scaling][ante] / VANILLA[1][ante])
        local actual = amount_at(ante, scaling)
        -- Rounded to a blind-shaped number, so compare within that step.
        local tolerance = math.max(expected * 0.1, 1)
        assert.is_true(math.abs(actual - expected) <= tolerance,
          ("scaling %d ante %d: got %s, expected about %s")
            :format(scaling, ante, tostring(actual), tostring(expected)))
      end
    end
  end)

  it("never lowers a blind for a higher stake", function()
    for ante = 1, 8 do
      local white = amount_at(ante, 1)
      assert.is_true(amount_at(ante, 2) >= white, "ante " .. ante .. " at scaling 2")
      assert.is_true(amount_at(ante, 3) >= amount_at(ante, 2), "ante " .. ante .. " at scaling 3")
    end
  end)

  -- Past ante 8 the custom path extrapolates from amounts[8], so the stake has
  -- to be applied to that anchor or the whole endgame ignores it.
  it("carries the stake into the extrapolated antes", function()
    assert.is_true(amount_at(12, 3) > amount_at(12, 1),
      "a higher stake must still bite after ante 8")
  end)
end)
