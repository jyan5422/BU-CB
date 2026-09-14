-- Temporary on-screen diagnostic for the two mechanics that still do not work.
--
-- Deliberately reports EXECUTION, not just state. Reading G.GAME.modifiers only
-- proves a value was set; it cannot tell whether the patched game code ever
-- ran. Each Lovely patch bumps a counter in ChallengeMod.DEBUG, so a modifier
-- that is set while its counter stays 0 means the patch is not executing on
-- this device -- which reading state alone could never distinguish.
--
-- Delete this file and its load line in ChallengeMod.lua once the two
-- mechanics are confirmed working.
ChallengeMod.DEBUG = ChallengeMod.DEBUG or {
  set_blind_calls = 0,
  handsize_fired = 0,
  last_blind_type = "-",
  card_init_calls = 0,
  facedown_fired = 0,
}

local D = ChallengeMod.DEBUG

local function fmt(label, value)
  return ("%s=%s"):format(label, tostring(value))
end

local function lines()
  local m = (G.GAME and G.GAME.modifiers) or {}
  local hand = G.hand and G.hand.config and G.hand.config.card_limit
  return {
    "BU-CB DEBUG",
    fmt("challenge", G.GAME and G.GAME.challenge or "none"),
    "-- handsize --",
    fmt("mod", m.cm_decreasing_handsize),
    fmt("hand_limit", hand),
    fmt("set_blind_calls", D.set_blind_calls),
    fmt("shrink_fired", D.handsize_fired),
    fmt("last_blind_type", D.last_blind_type),
    "-- facedown --",
    fmt("mod", m.cm_all_facedown),
    fmt("card_init_calls", D.card_init_calls),
    fmt("facedown_fired", D.facedown_fired),
  }
end

-- Drawn in the top-left, same place the version banner used to sit.
local draw_ref = Game.draw
function Game:draw()
  draw_ref(self)
  local ok = pcall(function()
    love.graphics.push()
    local y = 8
    for _, line in ipairs(lines()) do
      -- Shadow first so the text stays readable over any background.
      love.graphics.setColor(0, 0, 0, 0.75)
      love.graphics.print(line, 9, y + 1)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print(line, 8, y)
      y = y + 13
    end
    love.graphics.pop()
  end)
  if not ok then love.graphics.pop() end
end
