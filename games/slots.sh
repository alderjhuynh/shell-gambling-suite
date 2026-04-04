#!/usr/bin/env bash

SAVEFILE="$HOME/aura_gambling_suite_bash.txt"

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
    local now gain avail
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
    RESULT_REELS[0]="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
    RESULT_REELS[1]="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"
    RESULT_REELS[2]="${SYMBOLS[$(( RANDOM % ${#SYMBOLS[@]} ))]}"

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

evaluate_spin() {
    local a="${RESULT_REELS[0]}" b="${RESULT_REELS[1]}" c="${RESULT_REELS[2]}"
    WIN_LABEL=""
    WINNINGS=0
    if [[ "$a" == "DM" && "$b" == "DM" && "$c" == "DM" ]]; then
        WIN_LABEL="DIAMOND JACKPOT"; WINNINGS=$(( BET * 100 ))
    elif [[ "$a" == "ST" && "$b" == "ST" && "$c" == "ST" ]]; then
        WIN_LABEL="STAR JACKPOT"; WINNINGS=$(( BET * 50 ))
    elif [[ "$a" == "77" && "$b" == "77" && "$c" == "77" ]]; then
        WIN_LABEL="LUCKY SEVENS"; WINNINGS=$(( BET * 40 ))
    elif [[ "$a" == "CH" && "$b" == "CH" && "$c" == "CH" ]]; then
        WIN_LABEL="CHERRY BONUS"; WINNINGS=$(( BET * 20 ))
    elif [[ "$a" == "GR" && "$b" == "GR" && "$c" == "GR" ]]; then
        WIN_LABEL="GRAPE BONUS"; WINNINGS=$(( BET * 15 ))
    elif [[ "$a" == "OR" && "$b" == "OR" && "$c" == "OR" ]]; then
        WIN_LABEL="ORANGE BONUS"; WINNINGS=$(( BET * 12 ))
    elif [[ "$a" == "LM" && "$b" == "LM" && "$c" == "LM" ]]; then
        WIN_LABEL="LEMON BONUS"; WINNINGS=$(( BET * 10 ))
    elif [[ "$a" == "$b" || "$a" == "$c" || "$b" == "$c" ]]; then
        WIN_LABEL="TWO OF A KIND"; WINNINGS=$BET
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

        if (( PENDING_BONUS > 0 )); then
            printf '\n  %s%s +%d FREE CREDITS! %s\n\n' "$CYAN" "$BOLD" "$PENDING_BONUS" "$RESET"
            PENDING_BONUS=0
        fi

        local now ttl
        now=$(date +%s)
        ttl=$(( NEXT_CREDIT_TIME - now ))
        (( ttl < 0 )) && ttl=0
        printf '  %sCredits: %s%d%s   %sNext free +%d in: %s%s\n' \
            "$YELLOW" "$BOLD" "$CREDITS" "$RESET" \
            "$CYAN" "$PASSIVE_CREDIT_AMOUNT" "$(fmt_time "$ttl")" "$RESET"

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
                local max_bet
                max_bet=$(( CREDITS < 100 ? CREDITS : 100 ))
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

        spin_reels
        evaluate_spin
        CREDITS=$(( CREDITS + WINNINGS ))
        save_state

        if (( WINNINGS > 0 )); then
            if (( WINNINGS >= BET * 10 )); then
                jackpot_flash "${WIN_LABEL}! +${WINNINGS} CREDITS"
            elif [[ "$WIN_LABEL" == "TWO OF A KIND" ]]; then
                printf '  %s%s%s! Bet returned.%s\n' "$YELLOW" "$BOLD" "$WIN_LABEL" "$RESET"
            else
                printf '  %s%s%s! +%d CREDITS%s\n' "$GREEN" "$BOLD" "$WIN_LABEL" "$WINNINGS" "$RESET"
            fi
        else
            printf '  %sNo match. -%d CREDITS.%s\n' "$RED" "$BET" "$RESET"
        fi

        echo
    done
}

main "$@"
