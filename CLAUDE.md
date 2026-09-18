# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BU-CB** (Balatro Custom Challenges) is a mod for the game **Balatro** using the **Lovely mod loader**. It adds custom challenge runs with unique rules, restrictions, and mechanics.

## Architecture

- **lovely.toml** - Lovely manifest defining patches that inject code into the base game
- **mod.lua** - Entry point loaded by Lovely, calls `initChallenges()`
- **Challenges.lua** - Core mod logic: loads all challenge files, defines custom modifiers, hooks into game functions
- **Challenges/*.lua** - Individual challenge definitions (20+ challenges)
- **nativefs.lua** - Native filesystem access for Lovely

## Key Files

| File | Purpose |
|------|---------|
| `lovely.toml` | Patch definitions for game injection points |
| `Challenges.lua` | Main mod logic, custom modifiers, game function hooks |
| `mod.lua` | Mod entry point |
| `Challenges/` | Directory of individual challenge definition files |

## Custom Modifiers (defined in Challenges.lua)

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

This is a Lua mod for a Love2D game. There are no build/lint/test commands - the mod is loaded directly by Lovely at runtime. To test changes:

1. Install Lovely mod loader for Balatro
2. Place mod in Balatro's mods folder
3. Launch Balatro

## Git

- Main branch: `master`
- Clean working tree
- Recent changes: challenge fixes, automatic info rule for non-challenge decks

## Code Style

- Lua 5.1 (Love2D/Lovely)
- 2-space indentation
- Challenge files use `return { ... }` pattern
- Modifiers use `id`/`value` pairs in rules tables