# Big Wee — design

A Big 2 (鋤大弟) challenge. The name is Big 2 crossed with the Wee Joker, which
a later version may add to push 2s further.

Every rule below is a **separate modifier**, so a joker, daily or other
challenge can take one piece without the rest. Big Wee is then just the
challenge that happens to list all of them.

## Status

Implemented and being played. Eight modifiers, of which the climb rule is the
only substantial one.

The rules were later checked against pagat's Big Two page, which confirmed the
rank order (2-A-K-Q-J-10 down to 3), the suit order
(spades-hearts-clubs-diamonds), a full house being compared by its triple, and
a five-card group being beaten by a stronger type. Big Two is a **climbing**
game in pagat's taxonomy, not a multi-trick one, which is why the modifiers are
named `cm_climb` rather than anything involving tricks.

## The modifiers

### 1. `cm_climb` — the core rule

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
| 2 cards | 2 cards, same hand type, higher rank |
| 3 cards | 3 cards, same hand type, higher rank |
| 4 cards | 4 cards, stronger hand, rank as tiebreak |
| 5 cards | 5 cards, stronger hand, rank as tiebreak |

**Hand type is compared at every count**, then rank breaks the tie. Big 2 ranks
pairs and triples by rank alone, but only because a two-card play there is
always a pair. Balatro will play any two cards, so comparing rank alone let
King-3 ("High Card") beat a pair of 7s on the king, and three junk cards beat a
triple. Found in adversarial review; the specs had only ever compared Pair
against Pair. A consequence worth knowing: a pair-plus-kicker can lead a
three-card climb, and a genuine triple then beats it.

Four-card plays are **not legal in Big Two** -- pagat is explicit that a five
card group is the only multi-card play above a triple -- but Balatro offers
them, so they get their own bucket rather than being banned. Disabling a play
the UI presents would read as broken, and where the two games disagree this is
Balatro's. Decided deliberately, not overlooked.

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

The lock lives on `G.GAME.current_round`, but the game does **not** replace
that table between rounds -- it mutates named fields, so a key of our own
survives into the next round and would reject its first hand. The lock is
therefore stamped with `G.GAME.round`, a counter the game bumps per blind, and
treated as stale when the stamp no longer matches. Two earlier attempts got
this wrong (a custom flag, then `any_hand_drawn`, which `new_round` clears and
the deal immediately re-sets).

### 2. `cm_pass` — discard nothing to pass

Discarding with **no cards selected** is allowed: it spends a discard, clears
the lock, and leaves the hand untouched. Normal discards still work as usual.

Two places need changing, not one. The gate is the `#G.hand.highlighted <= 0`
condition in `G.FUNCS.can_discard` (`functions/button_callbacks.lua`). But the
discard path does **not** already handle zero cards: its whole body sits inside
`if highlighted_count > 0`, so a zero-card discard was free until the charge
was added in the wrapper (`ease_discard(-1)` plus the `discards_used` bump).
Observed in play as a pass that cost nothing.

The pass is the escape valve: without it you could hold 13 cards that cannot
make the locked shape and cannot afford to discard into a worse position.

**Any discard clears the lock**, whether or not cards were selected. Giving up
the trick is the cost of discarding at all, which keeps improving your hand and
keeping the trick in tension without making a zero-card discard a special case.
An earlier draft cleared only on a pure pass; that made discarding strictly
better than passing.

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
| 2 | 2 | 15 | +13 |
| J | 10 | 11 | +1 |
| Q | 10 | 12 | +2 |
| K | 10 | 13 | +3 |
| A | 11 | 14 | +3 |

Chips match the rank order exactly, so the highest rank is also the
highest-scoring one. An earlier draft had A 15 and 2 14, which scored the ace
above the 2 while the 2 outranked it.

Chip value then tracks Big 2's rank order, so the strongest card is also the
highest scoring and the ordering is legible from the numbers alone.

### 4. `cm_suit_chips` — spades beat hearts beat clubs beat diamonds

Also via `perma_bonus`, on top of the rank bonus: spades +3, hearts +2,
clubs +1, diamonds +0. Goes through `Card:is_suit`, so Wild cards behave
correctly.

An ace of spades scores 17 (11 base, +3 rank, +3 suit), a three of diamonds 3 — enough spread to steer
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

### 6. `cm_climb_refund` — hold the climb, keep the pass

