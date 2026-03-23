#!/usr/bin/env bash
set -euo pipefail

configs=("surface" "laptop" "desktop")

for cfg in "${configs[@]}"; do
  echo "Building ${cfg}-iso..."
  nix build ".#nixosConfigurations.${cfg}-iso.config.system.build.isoImage" -o "result-${cfg}"
  echo "Done: result-${cfg}"
done
