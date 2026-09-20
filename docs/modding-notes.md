# Balatro modding notes

Hard-won facts from building Big Wee. Everything here cost at least one wrong
fix. Read before adding a challenge, modifier or joker.

Versions: Lovely 0.7.1, Steamodded 1.0.0-beta-1814a.

## The failure pattern to watch for

Specs passed while the game was broken **four separate times**, always for the
same reason: *the stub modelled a narrower world than the game.*

| stub assumed | game actually does | bug it hid |
|---|---|---|
| `current_round` replaced each round | mutated field by field | stale lock rejected every round's first hand |
| one suit | four | boosted 2 sorted into the next suit |
| Pair only ever met Pair | any 2 cards are playable | King-3 beat a pair of 7s |
| `SMODS.Modifier` exists | it does not | guarded block never ran, silently |

Two rules that would have caught all four:

1. **Make the stub's shape match the game's shape**, especially for the
   dimension you are *not* thinking about.
2. **Confirm a new spec fails against the old code** before keeping it. A spec
   written after the fix proves nothing until you revert and watch it go red.

And assert observable effects — score, sort order, placement — not the
condition you happen to be thinking about.

## Diagnose by looking, not by reasoning

Three UI bugs in a row were misdiagnosed on the first pass, each time by
reasoning about *which mechanism* was at fault instead of checking *where the
thing actually landed*:

| symptom | my first theory | actual cause |
|---|---|---|
| flash off to one side, drifting | needed a different offset | `card_eval_status_text` anchors to a **card** |
| two messages overprinting | needed a delay | game queues `before`, ours `after` — they never ordered |
| subtext too small | needed a bigger scale | `DynaText` **autofits** to `maxw` |

In all three the fix was structural, not a parameter. The cheap check that
would have short-circuited each: look at what the thing is *anchored to* and
what *sizes* it, before touching numbers. Position bugs are anchor bugs; size
bugs are fit bugs; ordering bugs are queue-kind bugs.

Corollary: when two things must not collide, separate them in **space**, not in
time. A different place cannot collide however the event queue resolves.

## Verifying a change

In order, cheapest first:

```sh
./run_tests.sh                       # specs
balatro-run /path/to/staged/mod      # launches the real game, regenerates the dump
grep "no matches" <log> | grep -v smods/lovely   # YOUR failed patches
grep <payload> ~/.local/share/love/Mods/lovely/dump/<file>  # did it land?
./push_to_phone.sh                   # device
```

- A failed Lovely pattern is a `WARN` in the log and **otherwise silent**. It
  never raises. Always grep for it, filtered to your own toml.
- `dump_lua = true` writes the post-patch source to
  `~/.local/share/love/Mods/lovely/dump/`. That is the ground truth for what
  runs — not this repo's copy of the game source.
- Do **not** syntax-check the dump with `luac`: the game uses LuaJIT's
  `continue`, so `luac` reports a false error on every file.
- Desktop passing does not mean the device passes. Several fixes verified
  cleanly on desktop and did nothing on the phone.
- `sendInfoMessage` writes to the Lovely log, which is impractical to read on
  Android. For device instrumentation, draw on screen (a `Game.draw` hook)
  instead.

## Packaging

- Lovely reads patches from `Mods/<dir>/lovely/` — **exactly one level deep**.
  A zip containing a wrapping folder yields `Mods/<zip>/<wrapper>/lovely/`,
  which Lovely never looks at. Ship a **flat** zip. This cost the longest
  debugging session of the project; every patch was simply absent.
- SMODS finds mods by a recursive scan for `*.json`. Lovely does not recurse.
  The two have different discovery rules, so a mod can load while its patches
  are ignored — which looks exactly like a logic bug.

## Steamodded

- `SMODS.Modifier` **does not exist** in 1814a. Never write
  `if SMODS.X then ... end` for an API you have not confirmed: the block just
  never runs, and nothing tells you.
- `SMODS.Challenge:register()` re-inserts into `G.CHALLENGES` (duplicate-key
  warnings) and `SMODS.add_prefixes` rewrites ids to `c_chmod_*`. Renaming a
  challenge id **orphans save progress** — see `smods/migrate_progress.lua`.
- SMODS patches the base game too. When anchoring a Lovely patch on a line
  SMODS also touches, anchor on **SMODS's rewritten text**, from the dump. A
  patch written against vanilla `game.lua` silently matched nothing.

## Scoring

- The round score comes from `SMODS.Scoring_Parameters.mult.current`, not the
  local `mult` in `evaluate_play`. Writing only the local moves the on-screen
  number and changes nothing else.
- `G.FUNCS.evaluate_play` has **one** call site, inside a one-shot event, so it
  runs exactly once per played hand. Side effects there (refunds, setting
  state) are safe.
- The **final scoring step inside it can run more than once.** A multiplier
  applied there must scale whatever that pass built and must *not* be guarded
  once-per-hand — the guard catches the first pass and the later, unmultiplied
  value is the one banked. This is the opposite of the rule above; do not
  generalise one to the other.
- `Card:get_chip_bonus` already adds `ability.perma_bonus`, the field Hiker
  writes. That is the clean seam for changing a card's chip value.

## Card ordering — `Card:get_nominal`

```
10*nominal*rank_mult + suit_nominal*mult + 10*face_nominal*rank_mult + ...
mult = 1 normally, 10000 when sorting by suit
```

