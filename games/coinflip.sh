#!/usr/bin/env bash

SAVEFILE="$HOME/aura_gambling_suite_bash.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PASSIVE_CREDIT_AMOUNT=10
PASSIVE_CREDIT_INTERVAL=300
PASSIVE_CREDIT_CAP=100

RESET=$'\033[0m'
BOLD=$'\033[1m'
YELLOW=$'\033[93m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
RED=$'\033[91m'
WHITE=$'\033[97m'
MAGENTA=$'\033[95m'
DIM=$'\033[2m'

HEADS_LINES=(
    "            ########"
    "          ##........##"
    "        ##....  ......##"
    "        ##..  HHHH....##"
    "        ##..  HHHH....##"
    "        ##  ..........##"
    "          ##........##"
    "            ########"
)

TAILS_LINES=(
    "            ########"
    "          ##........##"
    "        ##....  ......##"
    "        ##..  TTTT....##"
    "        ##..  TTTT....##"
    "        ##  ..........##"
    "          ##........##"
    "            ########"
)
SPIN_LINES=(
    "            ########"
    "          ##........##"
    "        ##....  ......##"
    "        ##..  ????....##"
    "        ##..  ????....##"
    "        ##  ..........##"
    "          ##........##"
    "            ########"
)

fmt_time() {
    local total=$1
    (( total < 0 )) && total=0
    printf '%dm %02ds' $(( total / 60 )) $(( total % 60 ))
}

draw_coin_lines() {
    local name="$1"
    local i
    for (( i=0; i<8; i++ )); do
        case "$name" in
            heads) printf '        %s\n' "${HEADS_LINES[$i]}" ;;
            tails) printf '        %s\n' "${TAILS_LINES[$i]}" ;;
            *)     printf '        %s\n' "${SPIN_LINES[$i]}" ;;
        esac
    done
}

draw_coin() {
    local frame="$1" title="$2" credits="$3" bet="$4" streak="$5" message="$6"
    local now ttl
    now=$(date +%s)
    ttl=$(( NEXT_CREDIT_TIME - now ))
    (( ttl < 0 )) && ttl=0

    clear
    printf '%s%s\n' "$YELLOW" "$BOLD"
    echo "  ╔═════════════════════════╗"
    echo "  ║    DOUBLE OR NOTHING    ║"
    echo "  ║   Aura Gambling Suite   ║"
    echo "  ╚═════════════════════════╝"
    printf '%s\n\n' "$RESET"

    printf '  %sCredits: %s%d%s   %sBet: %s%d%s   %sStreak: %s%dx%s   %s+%d in %s%s\n' \
        "$YELLOW" "$BOLD" "$credits" "$RESET" \
        "$CYAN" "$BOLD" "$bet" "$RESET" \
        "$MAGENTA" "$BOLD" "$streak" "$RESET" \
        "$DIM" "$PASSIVE_CREDIT_AMOUNT" "$(fmt_time "$ttl")" "$RESET"
    printf '  %sItems: %s 2x:%s Lucky: %s Shield: %s\n\n' \
        "$DIM" "$RESET" \
        "$( (( ITEM_2X_WIN )) && printf 'ON' || printf 'off' )" \
        "$( (( ITEM_LUCKY )) && printf 'ON' || printf 'off' )" \
        "$( (( ITEM_SHIELD )) && printf 'ON' || printf 'off' )"

    printf '        %s%s%s\n\n' "$CYAN" "$BOLD" "$title$RESET"
    draw_coin_lines "$frame"
    echo
    [[ -n "$message" ]] && printf '  %s\n' "$message"
    echo
}

animate_flip() {
    local credits="$1" bet="$2" streak="$3"
    local i
    for (( i=0; i<6; i++ )); do
        draw_coin "spin" "Flipping..." "$credits" "$bet" "$streak" ""
        sleep 0.12
    done
}

flip_coin() {
    local credits="$1" bet="$2" streak="$3" lucky_active="${4:-0}"
    animate_flip "$credits" "$bet" "$streak"
    if (( lucky_active )) && (( RANDOM % 100 < 70 )); then
        FLIP_RESULT="H"
    elif (( RANDOM % 2 == 0 )); then
        FLIP_RESULT="H"
    else
        FLIP_RESULT="T"
    fi
}

