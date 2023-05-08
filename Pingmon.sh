#!/usr/bin/env bash
#TELEGRAM_CHAT_ID="<CHAT_ID"
#TELEGRAM_BOT_TOKEN="<TOKEN>"
#curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq .
#{
#  "ok": true,
#  "result": [
#    {
#      "update_id": 872412446,
#      "message": {
#        "message_id": 6,
#        "from": {
#          "id": 123456789,
#          "is_bot": false,
#          "first_name": "Max",
#          "last_name": "M",
#          "language_code": "en"
#        },
#        "chat": {
#          "id": 123456789,
#          "first_name": "Max",
#          "last_name": "M",
#          "type": "private"
#        },
#        "date": 1683206820,
#        "text": "hello"
#      }
#    }
#  ]
#}
#
# curl -X POST "https://api.telegram.org/bot<bot-api-token>/sendMessage -H 'Content-Type: application/json' -d '{"chat_id": "<chat-id>", "text": "<Your Message>"}'
# curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" -H 'Content-Type: application/json' -d '{"chat_id": "123456789", "text": "Prova da bash CURL"}'
#
# Set the path to the file containing the list of hosts to ping
HOSTS_FILE="ip_monitor_hosts.txt"

# set Sleep time in seconds between probes 
SLEEPTIME=10

# Set the Telegram chat ID and bot token
#TELEGRAM_CHAT_ID="<CHAT_ID"
#TELEGRAM_BOT_TOKEN="<TOKEN>"

#Create an associative array to store each hosts prior status.. To order to prevent repeated pings while a host is down, it will be used to store host status.
declare -A PREV_STATUS

function sendalert() {
    MESSAGE="$(date '+%Y-%m-%d %H:%M:%S') $1"
    echo "$MESSAGE"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id=$TELEGRAM_CHAT_ID -d text="$MESSAGE" -o /dev/null
}

function findDown() {
    M=$1
    M2=""
    for hostip in "${!PREV_STATUS[@]}" ##cycle by keys = ip
    do
        #echo " PREV_STATUS $hostip: ${PREV_STATUS[$hostip]} "
        if [ "${PREV_STATUS[$hostip]}" -eq "0" ] ; then
            M2="${M2} $hostip"
        fi
    done
    if [ -n "$M2" ] ;then
        M="$M -- HOST DOWN: $M2"
    fi
    sendalert "${M}"
}

while true
do
    while read -r HOST || [[ -n "$HOST" ]] # Ping the hosts in the file hosts.txt
    do
       # Ping the host with 5 packets and get the packet loss percentage
       #PACKET_LOSS=$(ping -c 5 "$HOST" | grep 'packet loss' | awk -F '%' '{print $1}' | grep -oE '[^[:space:]]+$')
       PACKETLOSS=$(ping -w 2 -s 9 -f -c 100 "$HOST" | grep 'packet loss' | awk -F '%' '{print $1}' | grep -oE '[^[:space:]]+$')
       PACKET_LOSS=${PACKETLOSS%%.*}

       if [ ${PREV_STATUS[$HOST]+_} ] ; then # Check if the previous status of the host is available in the array
           PREV_STATUS_HOST=${PREV_STATUS[$HOST]} # Get the previous status of the host
       else
           PREV_STATUS_HOST=1 #Assume the host is UP if the prior status is unavailable.
       fi

       #if (( "$PACKET_LOSS" = 100 )) ; then
       if [ "$PACKET_LOSS" -eq "100" ] ; then
           CURRENT_STATUS=0 # If all packets are lost, set the current status to 0
           message=" $HOST Device not reachable"
       elif [ "$PACKET_LOSS" -gt "90" ] ; then
           CURRENT_STATUS=0 # If some packets are lost, set the current status to 0
           message=" $HOST: $PACKET_LOSS% Packet loss!"
       else
           CURRENT_STATUS=1 # If there is no packet loss, set the current status to 1
           message=" $HOST UP!!! "
       fi

       # Update the previous status of the host in the array
       PREV_STATUS[$HOST]=$CURRENT_STATUS

       if [ "$CURRENT_STATUS" -ne "$PREV_STATUS_HOST" ] ; then # If the current status is different from the previous status, log a message and send an alert
           findDown "${message}"
       fi

    done < "$HOSTS_FILE"

    # Sleep for 3 minutes before pinging the hosts again 
    sleep "$SLEEPTIME"
done
