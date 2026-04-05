#!/usr/bin/env bash

SAVEFILE="$HOME/aura_gambling_suite_bash.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PASSIVE_CREDIT_AMOUNT=10
PASSIVE_CREDIT_INTERVAL=300
PASSIVE_CREDIT_CAP=100

SYMBOLS=("CH" "LM" "OR" "GR" "ST" "DM" "77")

RESET=$'\033[0m'
BOLD=$'\033[1m'
YELLOW=$'\033[93m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
RED=$'\033[91m'
WHITE=$'\033[97m'
MAGENTA=$'\033[95m'
DIM=$'\033[2m'

BORDER_TOP="╔══════════════════════╗"
BORDER_MID="╠══════════════════════╣"
BORDER_BOT="╚══════════════════════╝"
REEL_DIVIDER="║"

fmt_time() {
    local total=$1
    (( total < 0 )) && total=0
    printf '%dm %02ds' $(( total / 60 )) $(( total % 60 ))
}

symbol_color() {
    case "$1" in
        DM) echo "$MAGENTA" ;;
        ST|77) echo "$YELLOW" ;;
        *) echo "$WHITE" ;;
    esac
}

draw_machine() {
    local locked_0="$1" locked_1="$2" locked_2="$3"
    printf '%s%s%s%s\n' "$YELLOW" "$BOLD" "$BORDER_TOP" "$RESET"
    printf '%s%s║     SLOT  MACHINE   ║%s\n' "$YELLOW" "$BOLD" "$RESET"
    printf '%s%s%s%s\n' "$YELLOW" "$BOLD" "$BORDER_MID" "$RESET"

    printf '%s%s%s%s' "$YELLOW" "$BOLD" "$REEL_DIVIDER" "$RESET"
    local i locked flag color sym
    for i in 0 1 2; do
        eval "flag=\$locked_${i}"
        eval "sym=\${REELS[$i]}"
        color=$(symbol_color "$sym")
        [[ "$flag" == "1" ]] && color="$GREEN"
        printf '  %s%s%-2s%s  ' "$color" "$BOLD" "$sym" "$RESET"
    done
    printf '%s%s%s%s\n' "$YELLOW" "$BOLD" "$REEL_DIVIDER" "$RESET"
    printf '%s%s%s%s\n' "$YELLOW" "$BOLD" "$BORDER_BOT" "$RESET"
}

spin_reels() {
    RESULT_REELS[0]="${ROLLED_REELS[0]}"
    RESULT_REELS[1]="${ROLLED_REELS[1]}"
    RESULT_REELS[2]="${ROLLED_REELS[2]}"

    REELS[0]="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
    REELS[1]="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
    REELS[2]="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"

    clear
    printf '%s%s\n' "$CYAN" "$BOLD"
    echo "  ╔════════════════════════════╗"
    echo "  ║   Slot Machine Typeshit    ║"
    echo "  ╚════════════════════════════╝"
    printf '%s\n\n' "$RESET"

    local step
    for step in 0 1 2 3 4 5 6 7 8; do
        if (( step >= 3 )); then REELS[0]="${RESULT_REELS[0]}"; else REELS[0]="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"; fi
        if (( step >= 5 )); then REELS[1]="${RESULT_REELS[1]}"; else REELS[1]="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"; fi
        if (( step >= 7 )); then REELS[2]="${RESULT_REELS[2]}"; else REELS[2]="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"; fi
        draw_machine $(( step >= 3 ? 1 : 0 )) $(( step >= 5 ? 1 : 0 )) $(( step >= 7 ? 1 : 0 ))
        sleep 0.08
        (( step < 8 )) && printf '\033[5A'
    done
    echo
}