`suit_nominal` steps by **0.01** per suit, so sorting by suit gives each suit a
band **100** wide, and ranks fill roughly `[30, 110]` of it (a 3 up to an ace).

Any rank shift therefore has an **upper** bound as well as a lower one: above
about 12 as a replacement nominal, the card crosses into the neighbouring
suit's band and the suit grouping visibly breaks. Shifts must also be scaled by
10 to survive against the suit term — adding to the *result* instead of
substituting the nominal does nothing.

`get_nominal` also drives `get_highest`, which picks the High Card scorer. A
sort change is therefore a scoring change too.

## Hand validation — `Blind:debuff_hand(cards, hand, handname, check)`

- Returning `true` throws the hand away: it scores nothing and still costs a
  hand, like playing an illegal hand into a hand-size boss.
- `check = true` is the UI pre-query from `CardArea:parse_highlighted`. It sets
  `G.boss_throw_hand`, which is what raises the "Hand will not score" warning.
  **Never mutate state on the check pass** — it runs on every selection change.
- `check = false` is the real play, once per hand.
- Cards come from `G.hand.highlighted` on the check pass and `G.play.cards` on
  the real one.

Compare by `card.base.id` (printed rank), which enhancements, editions, seals
and chip bonuses never touch. Rankless cards (Stone) return a large random
negative from `Card:get_id()` and must be excluded explicitly.

## UI

- **The "Hand will not score" warning** (`game.lua`, `Game:update`) has rows:
  the label, and the blind's `get_loc_debuff_text()` — which is `''` on a
  non-boss blind, a free slot. Big Wee adds a third row via
  `lovely/cm_climb_warning_row.toml`.
- **`DynaText` caches its string.** A row built once keeps its first value
  forever. SMODS solves this with a `func` on the node that diffs and calls
  `update_text(true)` plus `UIBox:recalculate()` — copy that idiom rather than
  destroying and rebuilding the box.
- **`DynaText` with `maxw` shrinks text to fit.** A long string renders small.
  That is autofit, not a scale bug — shorten the string or give it its own row.
- **`card_eval_status_text(card, ...)` anchors to a card**, so the text sits
  wherever that card is and slides with the scoring animation. Fine for a joker
  triggering; wrong for a message about the hand. For hand-level messages use
  `attention_text` with `major = G.play, align = 'tm', offset = {y = -1}`,
  which is what the game's own `play_area_status_text` does.
- Its `eval_type` matters: `'x_mult'` **builds its own text and ignores** a
  custom `message`; `'extra'` honours it.
- Centred text (`G.ROOM_ATTACH`, `align = 'cm'`) is right while the player is
  choosing and **wrong once a hand is committed** — the cards fly to the middle
  and draw on top of it.
- Sequential messages at one anchor need a delay, or they overlap. An
  `attention_text` holds ~0.9s.

## Round and hand state

- **`G.GAME.current_round` is mutated field by field between rounds, never
  replaced.** A custom key survives into the next round. Stamp per-round state
  with `G.GAME.round` (monotonic, bumped per blind) and treat a mismatched
  stamp as stale. `any_hand_drawn` does not work as a stamp: `new_round` clears
  it and the opening deal immediately sets it again.
- The discard body is wrapped in `if highlighted_count > 0`, so a **zero-card
  discard is free** unless you charge it yourself (`ease_discard(-1)` plus the
  `discards_used` bump). The gate to open is `#G.hand.highlighted <= 0` in
  `G.FUNCS.can_discard`.
- `G.GAME.starting_params.discard_limit` is an SMODS addition meaning
  **cards per discard** (default 5), not the number of discards
  (`starting_params.discards`). Easy to misread when reducing discards.
- The opening deal and every refill share `draw_from_deck_to_hand`, so blocking
  all draws starts the round empty. Gate on the game's own
  `current_round.any_hand_drawn`, and exempt booster-pack states.
- The game-over check fires when `card_limit <= 0` **and** the hand is empty —
  so never express "draws nothing" by zeroing `card_limit`; it turns into an
  instant loss. An empty hand with the limit intact is safe.
- Ending a round early: zero `hands_left` and let the existing resolution
  handle win or loss. The hook in `Game:update_hand_played` can only fire after
  a hand is played, so it cannot pre-empt the opening deal.
- `Blind:get_type()` has no `else` branch and can return **nothing**, so
  `tostring(self:get_type())` crashes.

## Balance

- A bonus applied **last** multiplies everything the build produced, so its
  real value tracks joker scaling, not its own number. An X2 at the end of a
  chain is far larger than X2 looks. Moving such a bonus **earlier** shrinks it
  with build strength instead of against it — the right lever when a late
  multiplier feels oppressive.
- Before nerfing a payout, check whether it was load-bearing. Big Wee's shed
  bonus looked excessive at 6,216 points; without it that hand scored 3,498
  against a 4,000 blind and lost.
- Keep a payout table **non-decreasing in `G.handlist` order** and assert it
  over the whole table. A flush paying less than the straight it beats is the
  kind of dip only a whole-table assertion catches.
- Bosses can make a rule unwinnable rather than hard. The Psychic (every hand
  must be 5 cards) and The Eye (a different hand type every hand) both fight a
  rule that constrains hand shape; both are banned in Big Wee. Check every
  boss against a new constraint and ban the contradictions.
