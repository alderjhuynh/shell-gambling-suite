#!/usr/bin/env bash

SAVEFILE="${SAVEFILE:-$HOME/aura_gambling_suite_bash.txt}"

PASSIVE_CREDIT_AMOUNT="${PASSIVE_CREDIT_AMOUNT:-10}"
PASSIVE_CREDIT_INTERVAL="${PASSIVE_CREDIT_INTERVAL:-300}"
PASSIVE_CREDIT_CAP="${PASSIVE_CREDIT_CAP:-100}"

init_shared_state() {
    CREDITS=100
    PASSIVE_EARNED=0
    NEXT_CREDIT_TIME=$(( $(date +%s) + PASSIVE_CREDIT_INTERVAL ))

    ITEM_2X_WIN=0
    ITEM_LUCKY=0
    ITEM_SHIELD=0
    ITEM_MAX_BET_LEVEL=0

    NEXT_MINE_TIME=0
    CREDITS_FRAC=0
    TOTAL_ORE_MINED=0
}

normalize_shared_state() {
    (( CREDITS < 0 )) && CREDITS=0
    (( PASSIVE_EARNED < 0 )) && PASSIVE_EARNED=0
    (( PASSIVE_EARNED > PASSIVE_CREDIT_CAP )) && PASSIVE_EARNED=$PASSIVE_CREDIT_CAP
    (( ITEM_2X_WIN != 0 )) && ITEM_2X_WIN=1
    (( ITEM_LUCKY != 0 )) && ITEM_LUCKY=1
    (( ITEM_SHIELD != 0 )) && ITEM_SHIELD=1
    (( ITEM_MAX_BET_LEVEL < 0 )) && ITEM_MAX_BET_LEVEL=0
    (( ITEM_MAX_BET_LEVEL > 4 )) && ITEM_MAX_BET_LEVEL=4
    (( NEXT_MINE_TIME < 0 )) && NEXT_MINE_TIME=0
    (( CREDITS_FRAC < 0 )) && CREDITS_FRAC=0
}

sync_passive_credits() {
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
}

load_state() {
    init_shared_state

    if [[ -f "$SAVEFILE" ]]; then
        while IFS='=' read -r key val; do
            case "$key" in
                credits)            CREDITS=$val ;;
                passive_earned)     PASSIVE_EARNED=$val ;;
                next_credit_time)   NEXT_CREDIT_TIME=$val ;;
                item_2x_win)        ITEM_2X_WIN=$val ;;
                item_lucky)         ITEM_LUCKY=$val ;;
                item_shield)        ITEM_SHIELD=$val ;;
                item_max_bet_level) ITEM_MAX_BET_LEVEL=$val ;;
                next_mine_time)     NEXT_MINE_TIME=$val ;;
                credits_frac)       CREDITS_FRAC=$val ;;
                total_ore_mined)    TOTAL_ORE_MINED=$val ;;
            esac
        done < "$SAVEFILE"
    fi

    normalize_shared_state
    sync_passive_credits
}

save_state() {
    {
        printf 'credits=%d\n' "$CREDITS"
        printf 'passive_earned=%d\n' "$PASSIVE_EARNED"
        printf 'next_credit_time=%d\n' "$NEXT_CREDIT_TIME"
        printf 'item_2x_win=%d\n' "$ITEM_2X_WIN"
        printf 'item_lucky=%d\n' "$ITEM_LUCKY"
        printf 'item_shield=%d\n' "$ITEM_SHIELD"
        printf 'item_max_bet_level=%d\n' "$ITEM_MAX_BET_LEVEL"
        printf 'next_mine_time=%d\n' "$NEXT_MINE_TIME"
        printf 'credits_frac=%d\n' "$CREDITS_FRAC"
        printf 'total_ore_mined=%d\n' "$TOTAL_ORE_MINED"
    } > "$SAVEFILE"
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

consume_lucky() {
    if (( ITEM_LUCKY )); then
        ITEM_LUCKY=0
        save_state
        return 0
    fi
    return 1
}

apply_payout_items() {
    local stake="$1"
    local payout="$2"
    ITEM_USED_2X=0
    ITEM_USED_SHIELD=0
    ITEM_SHIELD_BLOCKED=0
    ITEM_NOTE=""

    FINAL_PAYOUT=$payout

    if (( payout > stake && ITEM_2X_WIN )); then
        FINAL_PAYOUT=$(( payout * 2 ))
        ITEM_2X_WIN=0
        ITEM_USED_2X=1
        ITEM_NOTE="2x Win doubled the payout."
    elif (( payout < stake && ITEM_SHIELD )); then
        local loss blocked
        loss=$(( stake - payout ))
        blocked=$(( loss / 2 ))
        FINAL_PAYOUT=$(( payout + blocked ))
        ITEM_SHIELD=0
        ITEM_USED_SHIELD=1
        ITEM_SHIELD_BLOCKED=$blocked
        ITEM_NOTE="Shield blocked ${blocked} credits."
    fi

    if (( ITEM_USED_2X || ITEM_USED_SHIELD )); then
        save_state
    fi
}

current_max_bet_limit() {
    local fallback="$1"
    local limit="$fallback"

    case "$ITEM_MAX_BET_LEVEL" in
        1) (( limit < 500 )) && limit=500 ;;
        2) (( limit < 1000 )) && limit=1000 ;;
        3) (( limit < 10000 )) && limit=10000 ;;
        4) (( limit < 100000 )) && limit=100000 ;;
    esac

    (( limit > CREDITS )) && limit=$CREDITS
    printf '%d\n' "$limit"
}

clamp_bet_to_limit() {
    local fallback="$1"
    local minimum="${2:-1}"
    local limit
    limit=$(current_max_bet_limit "$fallback")

    if (( limit <= 0 )); then
        BET=0
        return
    fi

    if (( BET > limit )); then
        BET=$limit
    elif (( BET < minimum )); then
        BET=$minimum
        (( BET > limit )) && BET=$limit
    fi
}