evaluate_reels() {
    local a="$1" b="$2" c="$3"
    EVAL_LABEL=""
    EVAL_PAYOUT=0
    if [[ "$a" == "DM" && "$b" == "DM" && "$c" == "DM" ]]; then
        EVAL_LABEL="DIAMOND JACKPOT"; EVAL_PAYOUT=$(( BET * 100 ))
    elif [[ "$a" == "ST" && "$b" == "ST" && "$c" == "ST" ]]; then
        EVAL_LABEL="STAR JACKPOT"; EVAL_PAYOUT=$(( BET * 50 ))
    elif [[ "$a" == "77" && "$b" == "77" && "$c" == "77" ]]; then
        EVAL_LABEL="LUCKY SEVENS"; EVAL_PAYOUT=$(( BET * 40 ))
    elif [[ "$a" == "CH" && "$b" == "CH" && "$c" == "CH" ]]; then
        EVAL_LABEL="CHERRY BONUS"; EVAL_PAYOUT=$(( BET * 20 ))
    elif [[ "$a" == "GR" && "$b" == "GR" && "$c" == "GR" ]]; then
        EVAL_LABEL="GRAPE BONUS"; EVAL_PAYOUT=$(( BET * 15 ))
    elif [[ "$a" == "OR" && "$b" == "OR" && "$c" == "OR" ]]; then
        EVAL_LABEL="ORANGE BONUS"; EVAL_PAYOUT=$(( BET * 12 ))
    elif [[ "$a" == "LM" && "$b" == "LM" && "$c" == "LM" ]]; then
        EVAL_LABEL="LEMON BONUS"; EVAL_PAYOUT=$(( BET * 10 ))
    elif [[ "$a" == "$b" || "$a" == "$c" || "$b" == "$c" ]]; then
        EVAL_LABEL="TWO OF A KIND"; EVAL_PAYOUT=$BET
    fi
}

prepare_spin() {
    local lucky_active=0
    LUCKY_NOTE=""
    if consume_lucky; then
        lucky_active=1
        LUCKY_NOTE="Lucky gave you the better of two spins."
    fi

    local candidate_a candidate_b score_a score_b
    candidate_a=(
        "${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
        "${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
        "${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
    )
    evaluate_reels "${candidate_a[0]}" "${candidate_a[1]}" "${candidate_a[2]}"
    score_a=$EVAL_PAYOUT

    ROLLED_REELS=("${candidate_a[@]}")
    if (( lucky_active == 0 )); then
        return
    fi

    candidate_b=(
        "${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
        "${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
        "${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
    )
    evaluate_reels "${candidate_b[0]}" "${candidate_b[1]}" "${candidate_b[2]}"
    score_b=$EVAL_PAYOUT

    if (( score_b > score_a )); then
        ROLLED_REELS=("${candidate_b[@]}")
    fi
}

jackpot_flash() {
    local msg="$1"
    local color
    for color in "$YELLOW" "$CYAN" "$MAGENTA" "$RED" "$GREEN" "$YELLOW"; do
        printf '\r  %s%s*  %s  *%s   ' "$color" "$BOLD" "$msg" "$RESET"
        sleep 0.07
    done
    echo
}

