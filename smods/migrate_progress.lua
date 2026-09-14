-- Migrates challenge completions from older BU-CB id schemes to the ids this
-- build uses, so progress survives the moves between them.
--
-- Completion is stored per challenge id under
-- challenge_progress.completed[id]. Three schemes have been in use:
--
--   c_mod_<slug>_1            BU-CB (hardcoded per challenge file)
--   c_chmod_c_mod_<slug>_1    the SMODS build, which registered those ids
--                             through SMODS.Challenge; SMODS.modify_key
--                             prefixes keys with the mod prefix
--   cm_mod_<Display_Name>_1   BU-CB-DEV, generated from the name (current)
--
-- Rather than assume which scheme a save holds, every known old key is checked
-- and copied onto the current id. Unrecognised keys are left untouched.
--
-- Keyed by the CURRENT display name; several challenges were renamed, so the
-- old BU-CB name is noted where it differs. The pairings were confirmed by
-- comparing challenge rules, not names alone.
local LEGACY_SLUGS = {
  ["Anapodaphobia"] = "facedown",
  ["Budgeting"] = "budgeting",
  ["Bullseye"] = "bullseye",
  ["Certified Gambler"] = "certified_gambler",
  ["Cryptojacked"] = "cryptojacked",
  -- Post-dates oceanramen/master, so its old id came from the SMODS build only.
  ["Empty Canvas"] = "empty_canvas",
  ["Fleeting Memory"] = "fleeting",
  ["Hands Tied"] = "hands_tied",
  ["Highroll"] = "highroll",
  ["Jimboful"] = "jimboful",
  ["Jokerless?"] = "jokerlessq",
  ["Load Bearing"] = "load_bearing",
  ["Series Funding"] = "series_funding",
  ["Student Loan Debt"] = "student_loan_debt",
  ["Swapped Pockets"] = "swapped_pockets",
  ["Target Practice"] = "target_practice",
  ["Tarot Tycoon"] = "tarot_tycoon",
  ["The Golden Touch"] = "the_golden_touch",
  -- Renamed between BU-CB and BU-CB-DEV.
  ["Oops! All Sixes!"] = "sixes", -- was "Oops, All Sixes!"
  ["Pay-As-You-Go"] = "payasyougo", -- was "Pay As You Go"
  ["Riff-Raffle"] = "riffraff",
  ["Tarot Torture"] = "unfortunate", -- was "Unfortunate"
  ["Midterm"] = "golderstake", -- was "Golder Stake"
  ["Finals"] = "evengolderstake", -- was "Even Golder Stake"
}

-- Butterfingers' BU-CB id had no _1 suffix, so it needs its exact old keys
-- rather than the slug pattern the others follow.
local LEGACY_EXACT = {
  ["Butterfingers"] = { "c_mod_butterfingers", "c_chmod_c_mod_butterfingers" },
}

local function old_keys(name)
  if LEGACY_EXACT[name] then return LEGACY_EXACT[name] end
  local slug = LEGACY_SLUGS[name]
  if not slug then return nil end
  local base = "c_mod_" .. slug .. "_1"
  return {
    base, -- BU-CB, via Lovely
    "c_chmod_" .. base, -- the same id once SMODS prefixed it
    -- The SMODS build also registered the generated ids for a while.
    "c_chmod_cm_mod_" .. name:gsub("%s+", "_") .. "_1",
  }
end

local function migrate()
  local profile = G.PROFILES and G.PROFILES[G.SETTINGS and G.SETTINGS.profile]
  local progress = profile and profile.challenge_progress
  if not progress or not progress.completed then return end

  local migrated, names = 0, {}
  for _, data in ipairs(G.CHALLENGES or {}) do
    local id, name = data.id, data.name
    -- Only fill gaps: a completion already under the current id wins, so this
    -- is idempotent and safe to run on every profile load.
    if id and name and not progress.completed[id] then
      for _, key in ipairs(old_keys(name) or {}) do
        if progress.completed[key] then
          progress.completed[id] = true
          migrated = migrated + 1
          names[#names + 1] = name
          break
        end
      end
    end
  end

  if migrated > 0 then
    -- save_settings queues the profile write (it pushes save_profile).
    if G.SAVE_MANAGER then G:save_settings() end
    sendInfoMessage(
      ("Migrated %d challenge completions to current ids: %s"):format(migrated, table.concat(names, ", ")),
      "ChallengeMod"
    )
  end
end

migrate()

-- Profiles can be switched after load, and each carries its own progress, so
-- re-run on profile load rather than only at startup.
local load_profile_ref = Game.load_profile
function Game:load_profile(...)
  local ret = load_profile_ref(self, ...)
  migrate()
  return ret
end
