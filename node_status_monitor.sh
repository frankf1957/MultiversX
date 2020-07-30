#!/bin/bash

# ------------------------------------------------------------------------------- 
#
# Elrond validator node status monitor with telegram alerts
#
# This monitor script can be run on your validator node, or on any observer node.
# It will find all BLS keys registered to your KEYBASE_ID, and then get the
# heartbeat status for each BLS key. If the BLS key is for an observer it is
# ignored. If the BLS key is for a validator the isActive state is checked. If
# isActive is false a Telegram alert is sent using your TELEGRAM_BOT_TOKEN and
# TELEGRAM_CHAT_ID. If isActive is true the Telegram alert is cleared. The script
# maintains a state file on disk for each BLS key matching the pattern
# .node.${publicKey_short}.isActive.true and
# .node.${publicKey_short}.isActive.false. By checking these state files the
# script is able to send only one alert per BLS key each time the state of the
# validator changes from isActive=true to isActive=false and then back to
# isActive=true.
#
# To use this script:
#
# 1. Configure your KEYBASE_ID, TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID
#
# 2. run this script with test keyword to send a test to your telegram bot
#    bash node_status_monitor.sh test
#
# 3. run this script with crontab keyword to add the monitor to your crontab to run every 3 minutes
#    bash node_status_monitor.sh crontab
#
# @frankf1957
# Wed Jul 29 23:37:46 UTC 2020
#
# ------------------------------------------------------------------------------- 

# ------------------------------------------------------------------------------- 
# your keybase id
KEYBASE_ID="<your keybase id>"

# ------------------------------------------------------------------------------- 
# enable/disable sending telegram messages
SEND_TELEGRAM="YES"
TELEGRAM_BOT_TOKEN="0011223344:AABBC-BBBBBBBBBB_CCCCCC_000_aBaBaBaB"
TELEGRAM_CHAT_ID="-195701957"

# ------------------------------------------------------------------------------- 
#  ===>> MAKE NO CHANGES BELOW THIS LINE  <<==

HOSTNAME="$(hostname -s)"

IS_WAITING="🕑"
IS_WARNING="⚠️"
IS_CRITICAL="🔴"
IS_CLEAR="✅"

function send_telegram {
    local _message="$1"
    curl -X POST \
        -H 'Content-Type: application/json' \
        -d '{"chat_id": "'"$TELEGRAM_CHAT_ID"'", "text": "'"$_message"'", "disable_notification": true}' \
        https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage 1>/dev/null 2>&1
}


# -----------------------------------------------------------------------------
# testing notifications

if [[ "${1}" == "test" ]]; then
    for x in "WARNING" "CRITICAL" "CLEAR"; do
        echo >&2
        echo >&2 "# SENDING TEST ${x} ALARM TO ROLE: ${recipient}"
        case "$x" in
            "WARNING")
                IMG="$IS_WARNING"
                ;;
            "CRITICAL")
                IMG="$IS_CRITICAL"
                ;;
            "CLEAR")
                IMG="$IS_CLEAR"
                ;;
        esac
        send_telegram "$IMG $KEYBASE_ID test.alarm test.node test.validators is ${x} this is a test alarm"
    done
    exit 0
fi


# -----------------------------------------------------------------------------
# add to crontab

if [[ "${1}" == "crontab" ]]; then
    crontab -l 2>/dev/null | { cat; echo "*/3 * * * * /bin/bash -c $HOME/node_status_monitor.sh"; } | crontab -
    exit 0
fi


# ------------------------------------------------------------------------------- 
# get a list of validatorKeys for this KEYBASE_ID
publicKey_list=$(curl -s localhost:8080/node/heartbeatstatus | jq '.data.heartbeats | .[] | select(.identity=="'$KEYBASE_ID'").publicKey')


# ------------------------------------------------------------------------------- 
# process the list of validatorKeys
for publicKey in $publicKey_list
do
    HEARTBEATSTATUS=$(curl -s localhost:8080/node/heartbeatstatus | jq '.data.heartbeats | .[] | select(.publicKey=='$publicKey')')
    if [[ $? -ne 0 ]]; then
        send_telegram "$IS_CRITICAL curl could not connect to api port, node is down"
        exit 1
    fi

    isActive=$(echo $HEARTBEATSTATUS | jq -r .isActive)
    peerType=$(echo $HEARTBEATSTATUS | jq -r .peerType)
    nodeDisplayName=$(echo $HEARTBEATSTATUS | jq -r .nodeDisplayName)
    publicKey_head=$(echo $HEARTBEATSTATUS | jq -r .publicKey | head -c10)
    publicKey_tail=$(echo $HEARTBEATSTATUS | jq -r .publicKey | tail -c11 | head -c10)
    publicKey_short="${publicKey_head}...${publicKey_tail}"

    # ignoring observers
    if [[ ${peerType} == "observer" ]]; then
        continue
    fi

    # this is a validator
    case "${isActive}" in
        "true")
            # if the telegram alert was cleared, do not clear it again
            if [[ -f ${HOME}/.node.${publicKey_short}.isActive.true ]]; then
                continue
            fi
            # maintain node isActive state 
            rm -f ${HOME}/.node.${publicKey_short}.isActive.false
            touch ${HOME}/.node.${publicKey_short}.isActive.true
            # clear telegram alert
            if [[ "$SEND_TELEGRAM" == "YES" ]]; then
                send_telegram "$IS_CLEAR Node Name: ${nodeDisplayName} is active. Public key: ${publicKey_short}"
            fi
            ;;
        "false")
            # if the telegran alert was sent, do not send it again
            if [[ -f ${HOME}/.node.${publicKey_short}.isActive.false ]]; then
                continue
            fi
            # maintain node isActive state 
            rm -f ${HOME}/.node.${publicKey_short}.isActive.true
            touch ${HOME}/.node.${publicKey_short}.isActive.false
            # send telegram alert
            if [[ "$SEND_TELEGRAM" == "YES" ]]; then
                send_telegram "$IS_CRITICAL Node Name: ${nodeDisplayName} is not active. Public key: ${publicKey_short}"
            fi
            ;;
    esac

done

exit 0

