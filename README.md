# BU-CB (personal fork)

A personal fork of **[BU-CB](https://github.com/OceanRamen/BU-CB)** — the Balatro
University Challenge Bundle, a custom challenge mod by
**[OceanRamen (Djynasty)](https://github.com/OceanRamen)**.

All the challenges, mechanics and design work here are theirs and their
collaborators'. This fork exists for personal experiments and is not a
replacement for the upstream mod — if you just want to play BU-CB, get it from
the original repository above.

## Where this sits

```
OceanRamen/BU-CB               the mod
└── OceanRamen/BU-CB-DEV       upstream development branch
    └── ilikecheese0/BU-CB-DEV playtester/development fork
        └── this repository    personal fork
```

Forked from [ilikecheese0/BU-CB-DEV](https://github.com/ilikecheese0/BU-CB-DEV),
which tracks OceanRamen's development repo.

## What differs from upstream

Upstream loads through the Lovely injector directly. This fork adds a
[Steamodded](https://github.com/Steamodded/smods) entry point
(`ChallengeMod.json` + `ChallengeMod.lua`) so the mod loads as an SMODS mod,
keeping the upstream challenge/mechanic files unmodified so changes stay easy to
pull in. The per-mechanic patches under `lovely/` still apply as Lovely patches.

### New in this fork

**Deck and stake choice for any challenge.** A **Customize** button sits beside
PLAY on the challenge panel. PLAY is unchanged — start now, White stake, the
challenge's own deck. Customize opens the game's own New Run screen with the
challenge held, so you can pick a deck and stake first, with the challenge's
own deck pre-selected.

What a challenge declares still wins where it matters: an explicit card list
short-circuits deck generation, so a deck's effect cannot rewrite it. The deck's
own bonuses land on top — a Red Deck's extra discard applies before the
challenge's discard rule adjusts it.

**Custom blind curves respect the stake.** `cm_scaling` replaces vanilla's blind
table outright, so it never read the field stakes raise — a custom-curve
challenge played on Gold used White-stake blinds. The stake's effect is now
measured off the vanilla curve at runtime and applied to the custom one, so a
custom challenge gets as much harder between stakes as an ordinary run does.
This was invisible until stake became selectable.

**Big Wee** — a [Big 2](https://www.pagat.com/climbing/bigtwo.html) challenge,
and the first challenge written in this fork. Every hand must match and beat the
one before it, the 2 is the highest rank, suits break ties, and emptying your
hand pays an Xmult graded on how you go out. Built from eight reusable
modifiers rather than one bespoke rule, so a future joker or challenge can take
any single piece. Design notes and the reasoning behind each rule, including
what was rejected, are in [`docs/big-wee-design.md`](docs/big-wee-design.md).

**Restored challenges** dropped from the upstream development branch:
Cryptojacked, Jokerless?, Series Funding and Target Practice. This fork treats
BU-CB as a collection of ideas worth keeping rather than a single lineage.

[`docs/modding-notes.md`](docs/modding-notes.md) records the game internals and
testing traps found along the way — each one cost at least one wrong fix.

## Testing

The spec suite in `spec/` runs the whole load chain headlessly against stubs
([busted](https://lunarmodules.github.io/busted/), Lua 5.1 to match LuaJIT):

```sh
./run_tests.sh
```

Most cases correspond to a bug that actually happened -- missing rule
localization, duplicate registration, the two SMODS lookups a challenge run
performs (`SMODS.Challenges[id]` and `object:calculate(context)`), the
save-completion migration across every historical id scheme, and the Big 2
comparison rules.

A convention worth knowing if you add to them: a new spec is kept only after
confirming it **fails against the unfixed code**. Four bugs in this fork passed
their specs while broken, every time because the stub modelled a narrower world
than the game does.

> [!WARNING]
> Unreleased code may have fatal errors.

## Credits

Mod and challenge design: **OceanRamen (Djynasty)**, Surskitt, Cheerio1101,
ilikecheese, and the many BU-CB challenge designers credited individually in
each file under `Challenges/` — ascriptmaster, BERSERK, CampfireCollective,
DrSpectred, Misty, qcom_, sharktamer, s_millie, theQial, Tuzzo,
UppedHealer8521 and Wingcap.

Big Wee is by **jimmyy**, and is the only challenge here not from upstream.

With thanks to the BU-CB play-testers, including but not limited to
CampfireCollective, DrSpectred, SugarryBoi and Smokesniper.

## Licence

GPL-3.0, as inherited from
[ilikecheese0/BU-CB-DEV](https://github.com/ilikecheese0/BU-CB-DEV).
