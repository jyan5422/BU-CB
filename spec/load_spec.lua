-- Smoke tests: does the mod load, and do the things that have actually broken
-- in the past still work? Every case here corresponds to a real crash.
local harness = require("spec.harness")

describe("mod load", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  it("loads without error and registers challenges", function()
    assert.is_true(#mod.ours > 30)
  end)

  it("has no duplicate ids", function()
    local seen = {}
    for _, c in ipairs(mod.ours) do
      assert.is_nil(seen[c.id], "duplicate challenge id: " .. tostring(c.id))
      seen[c.id] = true
    end
  end)

  it("never calls SMODS.Challenge", function()
    -- register() re-inserts into G.CHALLENGES and rewrites ids via
    -- add_prefixes, which duplicated every entry and broke the menu lookups.
    assert.equal(0, #mod.smods_challenge_calls)
  end)

  it("gives every challenge a name", function()
    for _, c in ipairs(mod.ours) do
      assert.is_string(c.name, "challenge without a name: " .. tostring(c.id))
      assert.is_truthy(mod.challenge_names[c.id], "no localized name: " .. c.id)
    end
  end)
end)

describe("rule localization", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  -- A rules.custom id with no ch_c_ string renders blank or faults in the
  -- rules box; this is what cm_boss_suit_final and cm_decreasing_handsize hit.
  it("has rule text for every mod-owned modifier", function()
    for _, c in ipairs(mod.ours) do
      for _, v in ipairs(c.rules and c.rules.custom or {}) do
        local own = v.id:sub(1, 3) == "cm_" or v.id:sub(1, 3) == "dm_"
        if own then
          assert.is_truthy(
            mod.v_text["ch_c_" .. v.id],
            ("%s uses %s with no ch_c_ localization"):format(c.name, v.id)
          )
        end
      end
    end
  end)
end)

describe("starting a run", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  -- SMODS.calculate_card_areas does SMODS.Challenges[G.GAME.challenge].id on
  -- the first debuff_card; an empty table crashed every challenge run.
  it("publishes every challenge to SMODS.Challenges", function()
    for _, c in ipairs(mod.ours) do
      local obj = mod.smods_challenges[c.id]
      assert.is_truthy(obj, "not in SMODS.Challenges: " .. c.id)
      assert.equal(c.id, obj.id)
    end
  end)

  -- SMODS.eval_individual then calls object:calculate(context), which a plain
  -- data table with no metatable does not have.
  it("answers :calculate(context)", function()
    for _, c in ipairs(mod.ours) do
      local obj = mod.smods_challenges[c.id]
      -- Not assert.has_no.errors: its second argument is the *expected error*,
      -- not a label, and passing a message there makes the assertion pass
      -- regardless. pcall keeps the failure attributable to a challenge.
      local ok, err = pcall(function()
        return obj:calculate({})
      end)
      assert.is_true(ok, ("calculate failed for %s: %s"):format(c.id, tostring(err)))
    end
  end)
end)

describe("completion migration", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  it("migrates every legacy id scheme onto the current ids", function()
    local expected = {
      ["Anapodaphobia"] = true, -- c_mod_*
      ["Bullseye"] = true, -- c_chmod_c_mod_*
      ["Tarot Tycoon"] = true, -- c_chmod_cm_mod_*
      ["Butterfingers"] = true, -- no _1 suffix
      ["Tarot Torture"] = true, -- renamed challenge
    }
    local found = 0
    for _, c in ipairs(mod.ours) do
      if expected[c.name] then
        assert.is_true(mod.completed[c.id] == true, "not migrated: " .. c.name)
        found = found + 1
      end
    end
    assert.equal(5, found, "a challenge under test is missing from the list")
  end)

  it("leaves unrecognised keys alone", function()
    assert.is_true(mod.completed["c_mod_who_knows_1"])
  end)

  it("keeps the old keys (non-destructive)", function()
    for key in pairs(harness.SEEDED_COMPLETIONS) do
      assert.is_true(mod.completed[key], "migration removed " .. key)
    end
  end)
end)

describe("restored challenges", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  -- Dropped by BU-CB-DEV and recovered from oceanramen/master.
  it("includes the four challenges restored from BU-CB", function()
    local want = {
      ["Cryptojacked"] = false,
      ["Jokerless?"] = false,
      ["Target Practice"] = false,
      ["Series Funding"] = false,
    }
    for _, c in ipairs(mod.ours) do
      if want[c.name] ~= nil then want[c.name] = true end
    end
    for name, present in pairs(want) do
      assert.is_true(present, "restored challenge missing: " .. name)
    end
  end)
end)
