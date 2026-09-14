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

The spec suite in `spec/` runs the whole load chain headlessly against stubs
([busted](https://lunarmodules.github.io/busted/), Lua 5.1 to match LuaJIT):

```sh
./run_tests.sh
```

Each case corresponds to a crash that actually happened -- missing rule
localization, duplicate registration, and the two SMODS lookups a challenge run
performs (`SMODS.Challenges[id]` and `object:calculate(context)`) -- plus the
save-completion migration across every historical id scheme.

> [!WARNING]
> Unreleased code may have fatal errors.

## Credits

Mod and challenge design: **OceanRamen (Djynasty)**, Surskitt, Cheerio1101,
ilikecheese, and the many BU-CB challenge designers credited individually in
each file under `Challenges/` — ascriptmaster, BERSERK, CampfireCollective,
DrSpectred, Misty, qcom_, sharktamer, s_millie, theQial, Tuzzo,
UppedHealer8521 and Wingcap.

With thanks to the BU-CB play-testers, including but not limited to
CampfireCollective, DrSpectred, SugarryBoi and Smokesniper.
