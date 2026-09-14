#!/usr/bin/env bash
# Regenerate smods/core_shared.lua from core.lua after pulling upstream.
# Drops only the Lovely-only prologue: the ChallengeMod table init and the
# nativefs initChallenges() bootstrap, which ChallengeMod.lua owns instead.
# Everything from the RELEASE/VERSION assignments down is kept verbatim.
set -euo pipefail
cd "$(dirname "$0")/.."
start=$(grep -n '^ChallengeMod\.RELEASE' core.lua | head -1 | cut -d: -f1)
[ -n "$start" ] || { echo "core.lua: ChallengeMod.RELEASE not found" >&2; exit 1; }
{
  echo "-- GENERATED from core.lua by smods/gen_core_shared.sh -- do not edit."
  echo "-- Upstream's ChallengeMod table init and nativefs initChallenges() are"
  echo "-- dropped; ChallengeMod.lua owns both under SMODS."
  tail -n +"$start" core.lua
} > smods/core_shared.lua