Turned on by a negative `cm_pass` value rather than listed separately, so the
risk and the reward read as **one** rule to the player: "-3 discards, but earns
a discard by climbing". It stays a modifier of its own so a joker or another
challenge can take the reward without the penalty.

A successful continuation refunds one discard.

This is the counterweight to how punishing the lock is. It cannot be exploited
the way a *hand* refund could: a hand refund made chains self-financing, so
rising singles became thirteen free High Card plays. Discards cannot be spent
for score — only to pass or to feed a discard joker — so there is no path from
refunds to points.

It also reads right: keeping control of the trick means you never had to pass,
so you get the pass back.

### 7. `cm_no_redraw` — hand size +N, and nothing drawn after

> +5 hand size, but no cards are drawn until the next round

Written as a **bonus, not a flat size**, so it composes with whatever the deck
or challenge already grants: the vanilla base of 8 becomes 13, the Big 2 deal,
while a Painted Deck's +2 becomes 15 instead of being overridden. The value is
the bonus, so the rule reads as one line like a joker's.

The dwindling hand is the game: playing five of thirteen leaves eight, and that
is what produces the Big 2 endgame of holding three cards that have to do
something.

The opening deal and every refill share one function, so the patch cannot
simply block all draws -- the round would start empty. `ChallengeMod.Draw`
tracks whether the round has dealt and lets only the first through. Booster
packs are exempt, since they draw into the hand for their own selection UI.

The 13 cards are the compensation: two full 5-card plays and a trailing 3, so a
round is 2-3 plays before the hand runs dry. If that plays too harshly the dial
is the hand size, not a new mechanic.

### 8. `cm_shed_bonus` — going out pays, by how you go out

Playing your **last** card earns an Xmult graded on the hand you go out with,
from an explicit table of hand names. An earlier version derived it from the
`G.handlist` tier index, which is why the text used to claim it "needs no
ranking of its own"; the table replaced that because a tier-derived curve was
finer-grained than a player could read.

Keyed on what the hand **contains**, not Balatro's tier index, so the numbers
stay small and predictable -- a pair is X2 whether it is a bare pair, two pair
or sitting inside a flush.

| exit hand | Xmult |
|---|---|
| Pair, Two Pair | X2 |
| Three of a Kind, Straight, Flush, Full House | X3 |
| Four of a Kind and above | X4 |
| High Card | none |

The payout must never dip as the hand gets stronger. The flush originally paid
X2, on the reasoning that it contains no group -- but it sits above both the
straight and the triple in `G.handlist`, so it paid less than two hands it
beats, and matched two pair while being harder to assemble from five cards.
A spec now asserts the whole table is non-decreasing in tier order.

A full house pays X3 for its triple even though it outranks a flush, and
everything from four of a kind up pays X4 -- those are rare enough that
splitting them further would go unnoticed. An earlier version scaled 1.5 to 6.5
across all twelve tiers, which was finer-grained than a player could read.

High Card paying nothing is what makes this work: dumping your last five junk
cards still gets you out, but earns no bonus. Going out on a hand you held
back deliberately pays properly. Combined with the cheap junk *opener*, the
ideal round is open weak, climb, exit strong.

The top tiers are close to unreachable, since the exit must also match the
locked size and beat it, so they are trophies rather than balance concerns.

**Emptying your hand ends the round**, resolving through the existing check.
Implemented under `cm_no_redraw` rather than here, since it is the absence of a
redraw that makes an empty hand terminal -- a challenge taking the shed bonus
alone still refills its hand. The patch sits in `Game:update_hand_played`, so
it can only fire after a hand is played and never before the opening deal: if
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

- Hand size **+5**, giving the 13 that Big 2 deals from a vanilla base of 8
- **4** hands to start, and **one** discard: `cm_pass` carries a **-2** penalty
  on the base 3. Written as a penalty rather than a flat 1 so a deck granting
  extra discards keeps them.

  It was -3 (no discards) and that was unrecoverable, not merely hard. A
  discard is the only way to reset a climb, and the only way to earn a discard
  is to complete a climb -- so an opening lead you could not beat left no
  escape at all, and every remaining hand was thrown away for nothing.
  Observed as a dead run in round 1 of ante 1: 4 hands gone, 30 points of 300.
  Worst for a new player, who does not yet know that the 2 is the highest rank
  or that a five-card climb needs another five-card hand. One guaranteed reset
  breaks the circle; every pass after it still has to be earned.
