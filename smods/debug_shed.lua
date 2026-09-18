-- Temporary on-screen diagnostic for the shed bonus flash.
--
-- sendInfoMessage writes to the Lovely log, which is awkward to read on
-- Android, so the trace is drawn top-left instead. The same overlay approach
-- diagnosed the handsize and facedown bugs earlier.
--
-- Remove this file and its load line once the flash is confirmed.
ChallengeMod.ShedDebug = ChallengeMod.ShedDebug or { lines = {} }
local D = ChallengeMod.ShedDebug

--- Record one step of the flash attempt. Keeps the last few, newest last.
function D.log(msg)
  D.lines[#D.lines + 1] = tostring(msg)
  while #D.lines > 8 do table.remove(D.lines, 1) end
end

local draw_ref = Game.draw
function Game:draw()
  if draw_ref then draw_ref(self) end

  if #D.lines == 0 then return end
  local ok = pcall(function()
    love.graphics.push()
    local y = 8
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.print("SHED TRACE", 9, y + 1)
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print("SHED TRACE", 8, y)
    y = y + 13
    for _, line in ipairs(D.lines) do
      love.graphics.setColor(0, 0, 0, 0.75)
      love.graphics.print(line, 9, y + 1)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print(line, 8, y)
      y = y + 13
    end
    love.graphics.pop()
  end)
  if not ok then pcall(function() love.graphics.pop() end) end
end
