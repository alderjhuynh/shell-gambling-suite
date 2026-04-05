#!/usr/bin/env bash

SAVEFILE="$HOME/aura_gambling_suite_bash.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PASSIVE_CREDIT_AMOUNT=10
PASSIVE_CREDIT_INTERVAL=300
PASSIVE_CREDIT_CAP=100

RESET=$'\033[0m'
BOLD=$'\033[1m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
RED=$'\033[91m'
YELLOW=$'\033[93m'
WHITE=$'\033[97m'
DIM=$'\033[2m'

WIDTH=50

hr() {
    local i
    for (( i=0; i<WIDTH; i++ )); do
        printf '═'
    done
}

move_name() {
    case "$1" in
        0) echo "rock" ;;
        1) echo "paper" ;;
        *) echo "scissors" ;;
    esac
}

move_index() {
    case "$1" in
        rock) echo 0 ;;
        paper) echo 1 ;;
        *) echo 2 ;;
    esac
}

ai_init() {
    TRANSITIONS=(0 0 0 0 0 0 0 0 0)
    LAST_PLAYER_MOVE=-1
}

ai_update() {
    local move_idx=$1
    if (( LAST_PLAYER_MOVE >= 0 )); then
        local slot=$(( LAST_PLAYER_MOVE * 3 + move_idx ))
        TRANSITIONS[$slot]=$(( ${TRANSITIONS[$slot]} + 1 ))
    fi
    LAST_PLAYER_MOVE=$move_idx
}

ai_predict() {
    if (( LAST_PLAYER_MOVE < 0 )); then
        PREDICTED_MOVE=$(( RANDOM % 3 ))
        return
    fi

    local base=$(( LAST_PLAYER_MOVE * 3 ))
    local total=$(( ${TRANSITIONS[$base]} + ${TRANSITIONS[$(( base + 1 ))]} + ${TRANSITIONS[$(( base + 2 ))]} ))

    if (( total <= 0 )); then
        PREDICTED_MOVE=$(( RANDOM % 3 ))
        return
    fi

    local roll=$(( RANDOM % total + 1 ))
    local cum=0
    local i
    for i in 0 1 2; do
        cum=$(( cum + ${TRANSITIONS[$(( base + i ))]} ))
        if (( roll <= cum )); then
            PREDICTED_MOVE=$i
            return
        fi
    done

    PREDICTED_MOVE=0
}

ai_counter() {
    case "$1" in
        0) BOT_MOVE=1 ;;
        1) BOT_MOVE=2 ;;
        *) BOT_MOVE=0 ;;
    esac
}

resolve_round() {
    local player=$1 bot=$2
    if (( player == bot )); then
        RESULT_VALUE=0
        RESULT_LABEL="TIE"
    elif (( (player == 0 && bot == 2) || (player == 1 && bot == 0) || (player == 2 && bot == 1) )); then
        RESULT_VALUE=1
        RESULT_LABEL="WIN"
    else
        RESULT_VALUE=-1
        RESULT_LABEL="LOSS"
    fi
}

draw_screen() {
    local message="$1"
    clear
    printf '%s%s╔%s╗%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"
    printf '%s%s║  ROCK PAPER SCISSORS%*s║%s\n' "$YELLOW" "$BOLD" $(( WIDTH - 22 )) "" "$RESET"
    printf '%s%s║  Aura Gambling Suite%*s║%s\n' "$YELLOW" "$BOLD" $(( WIDTH - 21 )) "" "$RESET"
    printf '%s%s╠%s╣%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"

    local now ttl
    now=$(date +%s)
    ttl=$(( NEXT_CREDIT_TIME - now ))
    (( ttl < 0 )) && ttl=0
    local max_bet
    max_bet=$(current_max_bet_limit "$CREDITS")
    printf '  Credits: %s%d%s   Bet: %s%d%s   Max: %s%d%s   %s+10 in %ds%s\n' \
        "$BOLD" "$CREDITS" "$RESET" "$BOLD" "$BET" "$RESET" "$BOLD" "$max_bet" "$RESET" "$DIM" "$ttl" "$RESET"
    printf '  Items: 2x: %s  Lucky: %s  Shield: %s\n' \
        "$( (( ITEM_2X_WIN )) && printf 'ON' || printf 'off' )" \
        "$( (( ITEM_LUCKY )) && printf 'ON' || printf 'off' )" \
        "$( (( ITEM_SHIELD )) && printf 'ON' || printf 'off' )"

    printf '%s%s╠%s╣%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"

    if [[ -n "$LAST_ROUND_RESULT" ]]; then
        printf '  You: %s | Raya: %s -> %s\n' \
            "$LAST_ROUND_PLAYER" "$LAST_ROUND_BOT" "$LAST_ROUND_RESULT"
    fi

    printf '\n  %s\n\n' "$message"
    printf '%s%s╚%s╝%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"
}

