-- Choose a deck and stake for a challenge.
--
-- Vanilla starts a challenge the instant you click it, so the stake is always
-- White and the deck is always whatever the challenge declared. That remains
-- what PLAY does; this adds a Customize button beside it.
--
-- Everything needed already exists: the New
-- Run tab of the same overlay has a deck picker and a stake picker, and its
-- play button (G.FUNCS.start_setup_run) already reads G.challenge_tab and
-- passes it to start_run alongside the chosen stake and seed.
--
-- So this does not build a picker. It stashes the challenge and sends the
-- player to the New Run tab, where the game's own pickers do the work.
--
-- The challenge's own deck stays the default: "Challenge Deck" is offered as
-- the pre-selected option, and picking anything else overrides it. What a
-- challenge DECLARES is untouched either way -- an explicit card list still
-- wins over a deck's effect, because start_run short-circuits deck generation
-- when the challenge supplies one.
ChallengeMod.Setup = ChallengeMod.Setup or {}
local Setup = ChallengeMod.Setup

local CHALLENGE_BACK = "b_challenge"

--- True while the player is picking a deck and stake FOR a challenge.
--- Read by the deck-precedence patch (lovely/cm_challenge_deck_choice.toml).
Setup.active = false

-- b_challenge is flagged `omit = true`, so it is not in the Back pool and
-- cannot normally be shown or selected. It has to be present for the picker to
-- offer "the deck this challenge ships with" as a choice at all.
local function add_challenge_back()
  local pool = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Back
  local back = G.P_CENTERS and G.P_CENTERS[CHALLENGE_BACK]
  if not (pool and back) then return end
  for _, v in ipairs(pool) do
    if v == back then return end
  end
  table.insert(pool, 1, back)
end

local function remove_challenge_back()
  local pool = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Back
  local back = G.P_CENTERS and G.P_CENTERS[CHALLENGE_BACK]
  if not (pool and back) then return end
  for k, v in ipairs(pool) do
    if v == back then
      table.remove(pool, k)
      return
    end
  end
end

--- Leave challenge setup without starting a run.
---
--- G.challenge_tab MUST be cleared here. It is what start_setup_run reads to
--- decide a run is a challenge, so a leaked value would silently turn the
--- player's next ordinary run into a challenge run.
function Setup.cancel()
  Setup.active = false
  G.challenge_tab = nil
  remove_challenge_back()
end

--- Called once a run has actually started, to leave global state as found.
--- The challenge itself is already on G.GAME by then.
function Setup.finish()
  Setup.active = false
  G.challenge_tab = nil
  remove_challenge_back()
end

-- PLAY is left exactly as it was: click a challenge, start it, no extra step.
-- Customising is a separate button beside it (lovely/cm_customize_button.toml)
-- so the common case costs nothing.
G.FUNCS.cm_customize_challenge_run = function(e)
  local challenge = G.CHALLENGES and e and e.config and G.CHALLENGES[e.config.id]
  if not challenge then return end

  Setup.active = true
  G.challenge_tab = challenge
  add_challenge_back()

  -- One tab, not the full three. The player has already chosen a challenge;
  -- offering Continue and the challenge list again beside it invites starting
  -- something else with a challenge still stashed in G.challenge_tab.
  G.FUNCS.overlay_menu({
    definition = create_UIBox_generic_options({
      back_func = "cm_challenge_setup_back",
      contents = {
        {
          n = G.UIT.R,
          config = { align = "cm", padding = 0, draw_layer = 1 },
          nodes = {
            create_tabs({
              tabs = {
                {
                  label = localize("b_new_run"),
                  chosen = true,
                  tab_definition_function = G.UIDEF.run_setup_option,
                  tab_definition_function_args = "New Run",
                },
              },
              snap_to_nav = true,
            }),
          },
        },
      },
    }),
  })
end

--- Back out to the challenge list, rather than to the main menu.
G.FUNCS.cm_challenge_setup_back = function(e)
  Setup.cancel()
  G.FUNCS.setup_run({ config = { id = "challenge_list" } })
end

-- The deck picker reads its starting selection from the profile's remembered
-- deck (G.UIDEF.run_setup_option line ~5968). Pointing that at the challenge
-- deck for the duration of the build is what makes "as the challenge ships"
-- the default, with any other pick overriding it.
--
-- Swapped and restored around the call rather than written through: this is
-- the player's saved preference, and a challenge should not change which deck
-- their next ordinary run starts on.
local run_setup_option_ref = G.UIDEF.run_setup_option
function G.UIDEF.run_setup_option(type)
  if not (Setup.active and type == "New Run") then
    return run_setup_option_ref(type)
  end

  add_challenge_back()
  local memory = G.PROFILES and G.SETTINGS and G.PROFILES[G.SETTINGS.profile]
    and G.PROFILES[G.SETTINGS.profile].MEMORY
  if not memory then return run_setup_option_ref(type) end

  local remembered = memory.deck
  memory.deck = G.P_CENTERS[CHALLENGE_BACK] and G.P_CENTERS[CHALLENGE_BACK].name or remembered
  -- pcall so a failure inside the vanilla builder cannot strand the player's
  -- remembered deck pointing at a deck they never chose.
  local ok, out = pcall(run_setup_option_ref, type)
  memory.deck = remembered
  if not ok then error(out, 0) end
  return out
end

--- Did the player pick a deck other than the one the challenge ships with?
--- The precedence patch calls this; when it is false, nothing changes.
---
--- Setup.active is the load-bearing half. G.GAME.viewed_back persists from
--- whatever deck was last looked at in the ordinary New Run screen, so
--- comparing it alone said "overridden" for a challenge started straight from
--- PLAY -- and Big Wee launched on whichever deck single player was sitting
--- on. Only a deck chosen through the Customize flow counts.
function Setup.deck_overridden()
  if not Setup.active then return false end
  if not G.GAME then return false end
  local viewed = G.GAME.viewed_back and G.GAME.viewed_back.name
  if not viewed then return false end
  local challenge_deck = G.P_CENTERS[CHALLENGE_BACK] and G.P_CENTERS[CHALLENGE_BACK].name
  return viewed ~= challenge_deck
end

-- Clear the stash once a run is under way. Deliberately AFTER the reference
-- call: start_run reads G.challenge_tab and the viewed back while building the
-- run, so clearing first would throw away the challenge itself.
local start_run_ref = G.FUNCS.start_run
G.FUNCS.start_run = function(e, args)
  local ok, err = pcall(start_run_ref, e, args)
  Setup.finish()
  if not ok then error(err, 0) end
end
