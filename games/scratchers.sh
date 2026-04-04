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

TICKET_1_NAME="Lucky Penny"
TICKET_1_COST=10
TICKET_1_COLOR="$CYAN"
TICKET_1_ROWS=2
TICKET_1_COLS=3
TICKET_1_SYMBOLS="Cl Mo St Di Be"   # 🍀 💰 ⭐ 🎲 🔔 
TICKET_1_DESC="6 squares  match 3=1.1x  match 2=0.6x"
TICKET_1_PAY_3=110
TICKET_1_PAY_2=60

TICKET_2_NAME="Gold Rush"
TICKET_2_COST=25
TICKET_2_COLOR="$YELLOW"
TICKET_2_ROWS=3
TICKET_2_COLS=4
TICKET_2_SYMBOLS="Dm Tr Sl St 7s Tg"
TICKET_2_DESC="12 squares  match 4=1.5x  3=1x  2=0.5x"
TICKET_2_PAY_4=150
TICKET_2_PAY_3=100
TICKET_2_PAY_2=50

TICKET_3_NAME="Midnight Jackpot"
TICKET_3_COST=50
TICKET_3_COLOR="$MAGENTA"
TICKET_3_ROWS=3
TICKET_3_COLS=5
TICKET_3_SYMBOLS="Dm Jk Fw Cr Mn Om Bl"
TICKET_3_DESC="15 squares  match 5=2x  4=1.2x  3=0.6x  2=0.3x"
TICKET_3_PAY_5=200
TICKET_3_PAY_4=120
TICKET_3_PAY_3=60
TICKET_3_PAY_2=30


load_state() {
    CREDITS=100
    PASSIVE_EARNED=0
    NEXT_CREDIT_TIME=$(( $(date +%s) + PASSIVE_CREDIT_INTERVAL ))

    if [[ -f "$SAVEFILE" ]]; then
        while IFS='=' read -r key val; do
            case "$key" in
                credits)           CREDITS=$val ;;
                passive_earned)    PASSIVE_EARNED=$val ;;
                next_credit_time)  NEXT_CREDIT_TIME=$val ;;
            esac
        done < "$SAVEFILE"

        (( PASSIVE_EARNED < 0 )) && PASSIVE_EARNED=0
        (( PASSIVE_EARNED > PASSIVE_CREDIT_CAP )) && PASSIVE_EARNED=$PASSIVE_CREDIT_CAP

        local NOW
        NOW=$(date +%s)
        if (( NEXT_CREDIT_TIME <= NOW )); then
            local MISSED POTENTIAL ALLOWED GAIN
            MISSED=$(( (NOW - NEXT_CREDIT_TIME) / PASSIVE_CREDIT_INTERVAL + 1 ))
            POTENTIAL=$(( MISSED * PASSIVE_CREDIT_AMOUNT ))
            ALLOWED=$(( PASSIVE_CREDIT_CAP - PASSIVE_EARNED ))
            (( ALLOWED < 0 )) && ALLOWED=0
            GAIN=$(( POTENTIAL < ALLOWED ? POTENTIAL : ALLOWED ))
            CREDITS=$(( CREDITS + GAIN ))
            PASSIVE_EARNED=$(( PASSIVE_EARNED + GAIN ))
            NEXT_CREDIT_TIME=$(( NOW + PASSIVE_CREDIT_INTERVAL ))
        fi
    fi
}

save_state() {
    printf 'credits=%d\npassive_earned=%d\nnext_credit_time=%d\n' \
        "$CREDITS" "$PASSIVE_EARNED" "$NEXT_CREDIT_TIME" > "$SAVEFILE"
}

check_passive_credits() {
    local NOW
    NOW=$(date +%s)
    if (( NOW >= NEXT_CREDIT_TIME )); then
        if (( PASSIVE_EARNED < PASSIVE_CREDIT_CAP )); then
            local AVAIL GAIN
            AVAIL=$(( PASSIVE_CREDIT_CAP - PASSIVE_EARNED ))
            GAIN=$(( PASSIVE_CREDIT_AMOUNT < AVAIL ? PASSIVE_CREDIT_AMOUNT : AVAIL ))
            CREDITS=$(( CREDITS + GAIN ))
            PASSIVE_EARNED=$(( PASSIVE_EARNED + GAIN ))
            PENDING_BONUS=$(( PENDING_BONUS + GAIN ))
        fi
        NEXT_CREDIT_TIME=$(( NOW + PASSIVE_CREDIT_INTERVAL ))
        save_state
    fi
}

