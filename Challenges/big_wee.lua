-- Big 2, as a Balatro challenge. See docs/big-wee-design.md.
local Challenge = {}
Challenge.NAME = "Big Wee"
Challenge.DESIGNER = "BU-CB"
Challenge.DATE_CREATED = 260915 -- Y/M/D
Challenge.VERSION = "0.1.0"
Challenge.DATA = {
  rules = {
    custom = {
      { id = "cm_trick_lock" },
      { id = "cm_pass" },
      { id = "cm_trick_refund" },
      { id = "cm_shed_bonus" },
      { id = "cm_rank_chips" },
      { id = "cm_suit_chips" },
      { id = "cm_wrap_straights" },
      { id = "cm_no_redraw" },
    },
    modifiers = {
      -- 52 cards over 4 players, as Big 2 deals. Nothing is drawn after a
      -- play, so this is the whole round's supply: worth two 5-card plays and
      -- a trailing 3.
      { id = "hand_size", value = 13 },
      { id = "hands", value = 4 },
      { id = "discards", value = 4 },
    },
  },
  jokers = {},
  consumeables = {},
  vouchers = {},
  deck = {
    type = "Challenge Deck",
  },
  restrictions = {
    banned_cards = {},
    banned_tags = {},
    banned_other = {
      -- The Psychic requires every hand to contain 5 cards, so a 1-, 2- or
      -- 3-card trick would make every legal continuation illegal and the round
      -- unwinnable.
      { id = "bl_psychic", type = "blind" },
    },
  },
}

return Challenge
