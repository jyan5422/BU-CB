-- Big 2, as a Balatro challenge. See docs/big-wee-design.md.
local Challenge = {}
Challenge.NAME = "Big Wee"
Challenge.DESIGNER = "jimmyy"
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
      -- +5 on the base 8 gives the 13 Big 2 deals, and breathes with any
      -- deck that already changes hand size.
      { id = "cm_no_redraw", value = 5 },
    },
    modifiers = {
      -- Hand size comes from cm_no_redraw's +5, not a flat value here.
      { id = "hands", value = 4 },
      -- Default 3: a challenge should feel like a boss, and passes are meant
      -- to be scarce.
      { id = "discards", value = 3 },
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
      -- The Eye forces a different hand type every hand while the trick lock
      -- wants the same size repeated, which can leave a round unwinnable.
      { id = "bl_eye", type = "blind" },
    },
  },
}

return Challenge
