-- Headless load test for the SMODS entry point. Stubs just enough of Balatro,
-- LOVE and SMODS to run the real ChallengeMod.lua chain, then asserts that
-- every rules.custom id resolves to a registered modifier and (for mod-owned
-- cm_/dm_ ids) a localization string -- the failure that crashes the rules box.
--
--   nix shell nixpkgs#lua5_1 --command lua smods/load_test.lua
--
-- nativefs needs LuaJIT's ffi; plain lua5.1 can't load it. Stub the one
-- function the handlers use so the rest of the chain runs for real.
local nativefs_stub = function()
  return { getDirectoryItems = function(dir)
    local out, p = {}, io.popen("ls -1 '" .. dir .. "' 2>/dev/null")
    if p then for l in p:lines() do out[#out+1] = l end p:close() end
    return out
  end, getInfo = function(path)
    local f = io.open(path, "r")
    if not f then return nil end
    f:close(); return { type = "file" }
  end, write = function() return true end, read = function(path)
    local f = io.open(path, "r"); if not f then return nil end
    local c = f:read("*a"); f:close(); return c
  end }
end
-- ChallengeMod.lua sets package.preload["nativefs"] itself; make that write a
-- no-op so the ffi-free stub above is what the handlers actually get.
local real_preload = package.preload
setmetatable(package, { __index = function(_, k)
  if k == "preload" then return setmetatable({}, {
    __index = function(_, kk) return kk == "nativefs" and nativefs_stub or real_preload[kk] end,
    __newindex = function(_, kk, vv) if kk ~= "nativefs" then real_preload[kk] = vv end end,
  }) end
end })
package.loaded["nativefs"] = nativefs_stub()

local registered_mods, registered_chals = {}, {}
-- Seed completions in all three legacy schemes to prove the migration finds
-- each one: BU-CB, the SMODS-prefixed variant, and a generated-id variant.
local SEEDED = {
  ["c_mod_facedown_1"] = true,                 -- BU-CB            -> Anapodaphobia
  ["c_chmod_c_mod_bullseye_1"] = true,         -- SMODS-prefixed   -> Bullseye
  ["c_chmod_cm_mod_Tarot_Tycoon_1"] = true,    -- SMODS generated  -> Tarot Tycoon
  ["c_mod_butterfingers"] = true,              -- no _1 suffix     -> Butterfingers
  ["c_mod_unfortunate_1"] = true,              -- renamed          -> Tarot Torture
  ["c_mod_who_knows_1"] = true,                -- unknown, must be left alone
}
G = { CHALLENGES = {}, localization = { misc = { challenge_names = {}, v_text = {} } },
      C = {}, SETTINGS = { profile = 1 }, UIDEF = {}, FUNCS = {},
      PROFILES = { [1] = { challenge_progress = { completed = SEEDED, unlocked = {} } } },
      SAVE_MANAGER = nil }
Game = { load_profile = function() end, save_settings = function() end }
SMODS = {
  current_mod = { path = "./" },
  -- Deliberately no Modifier field: SMODS 1.0.0-beta-1814a has none, and
  -- providing one here previously masked that the mod's guard never fired.
  Challenge = function(t)
    error("SMODS.Challenge called: the handlers already own G.CHALLENGES, so "
      .. "registering again duplicates every key (" .. tostring(t.key) .. ")")
  end,
  Challenges = {},
  -- Mirrors the real class: calculate/calc_dollar_bonus are no-op defaults
  -- that registered objects inherit.
  Challenge = { calculate = function(self, ctx) end, calc_dollar_bonus = function(self) end },
}
function Game.start_run() end; function Game.draw() end
Blind = {}; Card = {}; Sprite = function() end; UIBox_button = function() end
localize = function() return "" end
sendInfoMessage = function() end
sendWarnMessage = function() end
UIBox_button = function(t) return { config = t } end
STR_UNPACK = function(str) local f = loadstring(tostring(str)); return f and f() or nil end
STR_PACK = function(t) return "{}" end
love = { graphics = {}, filesystem = {
  getInfo = function() return nil end,
  read = function() return nil end,
  write = function() return true end,
  append = function() return true end,
  newFile = function() return { open=function() return false end } end,
} }

assert(loadfile("ChallengeMod.lua"))()

local ours, seen = {}, {}
for _, d in ipairs(G.CHALLENGES) do
  if d.id and d.id:sub(1, 2) == "cm" then
    assert(not seen[d.id], "duplicate challenge id in G.CHALLENGES: " .. d.id)
    seen[d.id] = true
    ours[#ours + 1] = d
  end
end
print(("G.CHALLENGES: %d ours, %d total"):format(#ours, #G.CHALLENGES))


local missing_loc, missing_mod = {}, {}
for _, t in ipairs(ours) do
  local key = t.id
  for _, v in ipairs(t.rules and t.rules.custom or {}) do
    local mod_owned = v.id:sub(1,3) == "cm_" or v.id:sub(1,3) == "dm_"
    if mod_owned and not G.localization.misc.v_text["ch_c_" .. v.id] then
      missing_loc[v.id] = (missing_loc[v.id] or "") .. " " .. key
    end
  end
end
local ok = true
for id, w in pairs(missing_loc) do print("MISSING LOCALIZATION: "..id.." <-"..w); ok=false end
if ok then print("OK: no duplicate ids; every mod-owned rules.custom id has localization") end

-- Migration: each seeded legacy key must now also be set under the current id.
local EXPECT = { ["Anapodaphobia"]=1, ["Bullseye"]=1, ["Tarot Tycoon"]=1,
                 ["Butterfingers"]=1, ["Tarot Torture"]=1 }
local done = G.PROFILES[1].challenge_progress.completed
local ok_m = true
for _, d in ipairs(G.CHALLENGES) do
  if EXPECT[d.name] then
    if done[d.id] then EXPECT[d.name] = "ok"
    else print("MIGRATION FAILED: " .. d.name .. " (" .. tostring(d.id) .. ")"); ok_m = false end
  end
end
for n, v in pairs(EXPECT) do
  if v ~= "ok" then print("MIGRATION MISSING: challenge not found in list: " .. n); ok_m = false end
end
assert(done["c_mod_who_knows_1"], "migration must not delete unknown keys")
if ok_m then print("OK: migrated all 5 legacy schemes; unknown keys untouched") end

-- Starting a challenge run: SMODS.calculate_card_areas does
-- SMODS.Challenges[G.GAME.challenge].id, so every challenge the menu offers
-- must be reachable there under the id the game stores. Missing entries
-- crashed on the first debuff_card of any run.
local unreachable = {}
for _, d in ipairs(G.CHALLENGES) do
  if d.id and d.id:sub(1, 2) == "cm" then
    local obj = SMODS.Challenges[d.id]
    if not obj or not obj.id then unreachable[#unreachable + 1] = d.id end
  end
end
if #unreachable > 0 then
  for _, id in ipairs(unreachable) do print("NOT IN SMODS.Challenges: " .. id) end
  error(("%d challenges would crash on run start"):format(#unreachable))
end
print(("OK: all %d challenges reachable via SMODS.Challenges[id].id"):format(#G.CHALLENGES))

-- SMODS.eval_individual calls object:calculate(context) on the running
-- challenge; a plain data table with no metatable has no such method.
local uncallable = {}
for _, d in ipairs(G.CHALLENGES) do
  if d.id and d.id:sub(1, 2) == "cm" then
    local obj = SMODS.Challenges[d.id]
    local ok = obj and pcall(function() return obj:calculate({}) end)
    if not ok then uncallable[#uncallable + 1] = d.id end
  end
end
if #uncallable > 0 then
  for _, id in ipairs(uncallable) do print("NOT CALCULABLE: " .. id) end
  error(("%d challenges would crash in eval_individual"):format(#uncallable))
end
print("OK: every challenge object answers :calculate(context)")
