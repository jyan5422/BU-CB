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
  -- "decreases each Ante" means after an ante completes. Hooking the boss
  -- blind shrank mid-ante instead, so ante 1 ended at 9 rather than 10.
  it("shrinks the hand at ante end, not on boss blind", function()
    local patch = read("lovely/cm_decreasing_handsize.toml")
    assert.is_truthy(patch:match("set_eternal_ante"),
      "handsize must hook end_round(), where the ante boundary is")
    assert.is_nil(patch:match("get_type%(%) == 'Boss'"),
      "shrinking on the boss blind fires during the ante, not after it")
    -- The hand is sized from starting_params each round, so the live area
    -- alone would be reset.
    assert.is_truthy(patch:match("starting_params%.hand_size"),
      "must persist the shrink in starting_params")
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

describe("facedown reveal on game over", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  local function state(s)
    G.STATES = { GAME_OVER = 9, SELECTING_HAND = 1 }
    G.STATE = s
  end

  it("hides cards during a facedown run", function()
    G.GAME = { modifiers = { cm_all_facedown = true } }
    state(G.STATES and G.STATES.SELECTING_HAND or 1)
    assert.is_true(ChallengeMod.hide_cards())
  end)

  -- The point of the reveal: read the jokers that were hidden all run.
  it("reveals them once the run is over", function()
    G.GAME = { modifiers = { cm_all_facedown = true } }
    state(9)
    assert.is_false(ChallengeMod.hide_cards())
  end)

  it("never hides when the modifier is off", function()
    G.GAME = { modifiers = {} }
    state(1)
    assert.is_false(ChallengeMod.hide_cards())
  end)

  it("survives a missing G.GAME", function()
    G.GAME = nil
    assert.is_false(ChallengeMod.hide_cards())
  end)

  -- Hiding must go through the predicate, or the reveal cannot take effect.
  -- Each payload that sets a card to 'back' has to be guarded by hide_cards().
  it("routes the hide decisions through hide_cards()", function()
    local f = assert(io.open("lovely/cm_all_facedown.toml"))
    local patch = f:read("*a")
    f:close()
    for payload in patch:gmatch('payload = """(.-)"""') do
      if payload:match("= 'back'") then
        assert.is_truthy(payload:match("hide_cards"),
          "this payload hides cards without consulting hide_cards():\n" .. payload)
      end
    end
  end)
end)

describe("facedown reveal actually flips cards", function()
  local mod

  setup(function()
    mod = harness.load()
  end)

  -- The predicate alone was not enough: Card:init sets facing once, at
  -- creation, so by game over every card already exists and nothing re-asks.
  -- The reveal has to flip them explicitly.
  local function hidden_card()
    return { facing = "back", sprite_facing = "back" }
  end

  it("flips existing cards front", function()
    G.jokers = { cards = { hidden_card(), hidden_card() } }
    G.consumeables = { cards = { hidden_card() } }
    local counts = ChallengeMod.reveal_all()
    assert.equal(2, counts.jokers)
    assert.equal(1, counts.consumeables)
    for _, c in ipairs(G.jokers.cards) do
      assert.equal("front", c.facing)
      assert.equal("front", c.sprite_facing)
    end
  end)

  it("clears a pending flip so the animation cannot re-hide", function()
    G.jokers = { cards = { { facing = "back", sprite_facing = "back", flipping = "f2b" } } }
    ChallengeMod.reveal_all()
    assert.is_nil(G.jokers.cards[1].flipping)
  end)

  it("skips cards already face up", function()
    G.jokers = { cards = { { facing = "front", sprite_facing = "front" } } }
    local counts = ChallengeMod.reveal_all()
    assert.is_nil(counts.jokers)
  end)

  it("tolerates missing card areas", function()
    G.jokers, G.consumeables, G.hand, G.deck, G.discard, G.play = nil, nil, nil, nil, nil, nil
    assert.has_no_errors(function() ChallengeMod.reveal_all() end)
  end)

  -- Game:update drives it, so the reveal must fire from the state alone.
  it("fires on the transition into game over", function()
    G.STATES = { GAME_OVER = 9, SELECTING_HAND = 1 }
    G.GAME = { modifiers = { cm_all_facedown = true } }
    G.jokers = { cards = { hidden_card() } }
    ChallengeMod._revealed = nil

    G.STATE = 1
    Game.update(G, 0.016)
    assert.equal("back", G.jokers.cards[1].facing, "revealed while the run was still going")

    G.STATE = 9
    Game.update(G, 0.016)
    assert.equal("front", G.jokers.cards[1].facing, "did not reveal at game over")
  end)
end)

-- cm_pass carries both halves of one risk/reward rule: the discard penalty and
-- the climb refund. The coupling is implicit, so it needs asserting -- nothing
-- else would notice if the refund quietly stopped being switched on.
describe("the pass penalty and the climb refund", function()
  local challenge_mod

  setup(function()
    challenge_mod = harness.load().mod
  end)

  -- evaluate_rules takes the Game as its first argument and reads self.GAME,
  -- so a bare table with a GAME field is enough to drive it.
  local function apply(value, discards)
    local game = {
      GAME = { modifiers = {}, starting_params = { discards = discards or 3 } },
    }
    challenge_mod.evaluate_rules(game, { id = "cm_pass", value = value })
    return game.GAME
  end

  it("spends the discards and grants the refund together", function()
    local g = apply(-3)
    assert.equal(0, g.starting_params.discards)
    assert.is_true(g.modifiers.cm_pass)
    assert.is_true(g.modifiers.cm_climb_refund,
      "a discard penalty must come with the way to earn them back")
  end)

  it("never takes discards below zero", function()
    assert.equal(0, apply(-99).starting_params.discards)
  end)

  -- The penalty is a bonus/penalty rather than an absolute, so a deck granting
  -- extra discards keeps them.
  it("applies to whatever the deck granted", function()
    assert.equal(2, apply(-3, 5).starting_params.discards)
  end)

  -- Without a penalty there is nothing to earn back, so pass alone stays a
  -- plain "you may discard nothing" rule.
  it("does not grant a refund when there is no penalty", function()
    assert.is_nil(apply(0).modifiers.cm_climb_refund)
  end)
end)
