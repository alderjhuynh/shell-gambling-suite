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
- `rps` -> rock paper scissors
- `sc` -> scratchers
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

1. copies each shell game into `/usr/local/bin`
2. renames them to the short commands listed above
3. prompts for `sudo` during the copy step

Because the install target is `/usr/local/bin`, no extra `PATH` changes are usually needed.

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
bash games/rock_paper_scissors.sh
bash games/scratchers.sh
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
- `games/rock_paper_scissors.sh`: rock-paper-scissors against a simple move-predicting AI
- `games/scratchers.sh`: scratch-off ticket game with three ticket types and different payout tables
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

## Notes

- Passive credits are shared across all games on the same platform install.
- Most games are designed for interactive terminal use, not for piping or non-interactive shells.
- On Windows, the game launchers call PowerShell with `-ExecutionPolicy Bypass` from the local launcher scripts.
