#!/usr/bin/env bash

set -euo pipefail

COMMAND_NAMES=("bj bash" "sc bash" "cf bash" "rps bash" "sl bash" "vp bash")
COMMAND_FILES=("blackjack.sh" "scratchers.sh" "coinflip.sh" "rock_paper_scissors.sh" "slots.sh" "video_poker.sh")

TARGET_DIR="/usr/local/bin"
DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$DIR/games"

echo "Uninstalling Aura Gambling Suite CLI..."

for i in "${!COMMAND_NAMES[@]}"; do
  cmd="${COMMAND_NAMES[$i]}"
  script="${COMMAND_FILES[$i]}"
  target_path="$TARGET_DIR/$cmd"
  source_path="$GAME_DIR/$script"

  if [ ! -f "$source_path" ]; then
    echo "Skipping $cmd (missing $script)"
    continue
  fi

    if cmp -s "$source_path" "$target_path"; then
        sudo rm "$target_path"
        echo "Removed $cmd"
    else
        echo "WARNING: $cmd exists but differs from expected file. Skipping."
    fi
done

echo "Uninstall complete."