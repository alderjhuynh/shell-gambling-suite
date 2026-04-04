#!/usr/bin/env bash

SAVEFILE="$HOME/aura_gambling_suite_bash.txt"

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

load_state() {
    CREDITS=100
    PASSIVE_EARNED=0
    NEXT_CREDIT_TIME=$(( $(date +%s) + PASSIVE_CREDIT_INTERVAL ))

    if [[ -f "$SAVEFILE" ]]; then
        while IFS='=' read -r key val; do
            case "$key" in
                credits) CREDITS=$val ;;
                passive_earned) PASSIVE_EARNED=$val ;;
                next_credit_time) NEXT_CREDIT_TIME=$val ;;
            esac
        done < "$SAVEFILE"

        (( PASSIVE_EARNED < 0 )) && PASSIVE_EARNED=0
        (( PASSIVE_EARNED > PASSIVE_CREDIT_CAP )) && PASSIVE_EARNED=$PASSIVE_CREDIT_CAP

        local now missed potential allowed gain
        now=$(date +%s)
        if (( NEXT_CREDIT_TIME <= now )); then
            missed=$(( (now - NEXT_CREDIT_TIME) / PASSIVE_CREDIT_INTERVAL + 1 ))
            potential=$(( missed * PASSIVE_CREDIT_AMOUNT ))
            allowed=$(( PASSIVE_CREDIT_CAP - PASSIVE_EARNED ))
            (( allowed < 0 )) && allowed=0
            gain=$(( potential < allowed ? potential : allowed ))
            CREDITS=$(( CREDITS + gain ))
            PASSIVE_EARNED=$(( PASSIVE_EARNED + gain ))
            NEXT_CREDIT_TIME=$(( now + PASSIVE_CREDIT_INTERVAL ))
        fi
    fi
}

save_state() {
    printf 'credits=%d\npassive_earned=%d\nnext_credit_time=%d\n' \
        "$CREDITS" "$PASSIVE_EARNED" "$NEXT_CREDIT_TIME" > "$SAVEFILE"
}

check_passive_credits() {
    local now avail gain
    now=$(date +%s)
    if (( now >= NEXT_CREDIT_TIME )); then
        if (( PASSIVE_EARNED < PASSIVE_CREDIT_CAP )); then
            avail=$(( PASSIVE_CREDIT_CAP - PASSIVE_EARNED ))
            gain=$(( PASSIVE_CREDIT_AMOUNT < avail ? PASSIVE_CREDIT_AMOUNT : avail ))
            CREDITS=$(( CREDITS + gain ))
            PASSIVE_EARNED=$(( PASSIVE_EARNED + gain ))
            PENDING_BONUS=$(( PENDING_BONUS + gain ))
        fi
        NEXT_CREDIT_TIME=$(( now + PASSIVE_CREDIT_INTERVAL ))
        save_state
    fi
}

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
    printf '  Credits: %s%d%s   Bet: %s%d%s   %s+10 in %ds%s\n' \
        "$BOLD" "$CREDITS" "$RESET" "$BOLD" "$BET" "$RESET" "$DIM" "$ttl" "$RESET"

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
                read -r -p "New bet: " new_bet
                if [[ "$new_bet" =~ ^[0-9]+$ ]]; then
                    (( new_bet < 1 )) && new_bet=1
                    (( new_bet > CREDITS )) && new_bet=$CREDITS
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

        ai_predict
        ai_counter "$PREDICTED_MOVE"
        resolve_round "$PLAYER_MOVE" "$BOT_MOVE"

        local delta=0
        if (( RESULT_VALUE > 0 )); then
            delta=$(( BET * 2 ))
        elif (( RESULT_VALUE == 0 )); then
            delta=$BET
        fi

        CREDITS=$(( CREDITS + delta ))
        save_state

        ai_update "$PLAYER_MOVE"

        LAST_ROUND_PLAYER=$(move_name "$PLAYER_MOVE")
        LAST_ROUND_BOT=$(move_name "$BOT_MOVE")
        LAST_ROUND_RESULT=$RESULT_LABEL

        sleep 0.6
    done

    printf 'Final credits: %d\n' "$CREDITS"
}

main "$@"
