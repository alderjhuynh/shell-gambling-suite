#!/usr/bin/env bash

set -e

COMMAND_NAMES=("bj bash" "sc bash" "cf bash" "rps bash" "sl bash" "vp bash")
COMMAND_FILES=("blackjack.sh" "scratchers.sh" "coinflip.sh" "rock_paper_scissors.sh" "slots.sh" "video_poker.sh")

TARGET_DIR="/usr/local/bin"
DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$DIR/games"

echo "Installing Aura Gambling Suite CLI..."

for i in "${!COMMAND_NAMES[@]}"; do
  cmd="${COMMAND_NAMES[$i]}"
  script="${COMMAND_FILES[$i]}"
  source_path="$GAME_DIR/$script"
  target_path="$TARGET_DIR/$cmd"

  if [ ! -f "$source_path" ]; then
    echo "Skipping $cmd (missing $script)"
    continue
  fi

  chmod +x "$source_path"
  sudo cp "$source_path" "$target_path"

  echo "Installed $cmd for $script"
done

echo "Done. Available commands:"
for cmd in "${COMMAND_NAMES[@]}"; do
  echo "  $cmd"
done
