#!/usr/bin/env bash
# Rebuild zip and push to phone (SMODS build).
set -euo pipefail

# SMODS keys the mod off ChallengeMod.json / main_file, so the folder name is
# free; ChallengeMod matches the id and what the previous builds installed.
STAGE=/tmp/ChallengeMod

cd /home/yanjh/BU-CB
rm -f BU-CB.zip
rm -rf "$STAGE"
mkdir -p "$STAGE"
# lovely/ ships too: the per-mechanic patches are still Lovely patches, only
# the init-level ones from challenge_init.toml moved into smods/hooks.lua.
cp -r Assets Challenges Daily lovely smods \
  ChallengeMod.json ChallengeMod.lua \
  challenge_handler.lua core.lua mechanics.lua nativefs.lua \
  saved_scores.lua tags.lua "$STAGE"/
rm -f "$STAGE/smods/load_test.lua" "$STAGE/smods/gen_core_shared.sh"
cd /tmp && zip -rq /home/yanjh/BU-CB/BU-CB.zip ChallengeMod/
sudo tailscale file cp --name "BU-CB-$(date +%Y%m%d-%H%M).zip" /home/yanjh/BU-CB/BU-CB.zip jamess-galaxy-note10:
echo "Done"
