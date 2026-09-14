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

ChallengeMod.localizeChalNames()
ChallengeMod.localizeDailyNames()
ChallengeMod.localizeMechDescriptions()

-- No SMODS.Challenge registration: the upstream handlers already append their
-- DATA tables to G.CHALLENGES, which is the list the challenge menu reads, and
-- SMODS.Challenge.register() only inserts into that same pool -- via
-- SMODS.add_prefixes, which rewrites ids to c_chmod_cm_mod_* and so no longer
-- matches the raw cm_mod_* ids that localizeChalNames and the menu use.
-- Registering here produced 33 "same key as an existing object" warnings.
--
-- SMODS.Modifier does not exist in SMODS 1.0.0-beta-1814a either; custom
-- modifiers work purely through ChallengeMod.evaluate_rules plus the ch_c_*
-- localization strings, which is why a missing string is what breaks a rule.
