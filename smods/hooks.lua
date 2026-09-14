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

-- challenge_init.toml patched game.lua before love.graphics.setCanvas(G.AA_CANVAS)
-- to call ChallengeMod.draw(), which prints the mod version in the top-left
-- corner whenever RELEASE is false. That overlay is not wanted here, so the
-- hook is left out. Flipping RELEASE instead would also drop the per-challenge
-- VERSION line from the rules box, which is worth keeping.

-- ChallengeMod.update(dt) is defined in core.lua but never called upstream
-- either, so it stays unwired here: enabling it would start the daily score
-- writes that the Lovely build has never actually run.

-- cm_mult_dollar_cap, for the restored Series Funding. BU-CB implemented this
-- by wrapping mod_mult; BU-CB-DEV dropped both the challenge and the modifier,
-- so the hook comes back with it. (BU-CB's companion chips_dollar_cap was only
-- ever rule text -- never implemented anywhere -- so it is not revived.)
local mod_mult_ref = mod_mult
function mod_mult(_mult)
  _mult = mod_mult_ref(_mult)
  if G.GAME.modifiers.cm_mult_dollar_cap then
    _mult = math.min(_mult, math.max(G.GAME.dollars, 0))
  end
  return _mult
end
