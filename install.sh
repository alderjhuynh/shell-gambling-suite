#!/usr/bin/env bash

set -euo pipefail

COMMAND_NAMES=("bj" "sc" "cf" "rps" "sl" "vp" "mi" "shop")
COMMAND_FILES=("blackjack.sh" "scratchers.sh" "coinflip.sh" "rock_paper_scissors.sh" "slots.sh" "video_poker.sh" "miner.sh" "shop.sh")

DIR="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$DIR/games"

PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="${BIN_DIR:-$PREFIX/bin}"
LIB_DIR="${LIB_DIR:-$PREFIX/lib/aura-gambling-suite}"
LIB_GAME_DIR="$LIB_DIR/games"

needs_sudo_for() {
  local path="$1"
  while [[ ! -e "$path" && "$path" != "/" ]]; do
    path="$(dirname "$path")"
  done
  [[ ! -w "$path" ]]
}

run_root() {
  if [[ "${USE_SUDO:-0}" == "1" ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

USE_SUDO=0
if needs_sudo_for "$BIN_DIR" || needs_sudo_for "$LIB_DIR"; then
  USE_SUDO=1
fi

echo "Installing Aura Gambling Suite CLI..."
echo "  Bin dir: $BIN_DIR"
echo "  Lib dir: $LIB_DIR"

run_root install -d "$BIN_DIR" "$LIB_GAME_DIR"
run_root cp "$GAME_DIR"/*.sh "$LIB_GAME_DIR/"
run_root chmod 755 "$LIB_GAME_DIR"/*.sh

for i in "${!COMMAND_NAMES[@]}"; do
  cmd="${COMMAND_NAMES[$i]}"
  script="${COMMAND_FILES[$i]}"
  wrapper_path="$BIN_DIR/$cmd"
  target_script="$LIB_GAME_DIR/$script"

  if [[ ! -f "$target_script" ]]; then
    echo "Skipping $cmd (missing $script)"
    continue
  fi

  tmp_wrapper="$(mktemp)"
  printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$target_script" > "$tmp_wrapper"
  chmod 755 "$tmp_wrapper"
  run_root mv "$tmp_wrapper" "$wrapper_path"

  echo "Installed $cmd -> $target_script"
done

echo "Done. Available commands:"
for cmd in "${COMMAND_NAMES[@]}"; do
  echo "  $cmd"
done
