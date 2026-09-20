-- Big 2, as a Balatro challenge. See docs/big-wee-design.md.
local Challenge = {}
Challenge.NAME = "Big Wee"
Challenge.DESIGNER = "jimmyy"
Challenge.DATE_CREATED = 260915 -- Y/M/D
Challenge.VERSION = "0.1.0"
Challenge.DATA = {
  rules = {
    -- This order is what the player reads in the rules panel, so it runs from
    -- the rule that defines the challenge down to the resources it hands you.
    -- The hand-size and discard lines sit last and together: both are about
    -- what you start a round holding.
    custom = {
      { id = "cm_climb" },
      { id = "cm_shed_bonus" },
      { id = "cm_rank_chips" },
      { id = "cm_suit_chips" },
      { id = "cm_wrap_straights" },
      -- +5 on the base 8 gives the 13 Big 2 deals, and breathes with any
      -- deck that already changes hand size.
      { id = "cm_no_redraw", value = 5 },
      -- -3 on the base 3 leaves no discards, so every pass has to be earned
      -- by climbing. Written as a penalty so a deck granting extras keeps them.
      -- A negative value also turns cm_climb_refund on, so the risk and the
      -- reward read as one rule rather than two lines the player has to join
      -- up -- which is why it is not listed separately.
      { id = "cm_pass", value = -3 },
    },
    modifiers = {
      -- Hand size comes from cm_no_redraw's +5, not a flat value here.
      { id = "hands", value = 4 },
      -- Discards come from cm_pass's -3, not a flat value here.
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
