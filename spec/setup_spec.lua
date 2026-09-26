-- Deck and stake choice for a challenge. The UI half cannot be driven from a
-- spec, so what is asserted here is the part that decides whether a run is
-- altered at all, plus the patch property the whole feature rests on.
local function load_module()
  _G.ChallengeMod = {}
  _G.G = {
    P_CENTERS = { b_challenge = { name = "Challenge Deck" }, b_red = { name = "Red Deck" } },
    P_CENTER_POOLS = { Back = { { name = "Red Deck" } } },
    FUNCS = {},
    UIDEF = { run_setup_option = function() return {} end },
    GAME = {},
    SETTINGS = { profile = 1 },
    PROFILES = { { MEMORY = { deck = "Red Deck" } } },
  }
  assert(loadfile("smods/rules_challenge_setup.lua"))()
  return _G.ChallengeMod.Setup
end

describe("challenge deck override", function()
  local Setup

  before_each(function()
    Setup = load_module()
  end)

  -- The default path has to stay byte-identical: leave the picker on the
  -- challenge's own deck and nothing about the run changes.
  it("reports no override while the challenge deck is selected", function()
    _G.G.GAME.viewed_back = { name = "Challenge Deck" }
    assert.is_false(Setup.deck_overridden())
  end)

  it("reports an override once another deck is picked", function()
    _G.G.GAME.viewed_back = { name = "Red Deck" }
    assert.is_true(Setup.deck_overridden())
  end)

  it("reports no override when nothing has been viewed", function()
    _G.G.GAME.viewed_back = nil
    assert.is_false(Setup.deck_overridden())
  end)
end)

describe("leaving challenge setup", function()
  local Setup

  before_each(function()
    Setup = load_module()
  end)

  -- G.challenge_tab is what the play button reads to decide a run is a
  -- challenge. Leaking it would silently turn the player's next ordinary run
  -- into a challenge run, which is the worst failure this feature could have.
  it("clears the stashed challenge on cancel", function()
    _G.G.challenge_tab = { id = "cm_big_wee" }
    Setup.cancel()
    assert.is_nil(_G.G.challenge_tab)
    assert.is_false(Setup.active)
  end)

  it("clears the stashed challenge once a run starts", function()
    _G.G.challenge_tab = { id = "cm_big_wee" }
    Setup.finish()
    assert.is_nil(_G.G.challenge_tab)
  end)

  -- b_challenge is omit = true, so it must not be left in the pool: it would
  -- then show up as a pickable deck on an ordinary New Run.
  it("takes the challenge deck back out of the pool", function()
    Setup.cancel()
    for _, v in ipairs(_G.G.P_CENTER_POOLS.Back) do
      assert.not_equal("Challenge Deck", v.name)
    end
  end)
end)

describe("the deck precedence patch", function()
  local patch

  setup(function()
    local f = assert(io.open("lovely/cm_challenge_deck_choice.toml"))
    patch = f:read("*a")
    f:close()
  end)

  -- The override must sit AHEAD of the challenge's own deck in the or-chain,
  -- which is the single reason challenges are locked to their deck today.
  it("puts the override before the challenge's declared deck", function()
    -- The payload line, not the comment above it that quotes the original.
    local chain = patch:match("local selected_back = [^\n]*_cm_back[^\n]*")
    assert.is_truthy(chain, "the payload must still build the or-chain")
    local override = chain:find("_cm_back", 1, true)
    local declared = chain:find("args.challenge and args.challenge.deck", 1, true)
    assert.is_truthy(override and declared)
    assert.is_true(override < declared,
      "a chosen deck must take precedence over the challenge's own")
  end)

  it("only overrides for a challenge run", function()
    assert.is_truthy(patch:match("args%.challenge and ChallengeMod%.Setup%.deck_overridden"),
      "an ordinary run must be untouched")
  end)
end)
