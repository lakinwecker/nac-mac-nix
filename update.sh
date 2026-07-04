#!/usr/bin/env bash
# Update this machine (or a named host): refresh flake.lock, then switch.
# Thin wrapper around build.sh --update --switch.
#
# Usage:
#   ./update.sh            # update inputs, switch the current machine
#   ./update.sh gratch     # update inputs, switch gratch
#
# Remember to commit the resulting flake.lock change.
set -euo pipefail
cd "$(dirname "$0")"
exec ./build.sh --update --switch "$@"
