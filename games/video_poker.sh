#!/usr/bin/env bash

SAVEFILE="$HOME/aura_gambling_suite_bash.txt"

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

SUITS=("S" "H" "D" "C")
RANKS=("A" "2" "3" "4" "5" "6" "7" "8" "9" "10" "J" "Q" "K")
PAY_NAMES=("Royal Flush" "Straight Flush" "Four of a Kind" "Full House" "Flush" "Straight" "Three of a Kind" "Two Pair" "Jacks or Better" "Nothing")
PAY_MULTS=(250 50 25 9 6 4 3 2 1 0)

WIDTH=62

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

hr() {
    local char="${1:-═}"
    local i
    for (( i=0; i<WIDTH; i++ )); do
        printf '%s' "$char"
    done
}

card_color() {
    case "$1" in
        H|D) echo "$RED" ;;
        *) echo "$WHITE" ;;
    esac
}

suit_glyph() {
    case "$1" in
        S) echo "S" ;;
        H) echo "H" ;;
        D) echo "D" ;;
        *) echo "C" ;;
    esac
}

rank_index() {
    case "$1" in
        A) echo 0 ;;
        2) echo 1 ;;
        3) echo 2 ;;
        4) echo 3 ;;
        5) echo 4 ;;
        6) echo 5 ;;
        7) echo 6 ;;
        8) echo 7 ;;
        9) echo 8 ;;
        10) echo 9 ;;
        J) echo 10 ;;
        Q) echo 11 ;;
        K) echo 12 ;;
    esac
}