play_round() {
    local bet="$1" credits="$2"
    local streak=1
    local pot=$bet
    local lucky_roll=0
    local lucky_note=""

    if consume_lucky; then
        lucky_roll=1
        lucky_note="${GREEN}Lucky loaded the first flip in your favor.${RESET}"
    fi

    while true; do
        flip_coin "$credits" "$bet" "$streak" "$lucky_roll"
        lucky_roll=0

        if [[ "$FLIP_RESULT" == "H" ]]; then
            pot=$(( pot * 2 ))
            streak=$(( streak * 2 ))
            draw_coin "heads" "HEADS!" "$credits" "$bet" "$streak" \
                "${GREEN}${BOLD}WIN - Pot now ${pot}${RESET}${lucky_note:+  ${lucky_note}}"
        else
            draw_coin "tails" "TAILS!" "$credits" "$bet" "$streak" \
                "${RED}${BOLD}LOSE - You lost ${bet}${RESET}${lucky_note:+  ${lucky_note}}"
            sleep 1.5
            ROUND_PAYOUT=0
            return
        fi
        lucky_note=""

        sleep 1.2
        draw_coin "heads" "Continue?" "$credits" "$bet" "$streak" \
            "${WHITE}[ENTER] Double again  [c] Cash out${RESET}"
        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')
        if [[ "$choice" == "c" ]]; then
            ROUND_PAYOUT=$pot
            return
        fi
    done
}

main() {
    load_state
    PENDING_BONUS=0
    BET=10

    while true; do
        check_passive_credits
        clamp_bet_to_limit 500 10

        if (( PENDING_BONUS > 0 )); then
            printf '\n  %s%s+%d FREE CREDITS!%s\n\n' \
                "$CYAN" "$BOLD" "$PENDING_BONUS" "$RESET"
            PENDING_BONUS=0
            sleep 1
        fi

        local now ttl
        now=$(date +%s)
        ttl=$(( NEXT_CREDIT_TIME - now ))
        (( ttl < 0 )) && ttl=0

        local max_bet
        max_bet=$(current_max_bet_limit 500)

        printf '  %sCredits: %s%d%s   %sBet: %s%d%s   %sMax: %s%d%s   %s+%d in %s%s\n' \
            "$YELLOW" "$BOLD" "$CREDITS" "$RESET" \
            "$CYAN" "$BOLD" "$BET" "$RESET" \
            "$WHITE" "$BOLD" "$max_bet" "$RESET" \
            "$DIM" "$PASSIVE_CREDIT_AMOUNT" "$(fmt_time "$ttl")" "$RESET"

        if (( CREDITS <= 0 )); then
            printf '\n  %s%sOUT OF CREDITS%s\n\n' "$RED" "$BOLD" "$RESET"
            read -r -p "  [ENTER] to check again, [q] to quit: " choice
            choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')
            [[ "$choice" == "q" ]] && break
            continue
        fi

        printf '  %s[ENTER] Flip  [b] Bet(%d)  [q] Quit%s\n' "$WHITE" "$BET" "$RESET"
        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        check_passive_credits
        if (( PENDING_BONUS > 0 )); then
            printf '\n  %s%s+%d FREE CREDITS!%s\n\n' \
                "$CYAN" "$BOLD" "$PENDING_BONUS" "$RESET"
            PENDING_BONUS=0
        fi

        case "$choice" in
            q)
                save_state
                break
                ;;
            b)
                max_bet=$(current_max_bet_limit 500)
                (( max_bet < 10 )) && max_bet=10
                read -r -p "  ENTER BET (10-${max_bet}): " new_bet
                if [[ "$new_bet" =~ ^[0-9]+$ ]]; then
                    (( new_bet < 10 )) && new_bet=10
                    (( new_bet > max_bet )) && new_bet=$max_bet
                    BET=$new_bet
                fi
                echo
                continue
                ;;
        esac

        if (( BET > CREDITS )); then
            printf '  %sNOT ENOUGH CREDITS%s\n\n' "$RED" "$RESET"
            continue
        fi

        CREDITS=$(( CREDITS - BET ))
        PASSIVE_EARNED=0
        save_state

        ROUND_PAYOUT=0
        play_round "$BET" "$CREDITS"
        apply_payout_items "$BET" "$ROUND_PAYOUT"
        CREDITS=$(( CREDITS + FINAL_PAYOUT ))
        save_state

        if (( ITEM_USED_2X )); then
            printf '\n  %s2x Win doubled your cash-out payout.%s\n' "$CYAN" "$RESET"
        elif (( ITEM_USED_SHIELD )); then
            printf '\n  %sShield blocked %d credits on that loss.%s\n' "$YELLOW" "$ITEM_SHIELD_BLOCKED" "$RESET"
        fi

        sleep 1
        clear
    done

    printf '\n  %sFINAL CREDITS: %s%d%s\n\n' "$CYAN" "$BOLD" "$CREDITS" "$RESET"
}

main "$@"
