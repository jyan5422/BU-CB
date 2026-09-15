# Big Wee — design

A Big 2 (鋤大弟) challenge. The name is Big 2 crossed with the Wee Joker, which
a later version may add to push 2s further.

Every rule below is a **separate modifier**, so a joker, daily or other
challenge can take one piece without the rest. Big Wee is then just the
challenge that happens to list all of them.

## Status

Design under review. Nothing implemented yet — a draft of the comparison logic
exists outside the repo and will be rewritten against whatever this doc settles
on.

## The modifiers

### 1. `cm_trick_lock` — the core rule

The first hand played in a round fixes the trick's **shape**; every later hand
that round must match it and beat it. Failing either test throws the hand away
and clears the lock.

The shape is **card count**, not Balatro's hand name. Big 2 plays are 1, 2, 3
or 5 cards, and any legal five-card hand beats a weaker five-card hand whatever
shape it is. Locking on the name would make Two Pair and Four of a Kind special
cases; locking on count lets Balatro's own hand order rank them.

| lock | to beat it |
|---|---|
| 1 card | 1 card, higher rank |
| 2 cards | 2 cards, higher rank |
| 3 cards | 3 cards, higher rank |
| 4 cards | 4 cards, stronger hand, rank as tiebreak |
| 5 cards | 5 cards, stronger hand, rank as tiebreak |

Four-card plays are not a Big 2 shape, but Balatro offers them, so they get
their own bucket rather than being banned — disabling a play the UI presents
would read as broken.

**Rank order** (low to high): `3 4 5 6 7 8 9 10 J Q K A 2`. The 2 is highest,
as in Big 2; the Ace sits above the King.

Comparison reads `card.base.id`, the printed rank, which enhancements,
editions, seals and our own chip bonuses never touch — so a steel 5 still
compares as a 5, and scoring changes can never skew a comparison. Rankless
cards (Stone) compare as nothing and can never win, since `Card:get_id()`
returns a random negative for them.

**Tier** comes from `G.handlist`, which the game already orders strongest
first.

The lock lives on `G.GAME.current_round`, which the game clears each round, so
it resets per blind for free.

### 2. `cm_pass_only_discard` — discard becomes pass

Discard is allowed **only with no cards selected**. It spends a discard, clears
the lock, and leaves the hand untouched. With cards selected the button is
disabled: cards are never discarded, only played or held.

This is closer to Big 2 than discarding-to-improve, which does not exist there.
It is also the escape valve — without a pass you could hold 13 cards that
cannot make the locked shape.

One gate governs this, `G.FUNCS.can_discard`
(`functions/button_callbacks.lua`), whose `#G.hand.highlighted <= 0` condition
is inverted. The discard path itself already handles zero cards: it counts
`#cards` generically and spends one discard.

**Consequence:** every discard-triggered joker becomes dead, and every
discard-scaling joker stays at zero. Those must be banned in
`restrictions.banned_cards` or players will buy jokers that cannot work.

### 3. `cm_rank_chips` — Big 2 rank values as chips

Applied through `perma_bonus`, the same field Hiker uses, which
`Card:get_chip_bonus` already adds.

| card | base | target | bonus |
|---|---|---|---|
| 2 | 2 | 14 | +12 |
| J | 10 | 11 | +1 |
| Q | 10 | 12 | +2 |
| K | 10 | 13 | +3 |
| A | 11 | 15 | +4 |

Chip value then tracks Big 2's rank order, so the strongest card is also the
highest scoring and the ordering is legible from the numbers alone.

### 4. `cm_suit_chips` — spades beat hearts beat clubs beat diamonds

Also via `perma_bonus`, on top of the rank bonus. Amounts still to be chosen.
Goes through `Card:is_suit`, so Wild cards behave correctly.

### 5. `cm_wrap_straights` — 2AKQJ is a straight

`SMODS.wrap_around_straight()` already exists and returns `false`; overriding
it is one line. SMODS composes it with Four Fingers and Shortcut itself
(`game_object.lua:2913`), so the interaction worry is already handled upstream.

## The challenge

- Hand size **13** (52 / 4 players), dealt per round
- **4** hands, **4** discards to start — a guess, to be tuned by play
- All five modifiers above
- Discard-based jokers banned

## Decided and rejected

**Bonus hand for continuing a trick — rejected.** Refunding the hand on a
successful continuation would make the junk opener dominant rather than a
trade-off, and it opens a High Card exploit: singles form a 1-card lock, so a
refunded chain of rising singles is 13 scoring plays off one hand, which
levelled High Card makes lucrative. The refund and the exploit are the same
problem, so dropping the refund closes both without any anti-abuse rule.

If revisited: cap the refunds, or exclude 1-card locks from earning one.

**Inverted rank order for scoring — rejected.** Making 2 genuinely outrank
everything in Balatro's internals would fight `evaluate_poker_hand`, straight
detection and every rank-reading joker. `cm_rank_chips` gets the same feeling
through chips alone.

## Open questions

1. **Suit chip amounts.** Large enough to steer play, small enough not to
   swamp the rank bonuses.
2. **Does a failed hand cost a hand or a discard?** Costing nothing makes the
   lock toothless. A hand is harsher and closer to playing into a wall in Big 2.
3. **Button label.** The pass button will still read "Discard", which makes the
   mechanic hard to discover. Relabelling to "Pass" may be awkward in the UI
   code; an `attention_text` popup is the fallback.
4. **Starting hands and discards.** Passing is the only escape from a bad lock,
   so 4/4 is a starting guess, not a considered number.

## Note on verification

This design is reasoned from the game source. That has repeatedly proved
insufficient: several fixes this session verified cleanly on desktop and did
nothing on the phone, because the real fault was elsewhere. Expect to confirm
each rule on device, and prefer tests that assert the observable effect over
tests that assert the condition.
