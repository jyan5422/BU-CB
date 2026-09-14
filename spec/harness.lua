-- Loads the mod the way SMODS does, against stubs, and hands back what it
-- produced so specs can assert on it.
--
-- Balatro is LuaJIT; these specs run on plain lua5.1, so anything needing the
-- FFI is stubbed and everything else is the mod's real code.
local M = {}

-- nativefs needs LuaJIT's ffi. Stub the handful of functions the handlers use.
local function nativefs_stub()
  return {
    getDirectoryItems = function(dir)
      local out, p = {}, io.popen("ls -1 '" .. dir .. "' 2>/dev/null")
      if p then
        for l in p:lines() do out[#out + 1] = l end
        p:close()
      end
      return out
    end,
    getInfo = function(path)
      local f = io.open(path, "r")
      if not f then return nil end
      f:close()
      return { type = "file" }
    end,
    read = function(path)
      local f = io.open(path, "r")
      if not f then return nil end
      local c = f:read("*a")
      f:close()
      return c
    end,
    write = function() return true end,
  }
end

-- Completions in every historical id scheme, so the migration can be checked
-- against all of them at once. The last entry must survive untouched.
M.SEEDED_COMPLETIONS = {
  ["c_mod_facedown_1"] = true, -- BU-CB              -> Anapodaphobia
  ["c_chmod_c_mod_bullseye_1"] = true, -- SMODS-prefixed     -> Bullseye
  ["c_chmod_cm_mod_Tarot_Tycoon_1"] = true, -- SMODS + generated  -> Tarot Tycoon
  ["c_mod_butterfingers"] = true, -- no _1 suffix       -> Butterfingers
  ["c_mod_unfortunate_1"] = true, -- renamed            -> Tarot Torture
  ["c_mod_who_knows_1"] = true, -- unknown: must be left alone
}

-- Loads ChallengeMod.lua with globals stubbed. Returns a table of everything
-- worth asserting on: the challenge list, the localization tables, the
-- profile, and whether SMODS.Challenge was called (it must not be).
M.last_areas = {}

function M.load()
  M.last_areas = {}
  local seeded = {}
  for k, v in pairs(M.SEEDED_COMPLETIONS) do seeded[k] = v end

  local state = { smods_challenge_calls = {} }

  -- ChallengeMod.lua installs its own package.preload["nativefs"]; keep the
  -- ffi-free stub winning while letting other preloads through.
  local real_preload = package.preload
  setmetatable(package, {
    __index = function(_, k)
      if k == "preload" then
        return setmetatable({}, {
          __index = function(_, kk)
            return kk == "nativefs" and nativefs_stub or real_preload[kk]
          end,
          __newindex = function(_, kk, vv)
            if kk ~= "nativefs" then real_preload[kk] = vv end
          end,
        })
      end
    end,
  })
  package.loaded["nativefs"] = nativefs_stub()

  G = {
    CHALLENGES = {},
    localization = { misc = { challenge_names = {}, v_text = {} } },
    C = {},
    SETTINGS = { profile = 1 },
    UIDEF = {},
    FUNCS = {},
    PROFILES = { [1] = { challenge_progress = { completed = seeded, unlocked = {} } } },
    SAVE_MANAGER = nil,
  }

  SMODS = {
    -- Shaped like the real mod object, dependency tree and all: putting this
    -- on a challenge table is what broke save_run, so the serialization spec
    -- needs something with the same reach to be a real test.
    current_mod = {
      path = "./",
      dependencies = {
        { id = "Steamodded", fulfilled = true, { ver = { major = 1, minor = 0 }, op = function() end } },
      },
    },
    Challenges = {},
    -- joker_timing.lua wraps this; the stub records what it was asked to
    -- evaluate so a spec can assert jokers were skipped.
    calculate_card_areas = function(area, context, return_table, args)
      M.last_areas[#M.last_areas + 1] = area
      return {}
    end,
    -- Mirrors the real class: calculate and calc_dollar_bonus are no-op
    -- defaults that registered objects inherit.
    Challenge = {
      calculate = function(self, context) end,
      calc_dollar_bonus = function(self) end,
    },
  }
  -- Calling this would re-insert into G.CHALLENGES and rewrite ids; record any
  -- call so a spec can fail on it rather than it passing silently.
  setmetatable(SMODS, {
    __call = function() end,
  })
  SMODS.Challenge.__call = function(_, t)
    state.smods_challenge_calls[#state.smods_challenge_calls + 1] = t and t.key
  end

  Game = { load_profile = function() end, save_settings = function() end }
  function Game.start_run() end
  function Game.draw() end
  Blind, Card = {}, {}
  Sprite = function() end
  UIBox_button = function(t) return { config = t } end
  localize = function() return "" end
  sendInfoMessage = function() end
  sendWarnMessage = function() end
  STR_UNPACK = function(str)
    local f = loadstring(tostring(str))
    return f and f() or nil
  end
  STR_PACK = function() return "{}" end
  love = {
    graphics = {},
    filesystem = {
      getInfo = function() return nil end,
      read = function() return nil end,
      write = function() return true end,
      append = function() return true end,
    },
  }

  -- daily_challenge.lua prints its modifier picks; quiet it so spec output
  -- shows only results. Upstream's file stays untouched.
  local real_print = print
  print = function() end
  local ok, err = pcall(function()
    assert(loadfile("ChallengeMod.lua"))()
  end)
  print = real_print
  if not ok then error(err, 0) end

  state.challenges = G.CHALLENGES
  state.v_text = G.localization.misc.v_text
  state.challenge_names = G.localization.misc.challenge_names
  state.completed = G.PROFILES[1].challenge_progress.completed
  state.smods_challenges = SMODS.Challenges

  -- Only the mod's own entries; vanilla ids are the game's business.
  state.ours = {}
  for _, d in ipairs(state.challenges) do
    if d.id and d.id:sub(1, 2) == "cm" then
      state.ours[#state.ours + 1] = d
    end
  end

  return state
end

return M
