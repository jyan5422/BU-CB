#!/usr/bin/env bash
# Rebuild zip and push to phone (SMODS build).
set -euo pipefail

# The zip's entries are flat -- lovely/, smods/, ChallengeMod.json and the rest
# sit at the top with no wrapping folder.
#
# This matters because SMODS and Lovely disagree about depth. SMODS finds a mod
# by scanning recursively for ChallengeMod.json, so the Lua half works at any
# nesting. Lovely only reads patches from Mods/<dir>/lovely/, one level down.
# Shipping a wrapper folder meant unzipping produced
# Mods/<zipname>/ChallengeMod/lovely/, two levels deep, where Lovely never
# looked -- so every patch silently did nothing while the Lua ran fine.
#
# Flat entries let the user unzip into a folder they name, which is one level
# whatever the file manager calls it.
STAGE=/tmp/bucb-stage

cd /home/yanjh/BU-CB
rm -f BU-CB.zip
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -r Assets Challenges Daily lovely smods \
  ChallengeMod.json ChallengeMod.lua \
  challenge_handler.lua core.lua mechanics.lua nativefs.lua \
  saved_scores.lua tags.lua "$STAGE"/
rm -f "$STAGE/smods/gen_core_shared.sh"
cd "$STAGE" && zip -rq /home/yanjh/BU-CB/BU-CB.zip .
sudo tailscale file cp --name "BU-CB-$(date +%Y%m%d-%H%M).zip" /home/yanjh/BU-CB/BU-CB.zip jamess-galaxy-note10:
echo "Done"