- All eight modifiers above
- **The Psychic banned** (`bl_psychic`, `debuff = {h_size_ge = 5}`): it requires
  every played hand to contain 5 cards, so a 1-, 2- or 3-card lock would make
  every legal continuation illegal and the round unwinnable. It runs through the
  same `debuff_hand` seam this challenge uses.
- **The Eye banned** (`bl_eye`): it forces a different hand type every hand
  while the climb wants the same shape repeated, which can leave a round
  unwinnable for the same reason.

## Observed in play

One run at ante 3 (round 7, The Hook, 4,000 to beat) went out on a Two Pair
lvl.2 for 259 x 24 = 6,216 against 390 already banked. Without the shed bonus
that hand scores 3,108, for 3,498 total -- a loss by 502. **The shed bonus was
the difference between clearing the blind and failing it**, which is the gamble
the design asked for rather than a surplus.

Worth recording because the instinct on seeing 6,216 was to cut the bonus. The
number to look at first is the mult it multiplied: five jokers had turned a
base 3 into 12 before the bonus applied. The bonus doubles whatever the build
produced, so joker scaling is the larger multiplier and cutting the bonus
punishes a weak build harder than a strong one. If the bonus ever does need
cutting, moving it earlier (so jokers scale on top of it rather than it scaling
their work) is the lever that shrinks with build strength instead of against it.

A second thing that run exposed: `cm_climb_refund` fires on the exit hand too,
refunding a discard at the moment the round ends and it can never be spent.

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

**Sorting the 2 has an upper bound as well as a lower one.** `cm_rank_chips`
also moves the 2 in `Card:get_nominal` so the hand reads in Big 2 order.
Sorting by suit passes `mult = 10000` and `suit_nominal` steps by 0.01, so each
suit owns a band 100 wide and ranks fill [30, 110] of it. A replacement nominal
above 12 pushes the 2 past the next band's floor and it sorts into the
neighbouring suit -- seen in play as a 2 of hearts among the spades. 11.5
clears the ace's 11 and stays in the band. The spec stub had hardcoded a single
suit, so no test could have caught it.

**Inverted rank order for scoring — rejected.** Making 2 genuinely outrank
everything in Balatro's internals would fight `evaluate_poker_hand`, straight
detection and every rank-reading joker. `cm_rank_chips` gets the same feeling
through chips alone.

## The rules, as a player reads them

Each should fit on one line, like a joker:

- +5 hand size, dealt once per round.
In the order they appear, which runs from the rule that defines the challenge
down to the resources it hands you:

- 2 is the highest rank.
- Spades > hearts > clubs > diamonds. *(each suit in its own colour)*
- Shed your cards for up to X4.
- Straights may wrap around.
- +5 hand size, dealt once per round.
- -2 discards, earns a discard by climbing.
- Climb: same size, higher rank.

The two card-order rules lead, because they rewrite what the player already
knows about a deck and nothing below them reads correctly until they have
landed. Together they state the Big 2 order exactly: **rank** first, suit as
the tie-break. "Highest rank" rather than "highest card" is deliberate -- the
highest *card* is the 2 of spades specifically, since suit splits equal ranks,
and "rank" also echoes the climb rule's "higher rank". The climb rule sits last, next to the discard line -- the one other
place the word "climb" appears -- so the two are read together.

The hand-size and discard lines sit last and next to each other: both are
about what you start a round holding.

The penalty and the refund are one line, not two: they are a single
risk/reward decision and splitting them made the player join them up. "Discard
to start a new climb" was dropped from this list because the in-game warning
now says "discard to reset" at the moment it matters, which teaches it better
than a rules screen does.

## Open questions

1. **Button label.** The pass button still reads "Discard", which makes the
   mechanic hard to discover. Partly addressed: the "Hand will not score"
   warning now carries "..., discard to reset" as its subtext, so the escape is
   named at the moment the player needs it. Relabelling the button to "Pass"
   when nothing is selected is still open.
2. **Starting hands and discards.** 4 hands and 1 discard (`cm_pass -2` on
   the base 3). Arrived at from both ends: 3 was too strong, 0 was
   unrecoverable. Still a balance guess rather than a tuned number.
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
