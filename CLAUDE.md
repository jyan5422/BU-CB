# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BU-CB** (Balatro Custom Challenges) is a mod for the game **Balatro**. It adds
custom challenge runs with unique rules, restrictions, and mechanics.

It is a **Steamodded** mod that also ships **Lovely** patches. Steamodded loads
`ChallengeMod.lua`; Lovely applies the `lovely/*.toml` patches for the handful
of places a Lua hook cannot reach (locals inside `evaluate_play`, UI table
literals). Both are required.

**Read [docs/modding-notes.md](docs/modding-notes.md) before changing anything.**
It records the game internals and testing traps that have each already caused a
wrong fix -- packaging, `current_round` mutation, scoring passes, sort bands,
DynaText caching, and the ways specs pass while the game is broken.

## Architecture

- **ChallengeMod.json** - Steamodded manifest
- **ChallengeMod.lua** - Entry point; loads everything in a fixed order
- **challenge_handler.lua** / **Daily/daily_handler.lua** - Append challenge
  `DATA` tables to `G.CHALLENGES`
- **mechanics.lua** / **Daily/daily_mechanics.lua** - Modifier localization
  (`ch_c_*`) and the `evaluate_rules` branches that apply them
- **core.lua**, **smods/core_shared.lua** - Shared helpers
- **smods/rules_*.lua** - One file per reusable rule, exposed on `ChallengeMod`
  so a joker or another challenge can take one piece
- **smods/register.lua** - Publishes into `SMODS.Challenges` **without** calling
  `SMODS.Challenge()`; see the file for why
- **smods/migrate_progress.lua** - Copies completions across renamed ids
- **lovely/*.toml** - Source patches
- **spec/** - busted specs, run by `./run_tests.sh`

## Key Files

| File | Purpose |
|------|---------|
| `ChallengeMod.lua` | Entry point and load order |
| `mechanics.lua` | Modifier localization and `evaluate_rules` |
| `Challenges/` | One file per challenge (37) |
| `smods/rules_*.lua` | Reusable rule implementations |
| `lovely/` | Source patches (25) |
| `docs/modding-notes.md` | Game internals and testing traps |
| `docs/big-wee-design.md` | Worked example of a multi-rule challenge |

## Custom Modifiers (localized in mechanics.lua, applied in `evaluate_rules`)

- `cm_force_hand` - Only specific hand type scores
- `cm_force_hand_contains` - Played hands must contain specific hand type
- `cm_negative_interest` - Lose money from interest on blind defeat
- `cm_no_overscoring` - Blind score must not exceed X%
- `cm_noshop` - Skip shop, go straight to blind select
- `cm_scaling` - Custom ante/blind scaling formula
- `cm_stake` - Force specific stake level
- `all_perishable` - All jokers become perishable
- `all_rental` - All jokers become rental
- `no_shop_planets` / `no_shop_tarots` - Remove planets/tarots from shop
- `cm_all_facedown` - All cards face down except hand
- `cm_mult_dollar_cap` - Mult capped at current dollars
- `cm_hand_kills` - Lose if played hand contains specific type
- `cm_deck` - Display deck type in challenge rules
- `cm_credit` - Credit attribution in challenge rules

## Challenge Definition Format

Each challenge in `Challenges/` returns a table with:
- `name`, `id` - Display name and unique ID
- `rules.modifiers` - Base game modifiers (dollars, hands, discards, etc.)
- `rules.custom` - Custom modifier IDs from above list
- `jokers` / `consumeables` / `vouchers` - Starting items
- `deck` - Deck configuration (type, specific cards)
- `restrictions.banned_cards/tags/other` - Banned items

## Development Commands

```sh
./run_tests.sh          # busted specs (Lua 5.1)
balatro-run <dir>       # launch the real game against a staged copy of the mod
./push_to_phone.sh      # build a FLAT zip and taildrop it to the phone
```

Verify in that order, then on device. A failed Lovely patch is only a `WARN` in
the log, so always grep the log for your own `no matches` and confirm the
payload landed in `~/.local/share/love/Mods/lovely/dump/`. See
`docs/modding-notes.md`.

## Git

- Main branch: `dev-main`
- `origin` is the personal fork (`jyan5422/BU-CB`); `bucbdev` and `oceanramen`
  are upstreams. This fork is a collection of BU ideas from several forks.

## Code Style

- Lua 5.1 (Love2D/LuaJIT)
- 2-space indentation
- Challenge files set `Challenge.NAME`/`DATA` and end with `return Challenge`
  (a missing `return` loads silently and the challenge just never appears)
- Modifiers use `id`/`value` pairs in rules tables
- A modifier needs **both** an `evaluate_rules` branch and a `ch_c_<id>`
  localization string; a missing string is what breaks the rule
- Express a modifier's value as a **bonus or penalty**, not an absolute, so it
  composes with whatever the deck already grants