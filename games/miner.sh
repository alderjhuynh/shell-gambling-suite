#!/usr/bin/env bash

SAVEFILE="$HOME/aura_gambling_suite_bash.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PASSIVE_CREDIT_AMOUNT=10
PASSIVE_CREDIT_INTERVAL=300
PASSIVE_CREDIT_CAP=100

MINE_REWARD_NUM=1
MINE_REWARD_DEN=4
MINE_COOLDOWN=2


RESET=$'\033[0m'
BOLD=$'\033[1m'
YELLOW=$'\033[93m'
CYAN=$'\033[96m'
GREEN=$'\033[92m'
RED=$'\033[91m'
WHITE=$'\033[97m'
MAGENTA=$'\033[95m'
DIM=$'\033[2m'

WIDTH=54


hr() {
    local char="${1:-═}"
    printf '%0.s'"$char" $(seq 1 $WIDTH)
}

box_line() {
    local text="$1"
    local plain
    plain=$(printf '%s' "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#plain}
    local pad=$(( WIDTH - len - 2 ))   # -2 for the two spaces of indent
    printf '%s%s%*s\n' "  " "$text" "$pad" ""
}


ORE_SPRITES=(
    "    ${DIM}╔══════════════════════════════════════════════╗${RESET}"
    "    ${DIM}║  ████████████████████████████████████████  ║${RESET}"
    "    ${DIM}║  ████████████████████████████████████████  ║${RESET}"
    "    ${DIM}║  ████████████████████████████████████████  ║${RESET}"
    "    ${DIM}╚══════════════════════════════════════════════╝${RESET}"

    "    ${YELLOW}╔══════════════════════════════════════════════╗${RESET}"
    "    ${YELLOW}║  ███████████▒▒██████████████▒▒███████████  ║${RESET}"
    "    ${YELLOW}║  █████████████████▒▒█████████████████████  ║${RESET}"
    "    ${YELLOW}║  ███████████▒▒██████████████▒▒███████████  ║${RESET}"
    "    ${YELLOW}╚══════════════════════════════════════════════╝${RESET}"

    "    ${YELLOW}╔══════════════════════════════════════════════╗${RESET}"
    "    ${YELLOW}║  █████▒▒▒▒██████▒▒▒▒██████▒▒▒▒███████  ║${RESET}"
    "    ${YELLOW}║  ███▒▒░░▒▒████▒▒░░▒▒████▒▒░░▒▒███████  ║${RESET}"
    "    ${YELLOW}║  █████▒▒▒▒██████▒▒▒▒██████▒▒▒▒███████  ║${RESET}"
    "    ${YELLOW}╚══════════════════════════════════════════════╝${RESET}"

    "    ${RED}╔══════════════════════════════════════════════╗${RESET}"
    "    ${RED}║  ░░░░▒▒░░░░░░▒▒░░░░░░▒▒░░░░░░▒▒░░░░░░  ║${RESET}"
    "    ${RED}║  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║${RESET}"
    "    ${RED}║  ░░░░▒▒░░░░░░▒▒░░░░░░▒▒░░░░░░▒▒░░░░░░  ║${RESET}"
    "    ${RED}╚══════════════════════════════════════════════╝${RESET}"
)

ore_sprite_index() {
    local frac="$1"   # 0–3
    echo $(( frac * 5 ))
}

draw_screen() {
    local status_msg="$1"
    local now
    now=$(date +%s)

    local ttl=$(( NEXT_CREDIT_TIME - now ))
    (( ttl < 0 )) && ttl=0
    local pm=$(( ttl / 60 )) ps=$(( ttl % 60 ))
    local ptimer
    printf -v ptimer "%dm %02ds" "$pm" "$ps"

    local mine_ttl=$(( NEXT_MINE_TIME - now ))
    (( mine_ttl < 0 )) && mine_ttl=0

    local cred_display
    if (( CREDITS_FRAC > 0 )); then
        printf -v cred_display "%d.%s" "$CREDITS" \
            "$(( CREDITS_FRAC * 25 ))"
    else
        printf -v cred_display "%d" "$CREDITS"
    fi

    local sprite_idx
    sprite_idx=$(ore_sprite_index "$CREDITS_FRAC")

    clear

    echo "${YELLOW}${BOLD}╔$(hr)╗${RESET}"
    echo "${YELLOW}${BOLD}║   O R E   M I N E R$(printf '%*s' $(( WIDTH - 22 )) '')║${RESET}"
    echo "${YELLOW}${BOLD}║  ${DIM}Aura Gambling Suite${RESET}$(printf '%*s' $(( WIDTH - 20 )) '')${YELLOW}${BOLD}║${RESET}"
    echo "${YELLOW}${BOLD}╠$(hr)╣${RESET}"
    printf "${YELLOW}${BOLD}║${RESET}  ${YELLOW}Credits: ${BOLD}%s${RESET}   ${CYAN}Mined: ${BOLD}%d ore${RESET}   ${DIM}+%d in %s${RESET}\n" \
        "$cred_display" "$TOTAL_ORE_MINED" "$PASSIVE_CREDIT_AMOUNT" "$ptimer"
    printf "${YELLOW}${BOLD}║${RESET}  ${DIM}Items:${RESET} 2x: %-3s Lucky: %-3s Shield: %-3s\n" \
        "$( (( ITEM_2X_WIN )) && echo ON || echo off )" \
        "$( (( ITEM_LUCKY )) && echo ON || echo off )" \
        "$( (( ITEM_SHIELD )) && echo ON || echo off )"
    echo "${YELLOW}${BOLD}╠$(hr)╣${RESET}"

    # Ore art
    for (( row=0; row<5; row++ )); do
        echo "${ORE_SPRITES[$(( sprite_idx + row ))]}"
    done

    echo "${YELLOW}${BOLD}╠$(hr ─)╣${RESET}"

    if (( mine_ttl > 0 )); then
        printf "  ${DIM}Cooldown: ${BOLD}%ds${RESET}  —  ${DIM}ore regenerating…${RESET}\n" "$mine_ttl"
        printf "  ${WHITE}[ENTER] check   [q] quit${RESET}\n"
    else
        printf "  ${GREEN}${BOLD}✦ Ore ready! Press ENTER to mine.${RESET}\n"
        printf "  ${WHITE}[ENTER] mine   [q] quit${RESET}\n"
    fi

    [[ -n "$status_msg" ]] && printf "  %s\n" "$status_msg"

    echo "${YELLOW}${BOLD}╠$(hr)╣${RESET}"
    printf "  ${DIM}Each swing yields ${BOLD}0.25 credits${RESET}${DIM} · 4 swings = 1 credit${RESET}\n"
    echo "${YELLOW}${BOLD}╚$(hr)╝${RESET}"
}

flash_mine() {
    local msg="$1" color="$2"
    for c in "$color" "$WHITE" "$color" "$WHITE" "$color"; do
        printf "\r  %s%s%s   " "$c" "${BOLD}${msg}${RESET}" "$RESET"
        sleep 0.10
    done
    echo
}

main() {
    load_state

    PENDING_BONUS=0

    while true; do
        check_passive_credits

        local now
        now=$(date +%s)

        local status_msg=""
        if (( PENDING_BONUS > 0 )); then
            status_msg="${CYAN}${BOLD}+${PENDING_BONUS} FREE CREDITS!${RESET}"
            PENDING_BONUS=0
        fi

        local mine_ttl=$(( NEXT_MINE_TIME - now ))
        (( mine_ttl < 0 )) && mine_ttl=0

        draw_screen "$status_msg"

        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        case "$choice" in
            q)
                save_state
                echo ""
                echo "  ${CYAN}CREDITS: ${BOLD}${CREDITS}${RESET}  (${CREDITS_FRAC}/4 quarters pending)"
                echo "  ${CYAN}Total ore mined: ${BOLD}${TOTAL_ORE_MINED}${RESET}"
                echo ""
                break
                ;;
            "")
                now=$(date +%s)
                if (( now < NEXT_MINE_TIME )); then
                    local wait=$(( NEXT_MINE_TIME - now ))
                    draw_screen "${DIM}Still cooling down — ${wait}s left…${RESET}"
                    sleep 0.5
                    continue
                fi

                NEXT_MINE_TIME=$(( now + MINE_COOLDOWN ))
                TOTAL_ORE_MINED=$(( TOTAL_ORE_MINED + 1 ))

                local reward_quarters="$MINE_REWARD_NUM"
                local item_status=""
                if consume_lucky; then
                    reward_quarters=$(( reward_quarters + 1 ))
                    item_status="${GREEN}Lucky boosted this mine by +0.25.${RESET}"
                fi

                CREDITS_FRAC=$(( CREDITS_FRAC + reward_quarters ))
                if (( CREDITS_FRAC >= MINE_REWARD_DEN )); then
                    CREDITS=$(( CREDITS + CREDITS_FRAC / MINE_REWARD_DEN ))
                    CREDITS_FRAC=$(( CREDITS_FRAC % MINE_REWARD_DEN ))
                fi

                if (( ITEM_2X_WIN )); then
                    CREDITS_FRAC=$(( CREDITS_FRAC + reward_quarters ))
                    if (( CREDITS_FRAC >= MINE_REWARD_DEN )); then
                        CREDITS=$(( CREDITS + CREDITS_FRAC / MINE_REWARD_DEN ))
                        CREDITS_FRAC=$(( CREDITS_FRAC % MINE_REWARD_DEN ))
                    fi
                    ITEM_2X_WIN=0
                    item_status="${CYAN}2x Win doubled this mine reward.${RESET}"
                    save_state
                fi

                PASSIVE_EARNED=0
                save_state

                draw_screen "${GREEN}${BOLD}Mined ore.${RESET} ${item_status}"
                sleep 0.3
                ;;
        esac
    done
}

main "$@"
