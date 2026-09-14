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
