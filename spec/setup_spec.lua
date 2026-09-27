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
    Setup.active = true
    _G.G.GAME.viewed_back = { name = "Challenge Deck" }
    assert.is_false(Setup.deck_overridden())
  end)

  it("reports an override once another deck is picked", function()
    Setup.active = true
    _G.G.GAME.viewed_back = { name = "Red Deck" }
    assert.is_true(Setup.deck_overridden())
  end)

  it("reports no override when nothing has been viewed", function()
    Setup.active = true
    _G.G.GAME.viewed_back = nil
    assert.is_false(Setup.deck_overridden())
  end)

  -- The bug this missed. G.GAME.viewed_back survives from the ordinary New Run
  -- screen, so a challenge started straight from PLAY saw a "chosen" deck it
  -- had never been given -- Big Wee launched on whichever deck single player
  -- happened to be sitting on. Only the Customize flow may override.
  it("reports no override for a challenge started without customizing", function()
    Setup.active = false
    _G.G.GAME.viewed_back = { name = "Red Deck" }
    assert.is_false(Setup.deck_overridden(),
      "a stale viewed deck must not override the challenge's own")
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

-- PLAY must keep starting a run immediately. Customising is a second button,
-- so the common case costs no extra click.
describe("the customize button", function()
  local patch, module

  setup(function()
    local f = assert(io.open("lovely/cm_customize_button.toml"))
    patch = f:read("*a")
    f:close()
    local m = assert(io.open("smods/rules_challenge_setup.lua"))
    module = m:read("*a")
    m:close()
  end)

  it("leaves the play button alone", function()
    assert.is_truthy(patch:match('button = "start_challenge_run"'),
      "the play button must survive the patch")
    assert.is_nil(module:match("G%.FUNCS%.start_challenge_run%s*="),
      "play must not be overridden -- it starts the run immediately")
  end)

  it("adds its own entry point", function()
    assert.is_truthy(patch:match('button = "cm_customize_challenge_run"'))
    assert.is_truthy(module:match("G%.FUNCS%.cm_customize_challenge_run"))
  end)

  -- Sibling R nodes stack vertically; C nodes sit side by side. Using R put
  -- Customize above Play, which is not what "beside" means.
  it("puts the two buttons side by side, not stacked", function()
    local payload = patch:match('position = "at"(.*)')
    for node in payload:gmatch("{n=(G%.UIT%.[RC]),[^\n]*button =") do
      assert.equal("G.UIT.C", node,
        "a button sibling must be a column or it stacks vertically")
    end
  end)

  -- Both buttons share one row, so they have to fit in it.
  it("makes room for both", function()
    -- Only the payload: the anchor above it still quotes the original minw.
    local payload = patch:match('position = "at"(.*)')
    assert.is_truthy(payload, "payload not found")
    local widths = {}
    for w in payload:gmatch("minw = ([%d%.]+)") do widths[#widths + 1] = tonumber(w) end
    assert.equal(2, #widths, "expected exactly two buttons")
    assert.is_true(widths[1] + widths[2] <= 9,
      "the two buttons must fit the width the single play button had")
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

-- A zero-card discard is a path vanilla never takes, so the parts of the
-- discard function that keep the UI alive never run for it.
describe("the zero-card pass", function()
  local module

  setup(function()
    local f = assert(io.open("smods/rules_climb_wiring.lua"))
    module = f:read("*a")
    f:close()
  end)

  -- Discard is a one_press button: engine/ui.lua sets disable_button on click
  -- and nothing re-arms it. A real discard re-arms it by side effect, setting
  -- G.STATE = DRAW_TO_HAND which rebuilds the UI. A pass changes no state, so
  -- the flag survived and discard was dead for the rest of the round.
  it("re-arms the one-press discard button", function()
    assert.is_truthy(module:match("disable_button = nil"),
      "a pass must re-arm the button the click disabled")
  end)

  -- The function sets interrupt.focus before the guard it then skips, and
  -- every path that lifts it lives inside the body.
  it("lifts the focus interrupt the discard set on the way in", function()
    assert.is_truthy(module:match("interrupt%.focus = false"))
  end)

  -- The charge is the other thing the skipped body would have done.
  it("still charges the discard", function()
    assert.is_truthy(module:match("ease_discard%(%-1%)"))
    assert.is_truthy(module:match("discards_used"))
  end)
end)