generate_ticket() {
    local rows=$1 cols=$2
    shift 2
    local symbols=("$@")
    local total=$(( rows * cols ))
    local nsym=${#symbols[@]}

    local roll=$(( RANDOM % 1000 ))
    local win_count=0
    if   (( roll < 2  )); then win_count=5
    elif (( roll < 8  )); then win_count=4
    elif (( roll < 30 )); then win_count=3
    elif (( roll < 80 )); then win_count=2
    fi

    GRID_FLAT=()
    local i
    for (( i=0; i<total; i++ )); do
        GRID_FLAT+=( "${symbols[$(( RANDOM % nsym ))]}" )
    done

    if (( win_count >= 2 )); then
        local chosen_sym="${symbols[$(( RANDOM % nsym ))]}"

        local others=()
        local s
        for s in "${symbols[@]}"; do
            [[ "$s" != "$chosen_sym" ]] && others+=("$s")
        done
        (( ${#others[@]} == 0 )) && others=("${symbols[@]}")

        local positions=()
        local pos_used
        declare -A pos_used
        while (( ${#positions[@]} < win_count )); do
            local p=$(( RANDOM % total ))
            if [[ -z "${pos_used[$p]}" ]]; then
                pos_used[$p]=1
                positions+=("$p")
            fi
        done

        for (( i=0; i<total; i++ )); do
            local is_win=0
            local p
            for p in "${positions[@]}"; do
                (( p == i )) && is_win=1 && break
            done
            if (( is_win )); then
                GRID_FLAT[$i]="$chosen_sym"
            else
                GRID_FLAT[$i]="${others[$(( RANDOM % ${#others[@]} ))]}"
            fi
        done
    fi
}


evaluate_ticket() {
    declare -A counts
    local s
    for s in "${GRID_FLAT[@]}"; do
        counts[$s]=$(( ${counts[$s]:-0} + 1 ))
    done

    BEST_COUNT=0
    BEST_SYM=""
    for s in "${!counts[@]}"; do
        if (( counts[$s] > BEST_COUNT )); then
            BEST_COUNT=${counts[$s]}
            BEST_SYM=$s
        fi
    done
}


fmt_time() {
    local total=$1
    (( total < 0 )) && total=0
    local m=$(( total / 60 )) s=$(( total % 60 ))
    printf '%dm %02ds' "$m" "$s"
}

timer_str() {
    local now ttl
    now=$(date +%s)
    ttl=$(( NEXT_CREDIT_TIME - now ))
    fmt_time "$ttl"
}

draw_header() {
    local color="$1" name="$2"
    printf '%s%s╔══════════════════════════════════════════╗%s\n' "$color" "$BOLD" "$RESET"
    printf '%s%s║                SCRATCHERS                ║%s\n' "$color" "$BOLD" "$RESET"
    printf '%s%s║            Aura Gambling Suite           ║%s\n' "$color" "$BOLD" "$RESET"
    printf '%s%s╠══════════════════════════════════════════╣%s\n' "$color" "$BOLD" "$RESET"
    printf '%s%s║%s  %sCredits: %s%d%s   %s+%d in %s%s\n' \
        "$color" "$BOLD" "$RESET" \
        "$YELLOW" "$BOLD" "$CREDITS" "$RESET" \
        "$DIM" "$PASSIVE_CREDIT_AMOUNT" "$(timer_str)" "$RESET"
    printf '%s%s║%s  %s%sTicket: %s%s\n' \
        "$color" "$BOLD" "$RESET" "$color" "$BOLD" "$name" "$RESET"
    printf '%s%s╠══════════════════════════════════════════╣%s\n' "$color" "$BOLD" "$RESET"
}

draw_footer() {
    local color="$1"
    printf '%s%s╚══════════════════════════════════════════╝%s\n' "$color" "$BOLD" "$RESET"
}

draw_grid() {
    local rows=$1 cols=$2 color=$3 win_sym=$4 show_win=$5
    local total=$(( rows * cols ))
    local r c idx

    for (( r=0; r<rows; r++ )); do
        printf '  %s%s│%s  ' "$color" "$BOLD" "$RESET"
        for (( c=0; c<cols; c++ )); do
            idx=$(( r * cols + c ))
            local sym="${GRID_FLAT[$idx]}"
            local is_revealed=0
            local rv
            for rv in "${REVEALED[@]}"; do
                (( rv == idx )) && is_revealed=1 && break
            done

            if (( is_revealed )); then
                if [[ "$show_win" == "1" && "$sym" == "$win_sym" ]]; then
                    printf '%s%s%-4s%s' "$GREEN" "$BOLD" "$sym" "$RESET"
                else
                    printf '%s%-4s%s' "$WHITE" "$sym" "$RESET"
                fi
            else
                printf '%s##  %s' "$DIM" "$RESET"
            fi
        done
        printf '%s%s│%s\n' "$color" "$BOLD" "$RESET"
    done
}

draw_scratch_ui() {
    local rows=$1 cols=$2 color=$3 name=$4 message=$5 win_sym=$6 show_win=$7
    local total=$(( rows * cols ))
    local done_count=${#REVEALED[@]}

    clear
    draw_header "$color" "$name"
    echo
    draw_grid "$rows" "$cols" "$color" "$win_sym" "$show_win"
    echo
    if [[ -n "$message" ]]; then
        printf '  %s\n' "$message"
    else
        local remaining=$(( total - done_count ))
        if (( remaining > 0 )); then
            printf '  %sScratched %d/%d — %d left%s\n' "$WHITE" "$done_count" "$total" "$remaining" "$RESET"
        else
            printf '  %sAll squares revealed!%s\n' "$WHITE" "$RESET"
        fi
    fi
    echo
    draw_footer "$color"
}

animate_reveal() {
    local rows=$1 cols=$2 color=$3 name=$4 target_idx=$5
    local frames=("##" "%%")
    local sym="${GRID_FLAT[$target_idx]}"
    local frame

    for frame in "${frames[@]}" "$sym"; do
        clear
        draw_header "$color" "$name"
        echo

        local r c idx
        for (( r=0; r<rows; r++ )); do
            printf '  %s%s│%s  ' "$color" "$BOLD" "$RESET"
            for (( c=0; c<cols; c++ )); do
                idx=$(( r * cols + c ))
                local is_revealed=0
                local rv
                for rv in "${REVEALED[@]}"; do
                    (( rv == idx )) && is_revealed=1 && break
                done

                if (( idx == target_idx )); then
                    printf '%s%-4s%s' "$WHITE" "$frame" "$RESET"
                elif (( is_revealed )); then
                    printf '%s%-4s%s' "$WHITE" "${GRID_FLAT[$idx]}" "$RESET"
                else
                    printf '%s##  %s' "$DIM" "$RESET"
                fi
            done
            printf '%s%s│%s\n' "$color" "$BOLD" "$RESET"
        done

        echo
        draw_footer "$color"
        sleep 0.07
    done
}

scratch_ticket() {
    local rows=$1 cols=$2 color=$3 name=$4
    shift 4

    local total=$(( rows * cols ))
    REVEALED=()

    draw_scratch_ui "$rows" "$cols" "$color" "$name" \
        "${WHITE}[ENTER] scratch next  [a] scratch all  [q] quit${RESET}" "" "0"

    while (( ${#REVEALED[@]} < total )); do
        local choice
        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        case "$choice" in
            q)
                local i
                for (( i=0; i<total; i++ )); do
                    local already=0
                    local rv
                    for rv in "${REVEALED[@]}"; do (( rv == i )) && already=1 && break; done
                    (( already )) || REVEALED+=("$i")
                done
                draw_scratch_ui "$rows" "$cols" "$color" "$name" \
                    "${DIM}Skipped remaining…${RESET}" "" "0"
                sleep 0.5
                break
                ;;
            a)
                local i
                for (( i=0; i<total; i++ )); do
                    local already=0
                    local rv
                    for rv in "${REVEALED[@]}"; do (( rv == i )) && already=1 && break; done
                    if (( ! already )); then
                        animate_reveal "$rows" "$cols" "$color" "$name" "$i"
                        REVEALED+=("$i")
                        draw_scratch_ui "$rows" "$cols" "$color" "$name" "" "" "0"
                        sleep 0.05
                    fi
                done
                break
                ;;
            *)
                local i
                for (( i=0; i<total; i++ )); do
                    local already=0
                    local rv
                    for rv in "${REVEALED[@]}"; do (( rv == i )) && already=1 && break; done
                    if (( ! already )); then
                        animate_reveal "$rows" "$cols" "$color" "$name" "$i"
                        REVEALED+=("$i")
                        draw_scratch_ui "$rows" "$cols" "$color" "$name" \
                            "${WHITE}[ENTER] scratch next  [a] scratch all  [q] quit${RESET}" "" "0"
                        break
                    fi
                done
                ;;
        esac
    done

    evaluate_ticket

    WINNINGS=0
    WIN_LABEL=""
    local cost
    cost=$TICKET_COST

    local k v mult
    for k in "${PAYTABLE_KEYS[@]}"; do
        if (( BEST_COUNT >= k )); then
            local idx2=0
            local kk
            for kk in "${PAYTABLE_KEYS[@]}"; do
                [[ "$kk" == "$k" ]] && break
                (( idx2++ ))
            done
            mult="${PAYTABLE_VALS[$idx2]}"
            WINNINGS=$(( cost * mult / 100 ))
            WIN_LABEL="${BEST_COUNT} x ${BEST_SYM}"
            break
        fi
    done

    draw_scratch_ui "$rows" "$cols" "$color" "$name" "" \
        "$( (( WINNINGS > 0 )) && echo "$BEST_SYM" || echo "" )" \
        "$( (( WINNINGS > 0 )) && echo "1" || echo "0" )"
}

flash_result() {
    local msg="$1" color="$2"
    local c
    for c in "$color" "$WHITE" "$color" "$WHITE" "$color" "$WHITE"; do
        printf '\r  %s%s✨  %s  ✨%s   ' "$c" "$BOLD" "$msg" "$RESET"
        sleep 0.13
    done
    echo
}

draw_shop() {
    clear
    local now ttl
    now=$(date +%s)
    ttl=$(( NEXT_CREDIT_TIME - now ))

    printf '%s%s╔══════════════════════════════════════════╗%s\n' "$YELLOW" "$BOLD" "$RESET"
    printf '%s%s║                SCRATCHERS                ║%s\n' "$YELLOW" "$BOLD" "$RESET"
    printf '%s%s║            Aura Gambling Suite           ║%s\n' "$YELLOW" "$BOLD" "$RESET"
    printf '%s%s╠══════════════════════════════════════════╣%s\n' "$YELLOW" "$BOLD" "$RESET"
    printf '%s%s║%s  %sCredits: %s%d%s   %s+%d in %s%s\n' \
        "$YELLOW" "$BOLD" "$RESET" \
        "$YELLOW" "$BOLD" "$CREDITS" "$RESET" \
        "$DIM" "$PASSIVE_CREDIT_AMOUNT" "$(fmt_time "$ttl")" "$RESET"
    printf '%s%s╠══════════════════════════════════════════╣%s\n' "$YELLOW" "$BOLD" "$RESET"
    printf '%s%s║%s\n' "$YELLOW" "$BOLD" "$RESET"

    local id
    for id in 1 2 3; do
        local tname tcost tcolor tdesc
        eval "tname=\$TICKET_${id}_NAME"
        eval "tcost=\$TICKET_${id}_COST"
        eval "tcolor=\$TICKET_${id}_COLOR"
        eval "tdesc=\$TICKET_${id}_DESC"

        local afford_color
        (( CREDITS >= tcost )) && afford_color="$GREEN" || afford_color="$RED"

        printf '%s%s║%s  %s%s[%d]%s %s%s%s%s — %s%d credits%s\n' \
            "$YELLOW" "$BOLD" "$RESET" \
            "$afford_color" "$BOLD" "$id" "$RESET" \
            "$tcolor" "$BOLD" "$tname" "$RESET" \
            "$CYAN" "$tcost" "$RESET"
        printf '%s%s║%s      %s%s%s\n' \
            "$YELLOW" "$BOLD" "$RESET" "$DIM" "$tdesc" "$RESET"
        printf '%s%s║%s\n' "$YELLOW" "$BOLD" "$RESET"
    done

    printf '%s%s╠══════════════════════════════════════════╣%s\n' "$YELLOW" "$BOLD" "$RESET"
    printf '%s%s╚══════════════════════════════════════════╝%s\n' "$YELLOW" "$BOLD" "$RESET"
    echo
}

main() {
    load_state
    PENDING_BONUS=0

    while true; do
        check_passive_credits

        if (( PENDING_BONUS > 0 )); then
            echo
            printf '  %s%s+%d FREE CREDITS!%s\n' "$CYAN" "$BOLD" "$PENDING_BONUS" "$RESET"
            echo
            PENDING_BONUS=0
            sleep 1
        fi

        draw_shop

        if (( CREDITS <= 0 )); then
            printf '  %s%sOUT OF CREDITS — wait for your free bonus!%s\n\n' "$RED" "$BOLD" "$RESET"
            read -r -p "  [ENTER] check again  [q] quit: " ans
            ans=$(printf '%s' "$ans" | tr '[:upper:]' '[:lower:]')
            [[ "$ans" == "q" ]] && break
            continue
        fi

        printf '  %s[1/2/3] Buy ticket   [q] Quit%s\n' "$WHITE" "$RESET"
        read -r -p "  > " choice
        choice=$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')

        check_passive_credits
        if (( PENDING_BONUS > 0 )); then
            echo
            printf '  %s%s+%d FREE CREDITS!%s\n' "$CYAN" "$BOLD" "$PENDING_BONUS" "$RESET"
            echo
            PENDING_BONUS=0
        fi

        case "$choice" in
            q)
                save_state
                echo
                printf '  %sFINAL CREDITS: %s%d%s\n\n' "$CYAN" "$BOLD" "$CREDITS" "$RESET"
                break
                ;;
            1|2|3)
                local trows tcols tcost tcolor tname tsymbols_str
                eval "trows=\$TICKET_${choice}_ROWS"
                eval "tcols=\$TICKET_${choice}_COLS"
                eval "tcost=\$TICKET_${choice}_COST"
                eval "tcolor=\$TICKET_${choice}_COLOR"
                eval "tname=\$TICKET_${choice}_NAME"
                eval "tsymbols_str=\$TICKET_${choice}_SYMBOLS"

                if (( tcost > CREDITS )); then
                    echo
                    printf '  %sNot enough credits for %s (%d needed).%s\n\n' \
                        "$RED" "$tname" "$tcost" "$RESET"
                    sleep 1.2
                    continue
                fi

                CREDITS=$(( CREDITS - tcost ))
                PASSIVE_EARNED=0
                save_state

                local tsymbols=()
                local sym
                for sym in $tsymbols_str; do
                    tsymbols+=("$sym")
                done

                PAYTABLE_KEYS=()
                PAYTABLE_VALS=()
                local k v
                case "$choice" in
                    1)
                        PAYTABLE_KEYS=(3 2)
                        PAYTABLE_VALS=(110 60)
                        ;;
                    2)
                        PAYTABLE_KEYS=(4 3 2)
                        PAYTABLE_VALS=(150 100 50)
                        ;;
                    3)
                        PAYTABLE_KEYS=(5 4 3 2)
                        PAYTABLE_VALS=(200 120 60 30)
                        ;;
                esac

                generate_ticket "$trows" "$tcols" "${tsymbols[@]}"

                TICKET_COST=$tcost
                REVEALED=()
                scratch_ticket "$trows" "$tcols" "$tcolor" "$tname"

                CREDITS=$(( CREDITS + WINNINGS ))
                save_state

                if (( WINNINGS > 0 )); then
                    local net=$(( WINNINGS - tcost ))
                    local net_str
                    (( net >= 0 )) && net_str="+${net}" || net_str="$net"
                    if (( WINNINGS >= tcost * 50 )); then
                        flash_result \
                            "JACKPOT! ${WIN_LABEL}  ·  ${WINNINGS} CREDITS  (net ${net_str})" \
                            "$tcolor"
                    else
                        printf '  %s%sWINNER! %s  ·  +%d credits  (net %s)%s\n' \
                            "$GREEN" "$BOLD" "$WIN_LABEL" "$WINNINGS" "$net_str" "$RESET"
                    fi
                else
                    printf '  %sNo match (-%d credits)%s\n' "$RED" "$tcost" "$RESET"
                fi

                echo
                sleep 0.4
                read -r -p "  ${DIM}[ENTER] back to shop…${RESET}"
                ;;
        esac
    done
}

main "$@"