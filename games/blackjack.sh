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


SUITS=("♠" "♥" "♦" "♣")
RANKS=("A" "2" "3" "4" "5" "6" "7" "8" "9" "10" "J" "Q" "K")

declare -a DECK=()
declare -a PLAYER_HAND=()
declare -a DEALER_HAND=()

WIDTH=54


fresh_deck() {
    DECK=()
    for suit in "${SUITS[@]}"; do
        for rank in "${RANKS[@]}"; do
            DECK+=("$rank|$suit")
        done
    done
    local n=${#DECK[@]}
    for (( i=n-1; i>0; i-- )); do
        local j=$(( RANDOM % (i+1) ))
        local tmp="${DECK[$i]}"
        DECK[$i]="${DECK[$j]}"
        DECK[$j]="$tmp"
    done
}

pop_card() {
    local last_index=$(( ${#DECK[@]} - 1 ))
    local top="${DECK[$last_index]}"
    unset 'DECK[$last_index]'

    CARD_RANK="${top%%|*}"
    CARD_SUIT="${top##*|}"
}

deal_to_player() { pop_card; PLAYER_HAND+=("$CARD_RANK|$CARD_SUIT"); }
deal_to_dealer() { pop_card; DEALER_HAND+=("$CARD_RANK|$CARD_SUIT"); }

card_value() {
    local rank="$1"
    case "$rank" in
        J|Q|K) echo 10 ;;
        A)     echo 11 ;;
        *)     echo "$rank" ;;
    esac
}

hand_total() {
    local total=0 aces=0
    for entry in "$@"; do
        local rank="${entry%%|*}"
        local v
        v=$(card_value "$rank")
        total=$(( total + v ))
        [[ "$rank" == "A" ]] && (( aces++ ))
    done
    while (( total > 21 && aces > 0 )); do
        total=$(( total - 10 ))
        (( aces-- ))
    done
    echo "$total"
}

is_blackjack() {
    local arr=("$@")
    [[ ${#arr[@]} -eq 2 ]] || return 1
    local t
    t=$(hand_total "${arr[@]}")
    [[ "$t" -eq 21 ]]
}

dealer_should_hit() {
    local total
    total=$(hand_total "${DEALER_HAND[@]}")
    (( total < 17 )) && return 0
    if (( total == 17 )); then
        local raw=0
        for entry in "${DEALER_HAND[@]}"; do
            local r="${entry%%|*}"
            raw=$(( raw + $(card_value "$r") ))
        done
        if (( raw == total )); then
            for entry in "${DEALER_HAND[@]}"; do
                [[ "${entry%%|*}" == "A" ]] && return 0
            done
        fi
    fi
    return 1
}

hr() {
    local char="${1:-═}"
    printf '%0.s'"$char" $(seq 1 $WIDTH)
}

render_card_lines() {
    local rank="$1" suit="$2" hidden="${3:-}"
    local c="$WHITE"
    [[ "$suit" == "♥" || "$suit" == "♦" ]] && c="$RED"

    if [[ -n "$hidden" ]]; then
        CARD_LINES=(
            "${DIM}┌─────┐${RESET}"
            "${DIM}│░░░░░│${RESET}"
            "${DIM}│░░░░░│${RESET}"
            "${DIM}│░░░░░│${RESET}"
            "${DIM}└─────┘${RESET}"
        )
    else
        local label
        printf -v label "%-2s" "$rank"
        local label_r
        printf -v label_r "%2s" "$rank"
        CARD_LINES=(
            "${c}${BOLD}┌─────┐${RESET}"
            "${c}${BOLD}│${label}   │${RESET}"
            "${c}${BOLD}│  ${suit}  │${RESET}"
            "${c}${BOLD}│   ${label_r}│${RESET}"
            "${c}${BOLD}└─────┘${RESET}"
        )
    fi
}

visible_len() {
    local s="$1"
    s="${s//$'\033['[0-9]*m/}"
    printf '%s' "$s" | sed 's/\x1b\[[0-9;]*m//g' | wc -m | tr -d ' '
}

draw_table() {
    local hide_dealer="${1:-1}"
    local message="${2:-}"
    local phase="${3:-playing}"

    local p_total d_str d_total
    p_total=$(hand_total "${PLAYER_HAND[@]}")

    if [[ "$hide_dealer" -eq 1 ]]; then
        d_total=$(hand_total "${DEALER_HAND[0]}")
        d_str="${d_total} + ?"
    else
        d_total=$(hand_total "${DEALER_HAND[@]}")
        d_str="$d_total"
    fi

    local now ttl
    now=$(date +%s)
    ttl=$(( NEXT_CREDIT_TIME - now ))
    (( ttl < 0 )) && ttl=0
    local m=$(( ttl / 60 )) s=$(( ttl % 60 ))
    local timer_str
    printf -v timer_str "%dm %02ds" "$m" "$s"

    clear

    echo "${YELLOW}${BOLD}╔$(hr)╗${RESET}"
    echo "${YELLOW}${BOLD}║  ♠ ♥  B L A C K J A C K  ♦ ♣$(printf '%*s' $(( WIDTH - 30 )) '')║${RESET}"
    echo "${YELLOW}${BOLD}╠$(hr)╣${RESET}"
    echo "${YELLOW}${BOLD}║${RESET}  ${YELLOW}Credits: ${BOLD}${CREDITS}${RESET}   ${CYAN}Bet: ${BOLD}${BET}${RESET}   ${DIM}+${PASSIVE_CREDIT_AMOUNT} in ${timer_str}${RESET}"
    echo "${YELLOW}${BOLD}╠$(hr)╣${RESET}"
    echo "${YELLOW}${BOLD}║${RESET}  DEALER  [${d_str}]"

    local -a all_rows=("" "" "" "" "")
    for (( i=0; i<${#DEALER_HAND[@]}; i++ )); do
        local entry="${DEALER_HAND[$i]}"
        local r="${entry%%|*}" su="${entry##*|}"
        local hide_this=""
        (( i == 1 && hide_dealer == 1 )) && hide_this="hidden"
        render_card_lines "$r" "$su" "$hide_this"
        for (( row=0; row<5; row++ )); do
            all_rows[$row]+="${CARD_LINES[$row]} "
        done
    done
    for row in "${all_rows[@]}"; do echo "  $row"; done

    echo "${YELLOW}${BOLD}╠$(hr ─)╣${RESET}"

    local bust_warn="" bj_warn=""
    (( p_total > 21 )) && bust_warn="  ${RED}${BOLD}BUST!${RESET}"
    if is_blackjack "${PLAYER_HAND[@]}" && [[ "$phase" == "playing" ]]; then
        bj_warn="  ${MAGENTA}${BOLD}BLACKJACK!${RESET}"
    fi
    echo "${YELLOW}${BOLD}║${RESET}  YOU     [${p_total}]${bust_warn}${bj_warn}"

    all_rows=("" "" "" "" "")
    for entry in "${PLAYER_HAND[@]}"; do
        local r="${entry%%|*}" su="${entry##*|}"
        render_card_lines "$r" "$su"
        for (( row=0; row<5; row++ )); do
            all_rows[$row]+="${CARD_LINES[$row]} "
        done
    done
    for row in "${all_rows[@]}"; do echo "  $row"; done

    echo "${YELLOW}${BOLD}╠$(hr)╣${RESET}"
    [[ -n "$message" ]] && echo "  $message"
    echo "${YELLOW}${BOLD}╚$(hr)╝${RESET}"
}

flash_result() {
    local msg="$1" color="$2"
    for c in "$color" "$WHITE" "$color" "$WHITE" "$color" "$WHITE"; do
        printf "\r  %s%s%s   " "$c" "${BOLD}${msg}${RESET}" "$RESET"
        sleep 0.12
    done
    echo
}

opening_hand_score() {
    local player_total dealer_up score
    player_total=$(hand_total "${PLAYER_HAND[@]}")
    dealer_up=$(hand_total "${DEALER_HAND[0]}")
    score=$(( player_total * 10 - dealer_up ))
    is_blackjack "${PLAYER_HAND[@]}" && score=$(( score + 1000 ))
    printf '%d\n' "$score"
}

deal_opening_hands() {
    local lucky_active=0
    LUCKY_NOTE=""
    if consume_lucky; then
        lucky_active=1
        LUCKY_NOTE="Lucky steered the opening deal your way."
    fi

    if (( lucky_active == 0 )); then
        PLAYER_HAND=()
        DEALER_HAND=()
        fresh_deck
        deal_to_player; deal_to_player
        deal_to_dealer; deal_to_dealer
        return
    fi

    local best_score="" attempt current_score
    local -a best_player best_dealer best_deck
    for attempt in 1 2 3; do
        PLAYER_HAND=()
        DEALER_HAND=()
        fresh_deck
        deal_to_player; deal_to_player
        deal_to_dealer; deal_to_dealer
        current_score=$(opening_hand_score)
        if [[ -z "$best_score" || "$current_score" -gt "$best_score" ]]; then
            best_score=$current_score
            best_player=("${PLAYER_HAND[@]}")
            best_dealer=("${DEALER_HAND[@]}")
            best_deck=("${DECK[@]}")
        fi
    done

    PLAYER_HAND=("${best_player[@]}")
    DEALER_HAND=("${best_dealer[@]}")
    DECK=("${best_deck[@]}")
}

dealer_play() {
    draw_table 0 "${CYAN}Dealer reveals hole card…${RESET}" "dealer"
    sleep 1

    while dealer_should_hit; do
        pop_card
        DEALER_HAND+=("$CARD_RANK|$CARD_SUIT")
        draw_table 0 "${CYAN}Dealer hits…${RESET}" "dealer"
        sleep 0.9
    done

    local d_total
    d_total=$(hand_total "${DEALER_HAND[@]}")
    draw_table 0 "${YELLOW}Dealer stands at ${d_total}.${RESET}" "dealer"
    sleep 0.8
}

play_round() {
    deal_opening_hands

    draw_table 1 "${WHITE}[h] Hit   [s] Stand   [q] Quit${RESET}" "playing"

    if is_blackjack "${PLAYER_HAND[@]}"; then
        if is_blackjack "${DEALER_HAND[@]}"; then
            draw_table 0 "${MAGENTA}${BOLD}BLACKJACK! Pays 3:2${RESET}" "result"
            sleep 1.5
            ROUND_PAYOUT=$BET; ROUND_MSG="PUSH — both blackjack"; ROUND_COLOR="$YELLOW"
            return
        fi
        draw_table 0 "${MAGENTA}${BOLD}BLACKJACK! Pays 3:2${RESET}" "result"
        sleep 1.5
        ROUND_PAYOUT=$(( BET * 5 / 2 ))
        ROUND_MSG="BLACKJACK! Huge payout"; ROUND_COLOR="$MAGENTA"
        return
    fi

    local outcome_early=""
    while true; do
        local p_total
        p_total=$(hand_total "${PLAYER_HAND[@]}")

        if (( p_total > 21 )); then
            draw_table 1 "${RED}${BOLD}BUST!${RESET}" "bust"
            sleep 1
            ROUND_PAYOUT=0
            ROUND_MSG="BUST — -${BET} credits"
            ROUND_COLOR="$RED"
            outcome_early=1
            break
        fi

        if (( p_total == 21 )); then
            draw_table 1 "${GREEN}${BOLD}21! Standing automatically.${RESET}" "playing"
            sleep 1
            break
        fi

        draw_table 1 "${WHITE}[h] Hit   [s] Stand${RESET}" "playing"
        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        case "$choice" in
            q) ROUND_PAYOUT=""; return ;;
            h) deal_to_player ;;
            s) break ;;
        esac
    done

    [[ -n "$outcome_early" ]] && return

    dealer_play

    local p d
    p=$(hand_total "${PLAYER_HAND[@]}")
    d=$(hand_total "${DEALER_HAND[@]}")

    if (( d > 21 )); then
        ROUND_PAYOUT=$(( BET * 2 )); ROUND_MSG="DEALER BUSTS!"; ROUND_COLOR="$GREEN"
    elif (( p > d )); then
        ROUND_PAYOUT=$(( BET * 2 )); ROUND_MSG="YOU WIN!"; ROUND_COLOR="$GREEN"
    elif (( p < d )); then
        ROUND_PAYOUT=0; ROUND_MSG="DEALER WINS."; ROUND_COLOR="$RED"
    else
        ROUND_PAYOUT=$BET; ROUND_MSG="PUSH — tie"; ROUND_COLOR="$YELLOW"
    fi
}

main() {
    load_state

    BET=10
    PENDING_BONUS=0

    clear
    echo "${CYAN}${BOLD}"
    echo "  ╔═════════════════════════════╗"
    echo "  ║    ♠ ♥  BLACKJACK  ♦ ♣      ║"
    echo "  ║    Aura Gambling Suite      ║"
    echo "  ╚═════════════════════════════╝"
    echo "${RESET}"

    while true; do
        check_passive_credits
        clamp_bet_to_limit 500 10

        if (( PENDING_BONUS > 0 )); then
            echo ""
            echo "  ${CYAN}${BOLD}+${PENDING_BONUS} FREE CREDITS!${RESET}"
            echo ""
            PENDING_BONUS=0
            sleep 1
        fi

        local now ttl m s
        now=$(date +%s)
        ttl=$(( NEXT_CREDIT_TIME - now ))
        (( ttl < 0 )) && ttl=0
        m=$(( ttl / 60 )); s=$(( ttl % 60 ))
        local max_bet
        max_bet=$(current_max_bet_limit 500)
        printf "  ${YELLOW}Credits: ${BOLD}%d${RESET}   ${CYAN}Bet: ${BOLD}%d${RESET}   ${WHITE}Max: ${BOLD}%d${RESET}   ${DIM}+%d in %dm %02ds${RESET}\n" \
            "$CREDITS" "$BET" "$max_bet" "$PASSIVE_CREDIT_AMOUNT" "$m" "$s"
        printf "  ${DIM}Items:${RESET} 2x: %s  Lucky: %s  Shield: %s\n" \
            "$( (( ITEM_2X_WIN )) && printf 'ON' || printf 'off' )" \
            "$( (( ITEM_LUCKY )) && printf 'ON' || printf 'off' )" \
            "$( (( ITEM_SHIELD )) && printf 'ON' || printf 'off' )"

        if (( CREDITS <= 0 )); then
            echo ""
            echo "  ${RED}${BOLD}OUT OF CREDITS — wait for your free bonus!${RESET}"
            echo ""
            read -r -p "  [ENTER] check again  [q] quit: " ans
            ans=$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')
            [[ "$ans" == "q" ]] && break
            check_passive_credits
            continue
        fi

        echo "  ${WHITE}[ENTER] Deal  [b] Change bet(${BET})  [q] Quit${RESET}"
        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        check_passive_credits
        if (( PENDING_BONUS > 0 )); then
            echo ""
            echo "  ${CYAN}${BOLD}+${PENDING_BONUS} FREE CREDITS!${RESET}"
            echo ""
            PENDING_BONUS=0
        fi

        case "$choice" in
            q)
                save_state
                echo ""
                echo "  ${CYAN}FINAL CREDITS: ${BOLD}${CREDITS}${RESET}"
                echo ""
                break
                ;;
            b)
                max_bet=$(current_max_bet_limit 500)
                read -r -p "  ${WHITE}ENTER BET (10–${max_bet}): ${RESET}" new_bet
                if [[ "$new_bet" =~ ^[0-9]+$ ]]; then
                    (( new_bet < 10  )) && new_bet=10
                    (( new_bet > max_bet )) && new_bet=$max_bet
                    BET=$new_bet
                fi
                echo ""
                continue
                ;;
        esac

        if (( BET > CREDITS )); then
            echo "  ${RED}NOT ENOUGH CREDITS${RESET}"
            echo ""
            continue
        fi

        CREDITS=$(( CREDITS - BET ))
        PASSIVE_EARNED=0
        save_state

        ROUND_PAYOUT="" ROUND_MSG="" ROUND_COLOR=""
        play_round

        if [[ -z "$ROUND_PAYOUT" ]]; then
            CREDITS=$(( CREDITS + BET ))
            save_state
            echo ""
            echo "  ${CYAN}FINAL CREDITS: ${BOLD}${CREDITS}${RESET}"
            echo ""
            break
        fi

        apply_payout_items "$BET" "$ROUND_PAYOUT"
        CREDITS=$(( CREDITS + FINAL_PAYOUT ))
        save_state

        if [[ -n "$LUCKY_NOTE" ]]; then
            ROUND_MSG="${ROUND_MSG} ${LUCKY_NOTE}"
        fi
        if (( ITEM_USED_2X )); then
            ROUND_MSG="${ROUND_MSG} 2x Win doubled the payout."
        elif (( ITEM_USED_SHIELD )); then
            ROUND_MSG="${ROUND_MSG} Shield blocked ${ITEM_SHIELD_BLOCKED} credits."
        fi

        flash_result "$ROUND_MSG" "$ROUND_COLOR"
        echo ""
        sleep 0.5

        clear
        echo "${CYAN}${BOLD}"
        echo "  ╔═════════════════════════════╗"
        echo "  ║    ♠ ♥  BLACKJACK  ♦ ♣      ║"
        echo "  ║    Aura Gambling Suite      ║"
        echo "  ╚═════════════════════════════╝"
        echo "${RESET}"
    done
}

main "$@"
