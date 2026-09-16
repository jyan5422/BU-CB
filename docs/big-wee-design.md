# Big Wee — design

A Big 2 (鋤大弟) challenge. The name is Big 2 crossed with the Wee Joker, which
a later version may add to push 2s further.

Every rule below is a **separate modifier**, so a joker, daily or other
challenge can take one piece without the rest. Big Wee is then just the
challenge that happens to list all of them.

## Status

Design agreed; implementation next. Seven modifiers, of which the trick lock is
the only substantial one.

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

**Suit order** (low to high): diamonds, clubs, hearts, spades. Big 2 has no
ties -- every card in the deck is distinct -- so suit always breaks an equal
rank, and a pair of 7s *does* beat another pair of 7s when its deciding card
has the higher suit.

**The deciding card is the hand's defining group, not its highest card.** A
full house 3-3-3-9-9 is a "three", because the triple carries it; four of a
kind 5-5-5-5-K is a "five", the king being only a kicker. So the largest group
wins, ties between equal-sized groups fall back to rank, and suit breaks what
remains.

Comparison reads `card.base.id`, the printed rank, which enhancements,
editions, seals and our own chip bonuses never touch — so a steel 5 still
compares as a 5, and scoring changes can never skew a comparison. Rankless
cards (Stone) compare as nothing and can never win, since `Card:get_id()`
returns a random negative for them.

**Tier** comes from `G.handlist`, which the game already orders strongest
first.

The lock lives on `G.GAME.current_round`, which the game clears each round, so
it resets per blind for free.

### 2. `cm_pass` — discard nothing to pass

Discarding with **no cards selected** is allowed: it spends a discard, clears
the lock, and leaves the hand untouched. Normal discards still work as usual.

Only one gate needs changing, the `#G.hand.highlighted <= 0` condition in
`G.FUNCS.can_discard` (`functions/button_callbacks.lua`). The discard path
already handles zero cards — it counts `#cards` generically and spends one
discard.

The pass is the escape valve: without it you could hold 13 cards that cannot
make the locked shape and cannot afford to discard into a worse position.

**Discarding cards does not clear the lock** — only a pure pass does.
Otherwise discarding would be strictly better than passing and the pass would
have no reason to exist.

Earlier drafts made discard *pass-only*, banning card discards outright. That
was rejected: discards feeding jokers and money is core Balatro (Faint, Ramen,
Trading Card, Castle, Mail-In Rebate), and banning them would have meant
banning a large slice of the joker pool, making the challenge narrower rather
than more interesting.

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

Also via `perma_bonus`, on top of the rank bonus: spades +3, hearts +2,
clubs +1, diamonds +0. Goes through `Card:is_suit`, so Wild cards behave
correctly.

An ace of spades scores 18, a three of diamonds 3 — enough spread to steer
play without swamping the rank bonuses.

These bonuses affect **score only, never comparison**. Comparing by total chips
was considered and rejected: the suit bonuses leak across ranks, so a pair of
5s (15) ties a pair of 7s (15), and a pair of aces (31) beats a pair of 2s
(29), both of which contradict Big 2. Rank decides who wins; chips decide what
it scores.

### 5. `cm_wrap_straights` — 2AKQJ is a straight

`SMODS.wrap_around_straight()` already exists and returns `false`; overriding
it is one line. SMODS composes it with Four Fingers and Shortcut itself
(`game_object.lua:2913`), so the interaction worry is already handled upstream.

### 6. `cm_trick_refund` — hold the trick, keep the pass

A successful continuation refunds one discard.

This is the counterweight to how punishing the lock is. It cannot be exploited
the way a *hand* refund could: a hand refund made chains self-financing, so
rising singles became thirteen free High Card plays. Discards cannot be spent
for score — only to pass or to feed a discard joker — so there is no path from
refunds to points.

It also reads right: keeping control of the trick means you never had to pass,
so you get the pass back.

