#!/usr/bin/env bash

SAVEFILE="$HOME/aura_gambling_suite_bash.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

RESET=$'\033[0m'
BOLD=$'\033[1m'
YELLOW=$'\033[93m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
RED=$'\033[91m'
WHITE=$'\033[97m'
MAGENTA=$'\033[95m'
DIM=$'\033[2m'
BLUE=$'\033[94m'
ORANGE=$'\033[38;5;214m'

WIDTH=54


hr() {
    local char="${1:-═}"
    printf '%0.s'"$char" $(seq 1 $WIDTH)
}

pause() {
    read -r -p "  ${DIM}Press ENTER to continue…${RESET} " _
}

flash_msg() {
    local msg="$1" color="$2"
    for c in "$color" "$WHITE" "$color" "$WHITE" "$color"; do
        printf "\r  %s%s%s   " "$c" "${BOLD}${msg}${RESET}" "$RESET"
        sleep 0.13
    done
    echo
}


draw_header() {
    clear
    echo "${YELLOW}${BOLD}╔$(hr)╗${RESET}"
    echo "${YELLOW}${BOLD}║  ★  A U R A   S H O P  ★$(printf '%*s' $(( WIDTH - 26 )) '')║${RESET}"
    echo "${YELLOW}${BOLD}╠$(hr)╣${RESET}"
    printf "${YELLOW}${BOLD}║${RESET}  ${YELLOW}Credits: ${BOLD}%-6d${RESET}   ${DIM}2x: %-3s Shield: %-3s MBL: %-1s${RESET}\n" \
        "$CREDITS" \
        "$( (( ITEM_2X_WIN  )) && echo ON || echo off )" \
        "$( (( ITEM_LUCKY   )) && echo ON || echo off )" \
        "$( (( ITEM_SHIELD  )) && echo ON || echo off )" \
        "$ITEM_MAX_BET_LEVEL"
    echo "${YELLOW}${BOLD}╠$(hr)╣${RESET}"
}

draw_footer() {
    echo "${YELLOW}${BOLD}╚$(hr)╝${RESET}"
}


draw_shop() {
    draw_header

    local mbl_next_cost mbl_next_label
    case "$ITEM_MAX_BET_LEVEL" in
        0) mbl_next_cost=100;    mbl_next_label="→ Lv1 (500cr max bet)" ;;
        1) mbl_next_cost=1000;   mbl_next_label="→ Lv2 (1,000cr max bet)" ;;
        2) mbl_next_cost=10000;  mbl_next_label="→ Lv3 (10,000cr max bet)" ;;
        3) mbl_next_cost=100000; mbl_next_label="→ Lv4 (100,000cr max bet)" ;;
        *) mbl_next_cost=0;      mbl_next_label="(MAX)" ;;
    esac

    printf "  ${CYAN}${BOLD}[1]${RESET} ${WHITE}Loot Crate         ${YELLOW}500cr${RESET}\n"
    printf "      ${DIM}Roll for credits — Common to Jackpot${RESET}\n\n"

    local win_label
    (( ITEM_2X_WIN )) && win_label="${RED}ACTIVE — only 1 allowed${RESET}" || win_label="${YELLOW}2,500cr${RESET}"
    printf "  ${CYAN}${BOLD}[2]${RESET} ${WHITE}2x Win             ${win_label}\n"
    printf "      ${DIM}Doubles your next win payout${RESET}\n\n"

    local lucky_label
    (( ITEM_LUCKY )) && lucky_label="${RED}ACTIVE — only 1 allowed${RESET}" || lucky_label="${YELLOW}1,200cr${RESET}"
    printf "  ${CYAN}${BOLD}[3]${RESET} ${WHITE}Lucky              ${lucky_label}\n"
    printf "      ${DIM}Boosts the odds on your next game roll${RESET}\n\n"

    local shield_label
    (( ITEM_SHIELD )) && shield_label="${RED}ACTIVE — only 1 allowed${RESET}" || shield_label="${YELLOW}1,800cr${RESET}"
    printf "  ${CYAN}${BOLD}[4]${RESET} ${WHITE}Shield             ${shield_label}\n"
    printf "      ${DIM}Blocks 50%% of your next losing result${RESET}\n\n"

    if (( ITEM_MAX_BET_LEVEL >= 4 )); then
        printf "  ${CYAN}${BOLD}[5]${RESET} ${WHITE}Max Bet Increase   ${DIM}(MAX LEVEL)${RESET}\n"
    else
        printf "  ${CYAN}${BOLD}[5]${RESET} ${WHITE}Max Bet Increase   ${YELLOW}%dcr${RESET}  ${DIM}%s${RESET}\n" \
            "$mbl_next_cost" "$mbl_next_label"
    fi
    printf "      ${DIM}Raise your bet ceiling — currently Lv%d${RESET}\n\n" "$ITEM_MAX_BET_LEVEL"

    printf "  ${CYAN}${BOLD}[q]${RESET} ${WHITE}Leave shop${RESET}\n\n"
    draw_footer
}


