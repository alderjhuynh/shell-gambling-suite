# Aura Gambling Suite CLI

Essentially this is a collection of command line based gambling games, written entirely in shell for your convenience.

## Platform support

It works on macOS and most Linux environments

Unix-like installs assume:

- You exist.

## What gets installed

`install.sh` copies the game scripts from `games/` and gives them short command names:

- `bj` -> `blackjack.py`
- `cf` -> `coinflip.py`
- `rps` -> `rock_paper_scissors.py`
- `sc` -> `scratchers.py`
- `sl` -> `slots.py`
- `vp` -> `video_poker.py`

Feel free to change the names of the commands within `install.sh`

## Install

From the project directory:

```bash
chmod +x install.sh && bash install.sh
```

The installer will:

1. install the game entry points with the short commands
2. copy the game files those commands need
3. add the install location to your `PATH`

It will prompt for `sudo`.

After install, run the games directly from your terminal with the short commands above.

## Run without installing

You can also run any game directly with bash, but that kinda defeats the whole purpose:

```bash
bash games/blackjack.sh
bash games/coinflip.sh
bash games/rock_paper_scissors.sh
bash games/scratchers.sh
bash games/slots.sh
bash games/video_poker.sh
```

## Games

- `games/blackjack.sh`: single-player blackjack against the dealer with hit/stand play and blackjack payout handling
- `games/coinflip.sh`: double-or-nothing coin flip game where you can keep doubling or cash out
- `games/rock_paper_scissors.sh`: rock-paper-scissors against a simple move-predicting AI
- `games/scratchers.sh`: scratch-off ticket game with three ticket types and different payout tables
- `games/slots.sh`: 3-reel slot machine with symbol-based payouts
- `games/video_poker.sh`: draw poker with hold toggles, a pay table, and hand detail screens (since I kept forgetting the hands)

## Shared credits/save data

All games use the same save file:

```text
~/aura_gambling_suite_bash.txt
```

That file stores your shared credits and the passive credit timer, so your balance carries across all games.

Each game starts with 100 credits if no save file exists yet.

You can manually edit the credit amounts as I didn't hide the file, but also, like that ruins the reason you're playing the game.

## Notes

- Passive credits are awarded over time and are shared across the whole suite.
- Most games are designed for interactive terminal use, not for piping or non-interactive shells.
- I will NOT be porting this to batch because I hate batch and also if you're on windows just get linux
