-- Big 2, as a Balatro challenge. See docs/big-wee-design.md.
local Challenge = {}
Challenge.NAME = "Big Wee"
Challenge.DESIGNER = "jimmyy"
Challenge.DATE_CREATED = 260915 -- Y/M/D
Challenge.VERSION = "0.1.0"
Challenge.DATA = {
  rules = {
    -- This order is what the player reads in the rules panel: the card order
    -- first, then scoring, then the resources you get, and the climb rule
    -- last -- next to the discard line, which is the one other place the word
    -- "climb" appears, so the two are read together.
    custom = {
      -- The two card-order rules lead: they rewrite what the player already
      -- knows about a deck, and nothing below reads correctly until they have
      -- landed.
      { id = "cm_rank_chips" },
      { id = "cm_suit_chips" },
      { id = "cm_shed_bonus" },
      { id = "cm_wrap_straights" },
      -- +5 on the base 8 gives the 13 Big 2 deals, and breathes with any
      -- deck that already changes hand size.
      { id = "cm_no_redraw", value = 5 },
      -- -2 on the base 3 leaves exactly one discard. -3 left none, which was
      -- unrecoverable: a discard is the only way to reset a climb, and the
      -- only way to earn a discard is to complete one, so an opening lead you
      -- could not beat threw away every remaining hand for nothing. Seen in
      -- play as a dead run in round 1 of ante 1. One guaranteed reset breaks
      -- that circle; every pass after it still has to be earned.
      --
      -- Written as a penalty so a deck granting extras keeps them. A negative
      -- value also turns cm_climb_refund on, so the risk and the reward read
      -- as one rule rather than two lines the player has to join up -- which
      -- is why the refund is not listed separately.
      { id = "cm_pass", value = -2 },
      { id = "cm_climb" },
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
