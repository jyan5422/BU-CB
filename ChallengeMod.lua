-- SMODS entry point. Mirrors the load order that lovely/challenge_init.toml
-- drives in the Lovely build: core -> handlers/mechanics -> localize -> register.
ChallengeMod = {}
ChallengeMod.DAILY = {}
ChallengeMod.DAILY.DATE = {}
ChallengeMod.PATH = SMODS.current_mod.path

local function load_file(rel)
  assert(loadfile(ChallengeMod.PATH .. rel))()
end

-- The upstream handlers open with require("lovely") / require("nativefs").
-- Under SMODS neither is a package, so they are preloaded here to keep those
-- files byte-identical to upstream and cheap to re-pull. Only nativefs is
-- really used (directory listing); `lovely` is required but never referenced,
-- so mod_dir is filled in for parity and nothing more.
package.preload["lovely"] = function()
  return { mod_dir = ChallengeMod.PATH .. "..", version = "smods-shim" }
end
package.preload["nativefs"] = function()
  return assert(loadfile(ChallengeMod.PATH .. "nativefs.lua"))()
end

-- core.lua opens with its own `ChallengeMod = {}` and an initChallenges() that
-- re-reads these files via nativefs; both would undo the table above, so the
-- shared helpers are loaded and the Lovely-only bootstrap is left behind.
load_file("smods/core_shared.lua")
load_file("challenge_handler.lua")
load_file("mechanics.lua")
load_file("Daily/daily_handler.lua")
load_file("Daily/daily_mechanics.lua")
load_file("smods/hooks.lua")
load_file("smods/joker_timing.lua")
load_file("smods/facedown_reveal.lua")
load_file("smods/rules_climb.lua")
load_file("smods/rules_chips.lua")
load_file("smods/rules_straights.lua")
load_file("smods/rules_draw.lua")
load_file("smods/rules_sort.lua")
load_file("smods/rules_climb_wiring.lua")

ChallengeMod.localizeChalNames()
ChallengeMod.localizeDailyNames()
ChallengeMod.localizeMechDescriptions()

-- After the ids are final, so completions are copied onto the right keys.
load_file("smods/migrate_progress.lua")

-- SMODS looks the running challenge up by id; see the file for why this does
-- not go through SMODS.Challenge().
load_file("smods/register.lua")

-- SMODS.Modifier does not exist in SMODS 1.0.0-beta-1814a: custom modifiers
-- work purely through ChallengeMod.evaluate_rules plus the ch_c_* localization
-- strings, which is why a missing string is what breaks a rule.