### 7. `cm_shed_bonus` — going out pays, by how you go out

Playing your **last** card earns an Xmult graded on the hand you go out with,
taken from `G.handlist` so it needs no ranking of its own:

`Xmult = 1 + (tier - 1) * 0.5`, where tier 1 is High Card and 12 is Flush Five.

| exit hand | Xmult |
|---|---|
| Flush Five | 6.5x |
| Flush House | 6.0x |
| Five of a Kind | 5.5x |
| Straight Flush | 5.0x |
| Four of a Kind | 4.5x |
| Full House | 4.0x |
| Flush | 3.5x |
| Straight | 3.0x |
| Three of a Kind | 2.5x |
| Two Pair | 2.0x |
| Pair | 1.5x |
| High Card | none (1x) |

High Card landing on exactly 1x is what makes this work: dumping your last five
junk cards still gets you out, but pays nothing. Going out on a hand you held
back deliberately pays properly. Combined with the cheap junk *opener*, the
ideal round is open weak, climb, exit strong.

The top tiers are close to unreachable, since the exit must also match the
locked size and beat it, so they are trophies rather than balance concerns.

**Emptying your hand ends the round**, resolving through the existing check: if
the blind is met you advance, if not you lose. Without this you are stranded --
`can_play` is gated on `#G.hand.highlighted <= 0`, so with no cards you cannot
play, only burn discards on passes you can never follow up. Ending it is honest
about a position that is already decided.

That makes the shed bonus a real gamble: go out for the Xmult and it had better
clear the blind, because there is no next hand. Going out early is how you lose
in Big 2 too.

**Do not implement this by zeroing `card_limit`.** The game-over check at
`functions/state_events.lua:330` fires when `card_limit <= 0` *and* the hand is
empty, so clearing the limit would turn the reward into an instant loss. An
empty hand with the limit still at 13 is safe -- it simply draws nothing.

## The challenge

- Hand size **13** (52 / 4 players), dealt per round
- **4** hands, **4** discards to start — a guess, to be tuned by play
- All seven modifiers above
- **The Psychic banned** (`bl_psychic`, `debuff = {h_size_ge = 5}`): it requires
  every played hand to contain 5 cards, so a 1-, 2- or 3-card lock would make
  every legal continuation illegal and the round unwinnable. It runs through the
  same `debuff_hand` seam this challenge uses.

## Decided and rejected

**Failed hands cost a hand.** Same as playing an illegal hand into a boss that
gates hand size. Costing nothing would make the lock toothless.

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

## The rules, as a player reads them

Each should fit on one line, like a joker:

- Hands must match the last hand's size and beat its rank.
- Same size and higher rank earns a discard.
- Discard nothing to pass.
- Play your last card for Xmult, better hands pay more.

## Open questions

1. **Button label.** The pass button will still read "Discard", which makes the
   mechanic hard to discover. Relabelling to "Pass" when nothing is selected
   may be awkward in the UI code; an `attention_text` popup is the fallback.
2. **Starting hands and discards.** 4/4 is a starting guess, not a considered
   number.
3. **Is 13 enough compensation for no redraw?** Decided yes: 13 cards buys two
   full 5-card plays plus a trailing 3, so a round is 2-3 plays before the hand
   runs dry, and the drawdown is the point rather than a cost. If it plays too
   harshly the dial is the hand size (13 -> 15), not a new mechanic.

**v2 candidate:** mult rising as the hand shrinks, so the endgame is the
strongest moment. Very Balatro and very Big 2 -- it would turn the drawdown
from a cost into a build -- but it is another modifier and more balance
surface, so it waits until the base version has been played.

## Note on verification

This design is reasoned from the game source. That has repeatedly proved
insufficient: several fixes this session verified cleanly on desktop and did
nothing on the phone, because the real fault was elsewhere. Expect to confirm
each rule on device, and prefer tests that assert the observable effect over
tests that assert the condition.
