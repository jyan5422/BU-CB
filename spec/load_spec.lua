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

describe("saving a run", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  -- Starting a challenge sets G.GAME.challenge_tab to the challenge table, and
  -- save_run serializes it through recursive_table_cull, which walks every
  -- nested table with pairs(). Anything reachable that loops -- a mod object's
  -- dependency tree, for instance -- kills the save with "loop in gettable".
  -- Metatables are fine: pairs() does not follow __index.
  it("keeps challenge tables free of unserializable values", function()
    local function walk(t, path, seen, depth)
      assert.is_true(depth < 20, "table nests too deeply at " .. path)
      assert.is_nil(seen[t], "cycle reachable from the challenge table at " .. path)
      seen[t] = true
      for k, v in pairs(t) do
        local where = path .. "." .. tostring(k)
        assert.not_equal("function", type(v), "function value at " .. where)
        if type(v) == "table" then walk(v, where, seen, depth + 1) end
      end
      seen[t] = nil
    end

    for _, c in ipairs(mod.ours) do
      walk(c, c.id, {}, 0)
    end
  end)
end)

describe("joker timing modifiers", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  -- BU-CB disabled these by patching the per-joker eval in state_events.lua.
  -- 1.0.1o replaced those loops with SMODS.calculate_context, so the patterns
  -- stopped matching and the rules silently did nothing. The wrapper now skips
  -- the 'jokers' dispatch for the relevant contexts.
  local cases = {
    { modifier = "cm_no_after_hand", flag = "after" },
    { modifier = "cm_no_after_round", flag = "end_of_round" },
    { modifier = "cm_no_on_discard", flag = "discard" },
  }

  it("skips joker evaluation when the modifier is on", function()
    for _, case in ipairs(cases) do
      G.GAME = { modifiers = { [case.modifier] = true } }
      harness.last_areas = {}
      SMODS.calculate_card_areas("jokers", { [case.flag] = true })
      assert.equal(0, #harness.last_areas,
        case.modifier .. " did not skip the jokers dispatch")
    end
  end)

  it("still evaluates jokers when the modifier is off", function()
    for _, case in ipairs(cases) do
      G.GAME = { modifiers = {} }
      harness.last_areas = {}
      SMODS.calculate_card_areas("jokers", { [case.flag] = true })
      assert.equal(1, #harness.last_areas,
        case.modifier .. " suppressed jokers when it should not")
    end
  end)

  it("leaves other card areas alone", function()
    G.GAME = { modifiers = { cm_no_after_hand = true } }
    harness.last_areas = {}
    SMODS.calculate_card_areas("playing_cards", { after = true })
    SMODS.calculate_card_areas("individual", { after = true })
    -- The rules say Joker abilities; seals and consumables must still fire.
    assert.equal(2, #harness.last_areas)
  end)

  it("returns a table so calculate_context can merge flags", function()
    G.GAME = { modifiers = { cm_no_after_hand = true } }
    local ret = SMODS.calculate_card_areas("jokers", { after = true })
    assert.equal("table", type(ret))
  end)
end)

describe("applying challenge rules", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  -- The rule dispatch is a Lovely patch into game.lua's rule loop, not a
  -- Game:start_run wrapper: that loop writes G.GAME.starting_params and
  -- start_run consumes them further down the same function, so a wrapper runs
  -- too late and the modifiers never take effect.
  it("dispatches rules from a lovely patch, not a start_run wrap", function()
    local hooks = assert(io.open("smods/hooks.lua")):read("*a")
    assert.is_nil(
      hooks:match("ChallengeMod%.evaluate_rules"),
      "rule dispatch is back in hooks.lua, where it runs after starting_params is consumed"
    )

    local patch = assert(io.open("lovely/cm_evaluate_rules.toml")):read("*a")
    assert.is_truthy(patch:match("ChallengeMod%.evaluate_rules"), "patch lost its payload")
    assert.is_truthy(patch:match("evaluate_daily_modifiers"), "patch lost the daily dispatch")
    -- Injecting at the same anchor upstream used keeps it inside the loop.
    assert.is_truthy(patch:match("v%.id == 'no_reward'"), "patch lost its anchor")
    assert.is_truthy(patch:match('position = "before"'), "payload must precede the anchor")
  end)

  -- evaluate_rules is what turns a rules.custom entry into a G.GAME.modifiers
  -- value, so every id a challenge uses needs a branch or the rule does
  -- nothing. Reported rather than asserted: some ids are vanilla and handled
  -- by the game itself.
  it("handles the mod-owned modifier ids its challenges use", function()
    local mechanics = assert(io.open("mechanics.lua")):read("*a")
      .. assert(io.open("Daily/daily_mechanics.lua")):read("*a")
    local unhandled = {}
    for _, c in ipairs(mod.ours) do
      for _, v in ipairs(c.rules and c.rules.custom or {}) do
        local own = v.id:sub(1, 3) == "cm_" or v.id:sub(1, 3) == "dm_"
        if own and v.id ~= "cm_credit" and v.id ~= "cm_VERSION" then
          if not mechanics:match("v%.id == ['\"]" .. v.id .. "['\"]") then
            unhandled[v.id] = (unhandled[v.id] or "") .. " " .. c.name
          end
        end
      end
    end
    for id, where in pairs(unhandled) do
      print("NOTE: " .. id .. " has no evaluate_rules branch, used by" .. where)
    end
  end)
end)

describe("lovely patch anchors", function()
  local function read(path)
    local f = assert(io.open(path))
    local s = f:read("*a")
    f:close()
    return s
  end

  -- Blind:get_type() derives the type from self.name, which set_blind assigns
  -- partway through. Anchoring before that read the *previous* blind's name --
  -- empty on the first one -- so 'Boss' never matched and the hand never
  -- shrank, even with the modifier correctly set.
  it("shrinks the hand after the blind's name is assigned", function()
    local patch = read("lovely/cm_decreasing_handsize.toml")
    assert.is_truthy(patch:match("self%.dollars = blind and blind%.dollars or 0"),
      "anchor moved; it must sit after `self.name = ...` for get_type() to work")
    assert.is_nil(patch:match("pattern = 'self%.config%.blind = blind or {}'"),
      "anchored before self.name again -- get_type() will see the previous blind")
  end)

  -- Card:init runs for menu deck previews too, where G.GAME is nil, so an
  -- unguarded G.GAME.modifiers index throws.
  it("guards every G.GAME.modifiers read in the facedown patches", function()
    local patch = read("lovely/cm_all_facedown.toml")
    for line in patch:gmatch("[^\n]+") do
      if line:match("G%.GAME%.modifiers%.cm_all_facedown") then
        assert.is_truthy(
          line:match("G%.GAME and G%.GAME%.modifiers and"),
          "unguarded G.GAME.modifiers read: " .. line
        )
      end
    end
  end)
end)
