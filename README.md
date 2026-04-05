# Aura Gambling Suite CLI

A small collection of terminal gambling games with shared credits across the whole suite.

## Platform Support

- macOS: supported via the shell scripts in `games/`
- Linux: supported via the shell scripts in `games/`
- Windows: supported via the launchers and PowerShell implementation in `windows_support/`

## Commands

After installation, these commands are available:

macOS / Linux:

- `bj` -> blackjack
- `cf` -> coinflip
- `mi` -> miner
- `rps` -> rock paper scissors
- `sc` -> scratchers
- `shop` -> shop
- `sl` -> slots
- `vp` -> video poker

Windows:

- `bj` -> blackjack
- `cf` -> coinflip
- `rps` -> rock paper scissors
- `scr` -> scratchers
- `slt` -> slots
- `vp` -> video poker

## Install

### macOS / Linux

From the project directory:

```bash
chmod +x install.sh
bash install.sh
```

`install.sh`:

1. copies the Unix shell scripts into `/usr/local/lib/aura-gambling-suite/games`
2. creates short wrapper commands in `/usr/local/bin`
3. prompts for `sudo` only when the target prefix is not writable

Because the install target is `/usr/local/bin`, no extra `PATH` changes are usually needed.

For local testing without `sudo`, you can install into a custom prefix:

```bash
PREFIX="$HOME/.local" bash install.sh
```

### Windows

From File Explorer or `cmd.exe`, run:

```bat
windows_install.bat
```

`windows_install.bat`:

1. installs files into `%LOCALAPPDATA%\AuraGamblingSuite`
2. copies command launchers into `%LOCALAPPDATA%\AuraGamblingSuite\bin`
3. copies the Windows game files into `%LOCALAPPDATA%\AuraGamblingSuite\games`
4. adds `%LOCALAPPDATA%\AuraGamblingSuite\bin` to your user `PATH`

The Windows version uses `cmd` launchers that call PowerShell under the hood. Restart your terminal after installing so the new commands are available.

## Uninstall

### macOS / Linux

```bash
chmod +x uninstall.sh
bash uninstall.sh
```

This removes the installed short commands from `/usr/local/bin`.
It also removes the Unix library directory at `/usr/local/lib/aura-gambling-suite`.

### Windows

```bat
windows_uninstall.bat
```

This removes `%LOCALAPPDATA%\AuraGamblingSuite` and removes its `bin` directory from your user `PATH`.

## Run Without Installing

### macOS / Linux

```bash
bash games/blackjack.sh
bash games/coinflip.sh
bash games/miner.sh
bash games/rock_paper_scissors.sh
bash games/scratchers.sh
bash games/shop.sh
bash games/slots.sh
bash games/video_poker.sh
```

### Windows

```bat
windows_support\games\blackjack.bat
windows_support\games\coinflip.bat
windows_support\games\rock_paper_scissors.bat
windows_support\games\scratchers.bat
windows_support\games\slots.bat
windows_support\games\video_poker.bat
```

## Games

- `games/blackjack.sh`: single-player blackjack against the dealer with hit/stand play and blackjack payout handling
- `games/coinflip.sh`: double-or-nothing coin flip game where you can keep doubling or cash out
- `games/miner.sh`: ore miner that converts mined ore into quarter-credit chunks
- `games/rock_paper_scissors.sh`: rock-paper-scissors against a simple move-predicting AI
- `games/scratchers.sh`: scratch-off ticket game with three ticket types and different payout tables
- `games/shop.sh`: shared item shop for loot crates, one-time-use buffs, and max bet upgrades
- `games/slots.sh`: 3-reel slot machine with symbol-based payouts
- `games/video_poker.sh`: draw poker with hold toggles, a pay table, and hand detail screens

## Shared Credits / Save Data

Each platform keeps one shared save file for all games on that platform.

macOS / Linux:

```text
~/aura_gambling_suite_bash.txt
```

Windows:

```text
%LOCALAPPDATA%\AuraGamblingSuite\state.json
```

If no save file exists yet, the suite starts with 100 credits.

The save data stores:

- current credits
- passive credits already earned toward the current cap
- the next passive credit timestamp
- one-time-use shop items: `2x Win`, `Lucky`, and `Shield`
- Unix miner state such as ore progress and mine cooldown

## Notes

- Passive credits are shared across all games on the same platform install.
- On macOS/Linux, `2x Win`, `Lucky`, and `Shield` are single-use shop items and are consumed by the next qualifying game action.
- Most games are designed for interactive terminal use, not for piping or non-interactive shells.
- On Windows, the game launchers call PowerShell with `-ExecutionPolicy Bypass` from the local launcher scripts.
