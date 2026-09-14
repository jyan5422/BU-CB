-- Restored from BU-CB (OceanRamen/BU-CB, Challenges/240615_cryptojacked.lua);
-- dropped in BU-CB-DEV. Converted to the Challenge.DATA schema.
local Challenge = {}
Challenge.NAME = "Cryptojacked"
Challenge.DESIGNER = "Millie"
Challenge.DATE_CREATED = 240615 -- Y/M/D
Challenge.VERSION = "1.0.0"
Challenge.DATA = {
  rules = {
    custom = {},
    modifiers = {
      { id = "discards", value = 0 },
    },
  },
  jokers = {
    { id = "j_delayed_grat", eternal = true, debuff = true },
  },
  consumeables = {},
  vouchers = {},
  deck = {
    type = "Challenge Deck",
  },
  restrictions = {
    banned_cards = {
      { id = "j_ring_master" },
      { id = "j_burglar" },
      { id = "j_merry_andy" },
      { id = "j_drunkard" },
      { id = "v_wasteful" },
      { id = "v_recyclomancy" },
    },
    banned_tags = {},
    banned_other = {},
  },
}

return Challenge