loot_crate_anim() {
    local tier="$1"
    local reward="$2"

    local color label border_char
    case "$tier" in
        common)   color="$WHITE";   label="COMMON";   border_char="─" ;;
        uncommon) color="$GREEN";   label="UNCOMMON"; border_char="═" ;;
        rare)     color="$CYAN";    label="RARE";     border_char="▓" ;;
        jackpot)  color="$MAGENTA"; label="JACKPOT";  border_char="★" ;;
    esac

    clear
    echo ""
    echo "  ${YELLOW}${BOLD}Opening Loot Crate…${RESET}"
    echo ""

    # Crate drawing
    local frames=(
        "  ${DIM}┌─────────┐\n  │  ?????  │\n  │  CRATE  │\n  └─────────┘${RESET}"
        "  ${YELLOW}┌─────────┐\n  │  ╔═══╗  │\n  │  ║ ? ║  │\n  └──╚═══╝──┘${RESET}"
        "  ${YELLOW}${BOLD}┌─────────┐\n  │░░░░░░░░░│\n  │░ CRACK ░│\n  └─────────┘${RESET}"
    )

    for frame in "${frames[@]}"; do
        clear
        echo ""
        echo "  ${YELLOW}${BOLD}Opening Loot Crate…${RESET}"
        echo ""
        printf "%b\n" "$frame"
        sleep 0.45
    done

    # Spinning reel
    local symbols=("♠" "♥" "♦" "♣" "★" "✦" "◆" "●")
    for (( i=0; i<14; i++ )); do
        local s="${symbols[$(( RANDOM % ${#symbols[@]} ))]}"
        local delay
        delay=$(awk "BEGIN{printf \"%.2f\", 0.04 + $i * 0.015}")
        printf "\r  ${color}${BOLD}  [ %s  %s  %s ]  ${RESET}" \
            "${symbols[$(( RANDOM % ${#symbols[@]} ))]}" \
            "$s" \
            "${symbols[$(( RANDOM % ${#symbols[@]} ))]}"
        sleep "$delay"
    done
    echo ""
    sleep 0.3

    # Reveal
    clear
    echo ""
    echo "  ${color}${BOLD}╔$(printf '%0.s'"$border_char" $(seq 1 30))╗${RESET}"
    printf "  ${color}${BOLD}║  %-27s║${RESET}\n" "  $label REWARD!"
    printf "  ${color}${BOLD}║  %-27s║${RESET}\n" "  +${reward} CREDITS"
    echo "  ${color}${BOLD}╚$(printf '%0.s'"$border_char" $(seq 1 30))╝${RESET}"
    echo ""

    if [[ "$tier" == "jackpot" ]]; then
        for (( i=0; i<3; i++ )); do
            printf "  ${MAGENTA}${BOLD}  ✦ ✦ ✦  J A C K P O T  ✦ ✦ ✦${RESET}\n"
            sleep 0.2
            printf "\r  ${YELLOW}${BOLD}  ★ ★ ★  J A C K P O T  ★ ★ ★${RESET}\n"
            sleep 0.2
        done
        echo ""
    fi

    sleep 1
}

