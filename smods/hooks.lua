-- SMODS equivalents of the game-code patches in lovely/challenge_init.toml.
-- The per-mechanic patches under lovely/ still apply as Lovely patches; only
-- the init-level ones are reimplemented here as function wraps.

-- Rule dispatch is NOT here: it lives in lovely/cm_evaluate_rules.toml, which
-- injects into game.lua's rule loop. Wrapping Game:start_run cannot work --
-- the loop writes G.GAME.starting_params and start_run consumes those values
-- further down the same function, so a wrapper runs far too late.

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
