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
G = { CHALLENGES = {}, localization = { misc = { challenge_names = {}, v_text = {} } },
      C = {}, PROFILES = {}, SETTINGS = { profile = 1 }, UIDEF = {}, FUNCS = {} }
SMODS = {
  current_mod = { path = "./" },
  -- Deliberately no Modifier field: SMODS 1.0.0-beta-1814a has none, and
  -- providing one here previously masked that the mod's guard never fired.
  Challenge = function(t)
    error("SMODS.Challenge called: the handlers already own G.CHALLENGES, so "
      .. "registering again duplicates every key (" .. tostring(t.key) .. ")")
  end,
}
Game = {}; function Game.start_run() end; function Game.draw() end
Blind = {}; Card = {}; Sprite = function() end; UIBox_button = function() end
localize = function() return "" end
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