main() {
    load_state
    PENDING_BONUS=0
    BET=10
    LAST_ROUND_PLAYER=""
    LAST_ROUND_BOT=""
    LAST_ROUND_RESULT=""
    ai_init

    while true; do
        check_passive_credits
        clamp_bet_to_limit "$CREDITS" 1

        if (( PENDING_BONUS > 0 )); then
            printf '\n+%d FREE CREDITS!\n\n' "$PENDING_BONUS"
            PENDING_BONUS=0
            sleep 1
        fi

        if (( CREDITS <= 0 )); then
            draw_screen "OUT OF CREDITS"
            read -r -p "Press enter..." _
            continue
        fi

        draw_screen "[r] rock  [p] paper  [s] scissors  [b] bet  [q] quit"
        read -r -p " > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        case "$choice" in
            q)
                break
                ;;
            b)
                local max_bet
                max_bet=$(current_max_bet_limit "$CREDITS")
                read -r -p "New bet (1-${max_bet}): " new_bet
                if [[ "$new_bet" =~ ^[0-9]+$ ]]; then
                    (( new_bet < 1 )) && new_bet=1
                    (( new_bet > max_bet )) && new_bet=$max_bet
                    BET=$new_bet
                fi
                continue
                ;;
            r) PLAYER_MOVE=0 ;;
            p) PLAYER_MOVE=1 ;;
            s) PLAYER_MOVE=2 ;;
            *) continue ;;
        esac

        check_passive_credits
        if (( BET > CREDITS )); then
            continue
        fi

        CREDITS=$(( CREDITS - BET ))
        PASSIVE_EARNED=0
        save_state

        local lucky_round=0
        local round_note=""
        if consume_lucky; then
            lucky_round=1
            round_note="Lucky nudged Raya into a worse throw."
        fi

        ai_predict
        if (( lucky_round )); then
            local lucky_roll=$(( RANDOM % 100 ))
            if (( lucky_roll < 60 )); then
                BOT_MOVE=$(( (PLAYER_MOVE + 2) % 3 ))
            elif (( lucky_roll < 85 )); then
                BOT_MOVE=$PLAYER_MOVE
            else
                ai_counter "$PREDICTED_MOVE"
            fi
        else
            ai_counter "$PREDICTED_MOVE"
        fi
        resolve_round "$PLAYER_MOVE" "$BOT_MOVE"

        local payout=0
        if (( RESULT_VALUE > 0 )); then
            payout=$(( BET * 2 ))
        elif (( RESULT_VALUE == 0 )); then
            payout=$BET
        fi

        apply_payout_items "$BET" "$payout"
        CREDITS=$(( CREDITS + FINAL_PAYOUT ))
        save_state

        ai_update "$PLAYER_MOVE"

        LAST_ROUND_PLAYER=$(move_name "$PLAYER_MOVE")
        LAST_ROUND_BOT=$(move_name "$BOT_MOVE")
        LAST_ROUND_RESULT=$RESULT_LABEL
        if (( RESULT_VALUE > 0 && ITEM_USED_2X )); then
            LAST_ROUND_RESULT="${RESULT_LABEL} (2x Win)"
        elif (( RESULT_VALUE < 0 && ITEM_USED_SHIELD )); then
            LAST_ROUND_RESULT="${RESULT_LABEL} (Shield)"
        elif [[ -n "$round_note" ]]; then
            LAST_ROUND_RESULT="${RESULT_LABEL} (Lucky)"
        fi

        sleep 0.6
    done

    printf 'Final credits: %d\n' "$CREDITS"
}

main "$@"
