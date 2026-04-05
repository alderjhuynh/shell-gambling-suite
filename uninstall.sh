#!/usr/bin/env bash

set -euo pipefail

COMMAND_NAMES=("bj" "sc" "cf" "rps" "sl" "vp" "mi" "shop")

PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="${BIN_DIR:-$PREFIX/bin}"
LIB_DIR="${LIB_DIR:-$PREFIX/lib/aura-gambling-suite}"

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

echo "Uninstalling Aura Gambling Suite CLI..."
echo "  Bin dir: $BIN_DIR"
echo "  Lib dir: $LIB_DIR"

for cmd in "${COMMAND_NAMES[@]}"; do
  target_path="$BIN_DIR/$cmd"
  if [[ -e "$target_path" ]]; then
    run_root rm -f "$target_path"
    echo "Removed $cmd"
  else
    echo "Skipping $cmd (not installed)"
  fi
done

if [[ -d "$LIB_DIR" ]]; then
  run_root rm -rf "$LIB_DIR"
  echo "Removed $LIB_DIR"
fi

echo "Uninstall complete."