fresh_deck() {
    DECK=()
    local suit rank
    for suit in "${SUITS[@]}"; do
        for rank in "${RANKS[@]}"; do
            DECK+=("$rank|$suit")
        done
    done

    local i j tmp
    for (( i=${#DECK[@]}-1; i>0; i-- )); do
        j=$(( RANDOM % (i + 1) ))
        tmp="${DECK[$i]}"
        DECK[$i]="${DECK[$j]}"
        DECK[$j]="$tmp"
    done
}

pop_card() {
    local idx=$(( ${#DECK[@]} - 1 ))
    DRAWN_CARD="${DECK[$idx]}"
    unset 'DECK[$idx]'
}

render_card_lines() {
    local rank="$1" suit="$2" held="$3" hidden="$4"
    local c border glyph label right
    c=$(card_color "$suit")
    glyph=$(suit_glyph "$suit")

    if [[ "$hidden" == "1" ]]; then
        CARD_LINES=(
            "${DIM}┌─────┐${RESET}"
            "${DIM}│░░░░░│${RESET}"
            "${DIM}│░░░░░│${RESET}"
            "${DIM}│░░░░░│${RESET}"
            "${DIM}└─────┘${RESET}"
        )
        return
    fi

    if [[ "$held" == "1" ]]; then
        border="${GREEN}${BOLD}"
    else
        border="${c}${BOLD}"
    fi

    printf -v label '%-2s' "$rank"
    printf -v right '%2s' "$rank"
    CARD_LINES=(
        "${border}┌─────┐${RESET}"
        "${border}│${label}   │${RESET}"
        "${border}│  ${glyph}  │${RESET}"
        "${border}│   ${right}│${RESET}"
        "${border}└─────┘${RESET}"
    )
}

is_held() {
    local idx="$1"
    local value
    for value in "${HELD[@]}"; do
        (( value == idx )) && return 0
    done
    return 1
}

draw_table() {
    local message="$1" phase="$2" result_name="$3" hidden="$4"
    local now ttl
    now=$(date +%s)
    ttl=$(( NEXT_CREDIT_TIME - now ))
    (( ttl < 0 )) && ttl=0

    clear
    printf '%s%s╔%s╗%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"
    printf '%s%s║                    SP VIDEO POKER                     ║%s\n' "$YELLOW" "$BOLD" "$RESET"
    printf '%s%s╠%s╣%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"
    printf '%s%s║%s  %sCredits: %s%d%s   %sBet: %s%d%s   %s+%d in %s%s\n' \
        "$YELLOW" "$BOLD" "$RESET" \
        "$YELLOW" "$BOLD" "$CREDITS" "$RESET" \
        "$CYAN" "$BOLD" "$BET" "$RESET" \
        "$DIM" "$PASSIVE_CREDIT_AMOUNT" "$(fmt_time "$ttl")" "$RESET"
    printf '%s%s╠%s╣%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"

    if [[ -n "$result_name" && "$result_name" != "Nothing" ]]; then
        printf '  %s%s%s%s\n' "$GREEN" "$BOLD" "$result_name" "$RESET"
    elif [[ "$phase" == "hold" ]]; then
        printf '  %sSelect cards to HOLD, then DRAW%s\n' "$DIM" "$RESET"
    else
        echo
    fi

    printf '%s%s╠%s╣%s\n' "$YELLOW" "$BOLD" "$(hr "─")" "$RESET"

    local rows=("" "" "" "" "")
    local i held_flag
    for (( i=0; i<5; i++ )); do
        is_held "$i" && held_flag=1 || held_flag=0
        render_card_lines "${HAND_RANKS[$i]}" "${HAND_SUITS[$i]}" "$held_flag" "$hidden"
        local row
        for row in 0 1 2 3 4; do
            rows[$row]+="${CARD_LINES[$row]} "
        done
    done
    for row in "${rows[@]}"; do
        printf '  %s\n' "$row"
    done

    local labels="" nums="" idx
    for idx in 0 1 2 3 4; do
        if is_held "$idx"; then
            labels+="${GREEN}${BOLD} HOLD  ${RESET} "
        else
            labels+="${DIM}       ${RESET} "
        fi
        labels+=""
        nums+="${DIM}  [$(( idx + 1 ))]  ${RESET} "
    done
    printf '  %s\n' "$labels"
    printf '  %s\n' "$nums"

    printf '%s%s╠%s╣%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"
    [[ -n "$message" ]] && printf '  %s\n' "$message" || echo
    printf '%s%s╚%s╝%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"
}

show_pay_table() {
    clear
    printf '%s%s╔%s╗%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"
    printf '%s%s║                SP VIDEO POKER - PAY TABLE            ║%s\n' "$YELLOW" "$BOLD" "$RESET"
    printf '%s%s╠%s╣%s\n' "$YELLOW" "$BOLD" "$(hr)" "$RESET"
    printf '  Bet: %d credit%s\n' "$BET" "$([ "$BET" -eq 1 ] || echo s)"
    printf '%s%s╠%s╣%s\n' "$YELLOW" "$BOLD" "$(hr "─")" "$RESET"

    local i payout color
    for (( i=0; i<${#PAY_NAMES[@]}; i++ )); do
        payout=$(( PAY_MULTS[$i] * BET ))
        color="$CYAN"
        [[ "${PAY_NAMES[$i]}" == "Royal Flush" ]] && color="$MAGENTA"
        [[ "${PAY_NAMES[$i]}" == "Nothing" ]] && color="$DIM"
        printf '  %s%-17s%s %6d cr\n' "$color" "${PAY_NAMES[$i]}" "$RESET" "$payout"
    done

    printf '\n  %s[ENTER] back%s' "$WHITE" "$RESET"
    read -r _
}

evaluate_hand() {
    local suit0="${HAND_SUITS[0]}"
    local flush=1
    local counts=(0 0 0 0 0 0 0 0 0 0 0 0 0)
    local unique=0
    local indices=()
    local i idx same_pair=0 max_count=0 pairs=0 three=0 four=0 jacks_or_better=0

    for (( i=0; i<5; i++ )); do
        [[ "${HAND_SUITS[$i]}" != "$suit0" ]] && flush=0
        idx=$(rank_index "${HAND_RANKS[$i]}")
        indices+=("$idx")
        counts[$idx]=$(( ${counts[$idx]} + 1 ))
    done

    SORTED_INDICES=($(printf '%s\n' "${indices[@]}" | sort -n))
    local straight=1
    for (( i=1; i<5; i++ )); do
        if (( SORTED_INDICES[$i] != SORTED_INDICES[$(( i - 1 ))] + 1 )); then
            straight=0
            break
        fi
    done
    if (( straight == 0 )); then
        if [[ "${HAND_RANKS[0]} ${HAND_RANKS[1]} ${HAND_RANKS[2]} ${HAND_RANKS[3]} ${HAND_RANKS[4]}" == *"A"* ]]; then
            local low_check
            low_check=$(printf '%s\n' "${HAND_RANKS[@]}" | sort | tr '\n' ' ')
            [[ "$low_check" == "2 3 4 5 A " ]] && straight=1
        fi
    fi

    for (( i=0; i<13; i++ )); do
        case "${counts[$i]}" in
            4) four=1 ;;
            3) three=1 ;;
            2)
                pairs=$(( pairs + 1 ))
                if (( i == 0 || i >= 10 )); then
                    jacks_or_better=1
                fi
                ;;
        esac
        (( counts[$i] > max_count )) && max_count=${counts[$i]}
        (( counts[$i] > 0 )) && unique=$(( unique + 1 ))
    done

    local royal=0
    if (( flush == 1 )); then
        if [[ " ${HAND_RANKS[*]} " == *" A "* && " ${HAND_RANKS[*]} " == *" K "* && " ${HAND_RANKS[*]} " == *" Q "* && " ${HAND_RANKS[*]} " == *" J "* && " ${HAND_RANKS[*]} " == *" 10 "* ]]; then
            royal=1
        fi
    fi

    if (( royal == 1 )); then
        HAND_NAME="Royal Flush"
        PAYOUT=$(( BET * 250 ))
    elif (( flush == 1 && straight == 1 )); then
        HAND_NAME="Straight Flush"
        PAYOUT=$(( BET * 50 ))
    elif (( four == 1 )); then
        HAND_NAME="Four of a Kind"
        PAYOUT=$(( BET * 25 ))
    elif (( three == 1 && pairs == 1 )); then
        HAND_NAME="Full House"
        PAYOUT=$(( BET * 9 ))
    elif (( flush == 1 )); then
        HAND_NAME="Flush"
        PAYOUT=$(( BET * 6 ))
    elif (( straight == 1 )); then
        HAND_NAME="Straight"
        PAYOUT=$(( BET * 4 ))
    elif (( three == 1 )); then
        HAND_NAME="Three of a Kind"
        PAYOUT=$(( BET * 3 ))
    elif (( pairs == 2 )); then
        HAND_NAME="Two Pair"
        PAYOUT=$(( BET * 2 ))
    elif (( pairs == 1 && jacks_or_better == 1 )); then
        HAND_NAME="Jacks or Better"
        PAYOUT=$BET
    else
        HAND_NAME="Nothing"
        PAYOUT=0
    fi
}

deal_hand() {
    fresh_deck
    HAND_RANKS=()
    HAND_SUITS=()
    local i
    for (( i=0; i<5; i++ )); do
        pop_card
        HAND_RANKS+=("${DRAWN_CARD%%|*}")
        HAND_SUITS+=("${DRAWN_CARD##*|}")
    done
}

redraw_hand() {
    local i
    for (( i=0; i<5; i++ )); do
        if ! is_held "$i"; then
            pop_card
            HAND_RANKS[$i]="${DRAWN_CARD%%|*}"
            HAND_SUITS[$i]="${DRAWN_CARD##*|}"
        fi
    done
}

toggle_holds() {
    local raw="$1" tok idx found new_held=()
    for idx in "${HELD[@]}"; do
        new_held+=("$idx")
    done

    for tok in $raw; do
        case "$tok" in
            1|2|3|4|5)
                idx=$(( tok - 1 ))
                found=0
                local kept=()
                local current
                for current in "${new_held[@]}"; do
                    if (( current == idx )); then
                        found=1
                    else
                        kept+=("$current")
                    fi
                done
                if (( found == 1 )); then
                    new_held=("${kept[@]}")
                else
                    new_held+=("$idx")
                fi
                ;;
        esac
    done

    HELD=("${new_held[@]}")
}

flash_result() {
    local msg="$1" color="$2" c
    for c in "$color" "$WHITE" "$color" "$WHITE" "$color" "$WHITE"; do
        printf '\r  %s%s%s%s   ' "$c" "$BOLD" "$msg" "$RESET"
        sleep 0.13
    done
    echo
}

play_round() {
    deal_hand
    HELD=()

    while true; do
        draw_table "${WHITE}[1-5] Toggle hold   [d] Draw   [p] Pay table   [q] Quit${RESET}" "hold" "" "0"
        read -r -p "  > " raw
        raw=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr ',' ' ')

        case "$raw" in
            q)
                ROUND_QUIT=1
                ROUND_CANCEL=1
                return
                ;;
            p)
                show_pay_table
                continue
                ;;
            d)
                break
                ;;
        esac

        toggle_holds "$raw"
    done

    draw_table "${CYAN}Drawing...${RESET}" "draw" "" "1"
    sleep 0.45
    redraw_hand
    evaluate_hand

    CREDITS=$(( CREDITS + PAYOUT ))
    save_state

    local color="$RED"
    if (( PAYOUT > 0 )); then
        color="$GREEN"
        [[ "$HAND_NAME" == "Royal Flush" ]] && color="$MAGENTA"
        [[ "$HAND_NAME" == "Straight Flush" || "$HAND_NAME" == "Four of a Kind" ]] && color="$YELLOW"
    fi

    HELD=(0 1 2 3 4)
    draw_table "${WHITE}[ENTER] Play again   [q] Quit${RESET}" "result" "$HAND_NAME" "0"
    if (( PAYOUT > 0 )); then
        flash_result "${HAND_NAME}! +${PAYOUT} credits" "$color"
    else
        flash_result "No win. -${BET} credits" "$color"
    fi

    read -r -p "  > " again
    again=$(printf '%s' "$again" | tr '[:upper:]' '[:lower:]')
    ROUND_QUIT=0
    ROUND_CANCEL=0
    [[ "$again" == "q" ]] && ROUND_QUIT=1
}

main() {
    load_state
    PENDING_BONUS=0
    BET=10

    clear
    printf '%s%s\n' "$CYAN" "$BOLD"
    echo "  ╔══════════════════════════════════╗"
    echo "  ║      SP VIDEO POKER              ║"
    echo "  ║      Aura Gambling Suite         ║"
    echo "  ╚══════════════════════════════════╝"
    printf '%s\n' "$RESET"

    while true; do
        check_passive_credits

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
        printf '  %sCredits: %s%d%s   %sBet: %s%d%s   %s+%d in %s%s\n' \
            "$YELLOW" "$BOLD" "$CREDITS" "$RESET" \
            "$CYAN" "$BOLD" "$BET" "$RESET" \
            "$DIM" "$PASSIVE_CREDIT_AMOUNT" "$(fmt_time "$ttl")" "$RESET"

        if (( CREDITS <= 0 )); then
            printf '\n  %s%sOUT OF CREDITS - wait for your free bonus!%s\n\n' "$RED" "$BOLD" "$RESET"
            read -r -p "  [ENTER] check again  [q] quit: " answer
            answer=$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')
            [[ "$answer" == "q" ]] && break
            continue
        fi

        printf '  %s[ENTER] Deal   [b] Change bet(%d)   [p] Pay table   [q] Quit%s\n' \
            "$WHITE" "$BET" "$RESET"
        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        case "$choice" in
            q)
                save_state
                printf '\n  %sFINAL CREDITS: %s%d%s\n\n' "$CYAN" "$BOLD" "$CREDITS" "$RESET"
                break
                ;;
            p)
                show_pay_table
                clear
                continue
                ;;
            b)
                local max_bet
                max_bet=$(( CREDITS < 500 ? CREDITS : 500 ))
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

        ROUND_QUIT=0
        ROUND_CANCEL=0
        play_round

        if (( ROUND_CANCEL == 1 )); then
            CREDITS=$(( CREDITS + BET ))
            save_state
            printf '\n  %sFINAL CREDITS: %s%d%s\n\n' "$CYAN" "$BOLD" "$CREDITS" "$RESET"
            break
        fi

        if (( ROUND_QUIT == 1 )); then
            printf '\n  %sFINAL CREDITS: %s%d%s\n\n' "$CYAN" "$BOLD" "$CREDITS" "$RESET"
            break
        fi

        echo
        sleep 0.3
    done
}

main "$@"