main() {
    load_state
    PENDING_BONUS=0
    BET=10
    RESULT_REELS=("" "" "")
    REELS=("" "" "")

    clear
    printf '%s%s\n' "$CYAN" "$BOLD"
    echo "  ╔════════════════════════════╗"
    echo "  ║   Slot Machine Typeshit    ║"
    echo "  ╚════════════════════════════╝"
    printf '%s\n' "$RESET"

    while true; do
        check_passive_credits
        clamp_bet_to_limit 100 10

        if (( PENDING_BONUS > 0 )); then
            printf '\n  %s%s +%d FREE CREDITS! %s\n\n' "$CYAN" "$BOLD" "$PENDING_BONUS" "$RESET"
            PENDING_BONUS=0
        fi

        local now ttl
        now=$(date +%s)
        ttl=$(( NEXT_CREDIT_TIME - now ))
        (( ttl < 0 )) && ttl=0
        local max_bet
        max_bet=$(current_max_bet_limit 100)

        printf '  %sCredits: %s%d%s   %sBet: %s%d%s   %sMax: %s%d%s   %sNext free +%d in: %s%s\n' \
            "$YELLOW" "$BOLD" "$CREDITS" "$RESET" \
            "$CYAN" "$BOLD" "$BET" "$RESET" \
            "$WHITE" "$BOLD" "$max_bet" "$RESET" \
            "$CYAN" "$PASSIVE_CREDIT_AMOUNT" "$(fmt_time "$ttl")" "$RESET"
        printf '  %sItems: %s 2x:%s Lucky: %s Shield: %s\n' \
            "$DIM" "$RESET" \
            "$( (( ITEM_2X_WIN )) && printf 'ON' || printf 'off' )" \
            "$( (( ITEM_LUCKY )) && printf 'ON' || printf 'off' )" \
            "$( (( ITEM_SHIELD )) && printf 'ON' || printf 'off' )"

        if (( CREDITS <= 0 )); then
            printf '\n  %s%sOUT OF CREDITS%s\n\n' "$RED" "$BOLD" "$RESET"
            read -r -p "  [ENTER] to check again, [q] to quit: " choice
            choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')
            [[ "$choice" == "q" ]] && break
            continue
        fi

        printf '  %s[ENTER] Spin  [b] Bet(%d)  [q] Quit%s\n' "$WHITE" "$BET" "$RESET"
        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        check_passive_credits

        case "$choice" in
            q)
                save_state
                printf '\n  %sFINAL CREDITS: %s%d%s\n\n' "$CYAN" "$BOLD" "$CREDITS" "$RESET"
                break
                ;;
            b)
                max_bet=$(current_max_bet_limit 100)
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

        prepare_spin
        spin_reels
        evaluate_reels "${RESULT_REELS[0]}" "${RESULT_REELS[1]}" "${RESULT_REELS[2]}"
        WIN_LABEL=$EVAL_LABEL
        WINNINGS=$EVAL_PAYOUT
        apply_payout_items "$BET" "$WINNINGS"
        WINNINGS=$FINAL_PAYOUT
        CREDITS=$(( CREDITS + WINNINGS ))
        save_state

        if (( WINNINGS > BET )); then
            if (( WINNINGS >= BET * 10 )); then
                jackpot_flash "${WIN_LABEL}! +${WINNINGS} CREDITS"
            elif [[ "$WIN_LABEL" == "TWO OF A KIND" ]]; then
                if (( WINNINGS > BET )); then
                    printf '  %s%s%s! 2x Win boosted the return to +%d CREDITS.%s\n' "$YELLOW" "$BOLD" "$WIN_LABEL" "$WINNINGS" "$RESET"
                else
                    printf '  %s%s%s! Bet returned.%s\n' "$YELLOW" "$BOLD" "$WIN_LABEL" "$RESET"
                fi
            else
                printf '  %s%s%s! +%d CREDITS%s\n' "$GREEN" "$BOLD" "$WIN_LABEL" "$WINNINGS" "$RESET"
            fi
        elif (( WINNINGS == BET )); then
            printf '  %s%s%s! Bet returned.%s\n' "$YELLOW" "$BOLD" "$WIN_LABEL" "$RESET"
        else
            if (( ITEM_USED_SHIELD )); then
                printf '  %sNo match. Shield blocked %d credits.%s\n' "$YELLOW" "$ITEM_SHIELD_BLOCKED" "$RESET"
            else
                printf '  %sNo match. -%d CREDITS.%s\n' "$RED" "$BET" "$RESET"
            fi
        fi

        [[ -n "$LUCKY_NOTE" ]] && printf '  %s%s%s\n' "$CYAN" "$LUCKY_NOTE" "$RESET"
        (( ITEM_USED_2X )) && printf '  %s2x Win doubled the slot payout.%s\n' "$CYAN" "$RESET"

        echo
    done
}

main "$@"
