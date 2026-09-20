#!/usr/bin/env bash
# Rebuild the SMODS zip and Taildrop it to a device.
#
# Usage: ./taildrop.sh [host]
#   host  Tailscale device name, with or without a trailing colon.
#         Defaults to the phone.
set -euo pipefail

DEFAULT_HOST=jamess-galaxy-note10
HOST="${1:-$DEFAULT_HOST}"
# Accept "host" or "host:" -- tailscale wants the colon, and typing it is easy
# to forget when the name is passed by hand.
HOST="${HOST%:}"

REPO=/home/yanjh/BU-CB

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

cd "$REPO"
rm -f BU-CB.zip
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -r Assets Challenges Daily lovely smods \
  ChallengeMod.json ChallengeMod.lua \
  challenge_handler.lua core.lua mechanics.lua nativefs.lua \
  saved_scores.lua tags.lua "$STAGE"/
rm -f "$STAGE/smods/gen_core_shared.sh"
cd "$STAGE" && zip -rq "$REPO/BU-CB.zip" .

echo "Sending to $HOST ..."
# Taildrop blocks until the device accepts, so this can sit for a while on a
# device that is asleep, and fails outright on one that has never been online.
sudo tailscale file cp --name "BU-CB-$(date +%Y%m%d-%H%M).zip" \
  "$REPO/BU-CB.zip" "$HOST:"
echo "Done"
