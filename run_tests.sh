#!/usr/bin/env bash
# Run the spec suite. Balatro is LuaJIT/5.1, so the specs run on lua5.1.
set -euo pipefail
cd "$(dirname "$0")"
exec nix shell nixpkgs#lua51Packages.busted --command busted "$@"
