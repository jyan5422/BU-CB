-- cm_all_facedown: reveal everything once the run is over.
--
-- The hiding is decided in several Lovely patches across card.lua and
-- cardarea.lua. Rather than repeat the condition in each, they all call this
-- one predicate, so "should cards be hidden right now" has a single home.
--
-- Hiding is dropped at the game-over screen so the jokers that were face down
-- all run can finally be read. Every route there sets G.STATE to GAME_OVER --
-- state_events.lua on a lost blind, G.FUNCS.DT_lose_game, and
-- ChallengeMod.fold for the challenges that end a run themselves -- so
-- checking the state covers all of them without patching each one.
function ChallengeMod.hide_cards()
  if not (G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_all_facedown == true) then
    return false
  end
  if G.STATE and G.STATES and G.STATE == G.STATES.GAME_OVER then
    return false
  end
  return true
end

-- The predicate alone is not enough. Card:init sets facing once, when a card
-- is created; by game over every card already exists, so nothing re-asks and
-- they stay face down. Flipping has to be done explicitly when the state
-- changes.
local DEBUG = false -- set true to print reveal diagnostics to the Lovely log

local function log(msg)
  if DEBUG and sendInfoMessage then sendInfoMessage("[reveal] " .. msg, "ChallengeMod") end
end

local function reveal_area(area, name, counts)
  if not area or not area.cards then return end
  for _, card in ipairs(area.cards) do
    if card.facing ~= "front" or card.sprite_facing ~= "front" then
      card.facing = "front"
      card.sprite_facing = "front"
      card.flipping = nil
      counts[name] = (counts[name] or 0) + 1
    end
  end
end

function ChallengeMod.reveal_all()
  local counts = {}
  -- G.jokers and G.consumeables are the point of the feature; the rest are
  -- revealed for consistency on the same screen.
  reveal_area(G.jokers, "jokers", counts)
  reveal_area(G.consumeables, "consumeables", counts)
  reveal_area(G.hand, "hand", counts)
  reveal_area(G.deck, "deck", counts)
  reveal_area(G.discard, "discard", counts)
  reveal_area(G.play, "play", counts)

  local parts = {}
  for k, v in pairs(counts) do parts[#parts + 1] = k .. "=" .. v end
  log(#parts > 0 and ("flipped " .. table.concat(parts, " ")) or "nothing to flip")
  return counts
end

-- Watch for the transition rather than patching each route into game over.
-- Game:update runs every frame, so this costs one comparison until it fires.
-- Guarded because Game.update may not be defined yet at load time, in which
-- case calling a nil upvalue would take the whole update loop down.
local update_ref = Game.update
function Game:update(dt)
  if update_ref then update_ref(self, dt) end

  local over = G.STATE and G.STATES and G.STATE == G.STATES.GAME_OVER
  local facedown = G.GAME and G.GAME.modifiers and G.GAME.modifiers.cm_all_facedown == true

  -- Once is enough: the Card:update patch that would re-hide them is itself
  -- gated by hide_cards(), which is already false by this point.
  if over and facedown then
    if not ChallengeMod._revealed then
      ChallengeMod._revealed = true
      log("game over reached; revealing")
      ChallengeMod.reveal_all()
    end
  elseif not over then
    ChallengeMod._revealed = nil
  end
end