open_loot_crate() {
    if (( CREDITS < 500 )); then
        echo ""
        echo "  ${RED}Not enough credits! (Need 500)${RESET}"
        sleep 1.2
        return
    fi

    CREDITS=$(( CREDITS - 500 ))
    save_state

    local roll=$(( RANDOM % 100 ))
    local tier reward
    if   (( roll < 1  )); then tier="jackpot";  reward=5000
    elif (( roll < 10 )); then tier="rare";     reward=1000
    elif (( roll < 40 )); then tier="uncommon"; reward=300
    else                       tier="common";   reward=100
    fi

    loot_crate_anim "$tier" "$reward"

    CREDITS=$(( CREDITS + reward ))
    save_state

    local net=$(( reward - 500 ))
    local net_str
    if (( net >= 0 )); then
        net_str="${GREEN}+${net}${RESET}"
    else
        net_str="${RED}${net}${RESET}"
    fi
    printf "  ${DIM}Net: %b credits  |  Balance: ${YELLOW}${BOLD}%d${RESET}\n" "$net_str" "$CREDITS"
    echo ""
    pause
}

buy_2x_win() {
    if (( ITEM_2X_WIN )); then
        echo ""
        echo "  ${RED}You already have 2x Win active!${RESET}"
        sleep 1.2; return
    fi
    if (( CREDITS < 2500 )); then
        echo ""
        echo "  ${RED}Not enough credits! (Need 2,500)${RESET}"
        sleep 1.2; return
    fi
    CREDITS=$(( CREDITS - 2500 ))
    ITEM_2X_WIN=1
    save_state
    flash_msg "2x Win ACTIVATED!" "$CYAN"
    sleep 0.6
}

buy_lucky() {
    if (( ITEM_LUCKY )); then
        echo ""
        echo "  ${RED}Lucky is already active!${RESET}"
        sleep 1.2; return
    fi
    if (( CREDITS < 1200 )); then
        echo ""
        echo "  ${RED}Not enough credits! (Need 1,200)${RESET}"
        sleep 1.2; return
    fi
    CREDITS=$(( CREDITS - 1200 ))
    ITEM_LUCKY=1
    save_state
    flash_msg "Lucky ACTIVATED!" "$GREEN"
    sleep 0.6
}

buy_shield() {
    if (( ITEM_SHIELD )); then
        echo ""
        echo "  ${RED}Shield is already active!${RESET}"
        sleep 1.2; return
    fi
    if (( CREDITS < 1800 )); then
        echo ""
        echo "  ${RED}Not enough credits! (Need 1,800)${RESET}"
        sleep 1.2; return
    fi
    CREDITS=$(( CREDITS - 1800 ))
    ITEM_SHIELD=1
    save_state
    flash_msg "Shield ACTIVATED!" "$BLUE"
    sleep 0.6
}

buy_max_bet() {
    if (( ITEM_MAX_BET_LEVEL >= 4 )); then
        echo ""
        echo "  ${RED}Max Bet is already at maximum level!${RESET}"
        sleep 1.2; return
    fi

    local costs=(100 1000 10000 100000)
    local cost="${costs[$ITEM_MAX_BET_LEVEL]}"

    if (( CREDITS < cost )); then
        echo ""
        printf "  ${RED}Not enough credits! (Need %d)${RESET}\n" "$cost"
        sleep 1.2; return
    fi

    CREDITS=$(( CREDITS - cost ))
    ITEM_MAX_BET_LEVEL=$(( ITEM_MAX_BET_LEVEL + 1 ))
    save_state
    flash_msg "Max Bet → Level ${ITEM_MAX_BET_LEVEL}!" "$ORANGE"
    sleep 0.6
}


main() {
    load_state

    clear
    echo "${CYAN}${BOLD}"
    echo "  ╔═════════════════════════════╗"
    echo "  ║        AURA  SHOP           ║"
    echo "  ║     Aura Gambling Suite     ║"
    echo "  ╚═════════════════════════════╝"
    echo "${RESET}"
    sleep 0.8

    while true; do
        draw_shop
        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        case "$choice" in
            1) open_loot_crate ;;
            2) buy_2x_win ;;
            3) buy_lucky ;;
            4) buy_shield ;;
            5) buy_max_bet ;;
            q)
                save_state
                echo ""
                echo "  ${CYAN}Thanks for shopping! Credits: ${BOLD}${CREDITS}${RESET}"
                echo ""
                break
                ;;
            *)
                echo "  ${DIM}Unknown option.${RESET}"
                sleep 0.5
                ;;
        esac
    done
}

main "$@"
