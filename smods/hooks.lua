-- SMODS equivalents of the game-code patches in lovely/challenge_init.toml.
-- The per-mechanic patches under lovely/ still apply as Lovely patches; only
-- the init-level ones are reimplemented here as function wraps.

-- challenge_init.toml patches game.lua's rule loop, before `if v.id == 'no_reward'`.
-- Game:start_run walks rules.custom, so the dispatch happens here instead.
local start_run_ref = Game.start_run
function Game:start_run(args)
  start_run_ref(self, args)
  local custom = self.GAME and self.GAME.challenge and self.GAME.challenge.rules
    and self.GAME.challenge.rules.custom
  if not custom then return end
  for _, v in ipairs(custom) do
    ChallengeMod.evaluate_rules(self, v)
    ChallengeMod.evaluate_daily_modifiers(self, v)
  end
end

-- challenge_init.toml patches game.lua before love.graphics.setCanvas(G.AA_CANVAS).
local game_draw_ref = Game.draw
function Game:draw()
  game_draw_ref(self)
  ChallengeMod.draw()
end

-- ChallengeMod.update(dt) is defined in core.lua but never called upstream
-- either, so it stays unwired here: enabling it would start the daily score
-- writes that the Lovely build has never actually run.
