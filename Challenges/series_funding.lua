-- Restored from BU-CB (OceanRamen/BU-CB, Challenges/240621_series_funding.lua);
-- dropped in BU-CB-DEV. Converted to the Challenge.DATA schema.
--
-- Needs cm_mult_dollar_cap, which BU-CB-DEV dropped along with the challenge;
-- it is reimplemented in smods/hooks.lua. BU-CB also listed chips_dollar_cap
-- here, but that id was never implemented in any version -- it only ever
-- produced rule text -- so it is left out rather than carried over as a no-op.
local Challenge = {}
Challenge.NAME = "Series Funding"
Challenge.DESIGNER = "sharktamer"
Challenge.DATE_CREATED = 240621 -- Y/M/D
Challenge.VERSION = "1.0.0"
Challenge.DATA = {
  rules = {
    custom = {
      { id = "cm_mult_dollar_cap" },
      { id = "no_interest" },
    },
    modifiers = {
      { id = "dollars", value = 20 },
    },
  },
  jokers = {
    { id = "j_popcorn" },
  },
  consumeables = {},
  vouchers = {},
  deck = {
    type = "Challenge Deck",
  },
  restrictions = {
    banned_cards = {
      { id = "j_burglar" },
      { id = "v_grabber" },
      { id = "v_nacho_tong" },
    },
    banned_tags = {},
    banned_other = {},
  },
}

return Challenge
