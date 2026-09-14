-- cm_no_after_hand / cm_no_after_round / cm_no_on_discard.
--
-- BU-CB implemented these as Lovely patches that skipped the per-joker
-- eval_card / calculate_joker call in state_events.lua. Balatro 1.0.1o replaced
-- those loops with SMODS.calculate_context, so all three patterns stopped
-- matching and the modifiers silently did nothing.
--
-- SMODS.calculate_card_areas('jokers', context, ...) is where jokers are
-- dispatched, separately from playing_cards and individual. Skipping just that
-- call for the relevant contexts gives exactly what the rules promise --
-- "Joker abilities are disabled" -- while seals and consumables still fire.
local calculate_card_areas_ref = SMODS.calculate_card_areas

-- context flag -> modifier that disables jokers for it
local DISABLED_BY = {
  after = "cm_no_after_hand",
  end_of_round = "cm_no_after_round",
  discard = "cm_no_on_discard",
}

function SMODS.calculate_card_areas(area, context, return_table, args)
  if area == "jokers" and context and G.GAME and G.GAME.modifiers then
    for flag, modifier in pairs(DISABLED_BY) do
      if context[flag] and G.GAME.modifiers[modifier] then
        -- calculate_card_areas always returns its `flags` table, and
        -- calculate_context merges it with pairs(), so an empty table is the
        -- correct "no joker did anything" answer. Returning nil would break
        -- that merge.
        return {}
      end
    end
  end
  return calculate_card_areas_ref(area, context, return_table, args)
end
