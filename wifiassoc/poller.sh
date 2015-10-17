#!/usr/bin/env bash

# Working directory
DIR=/opt/wifiassoc

# Path to SSH private key file
SSH_KEY=/path/to/ssh/key

# Remote user to login as
REMOTE_USER=root

# Poll every x seconds
SLEEP=60

# Print logging to stdout (enter stdout below) or to the filename defined by $LOG in $DIR
LOG=$DIR/assoclogging

# Newline seperator. Don't change this unless you know what you're doing
IFS=$'\n'

function log {
    if [ ! $LOG ]; then 
        exit
    fi
    if [ $LOG == "stdout" ]; then
        echo $(date +"%D %T") $1 $2 $3 $4 $5 $6 $7 $8 $9
    else
        echo $(date +"%D %T") $1 $2 $3 $4 $5 $6 $7 $8 $9 >> /$LOG
    fi
}

while true; do
NOW=$(date +"%D %T")

for AP in $(grep -v ^# $DIR/routers.list); do
    IP=$(echo $AP | awk '{ print $1 }')
    log $IP 
    IFACES=$(echo $AP | awk '{ print $2}')
    for IFACE in $(echo $IFACES | sed 's/,/\n/'); do
        IF=$(echo $IFACE | awk -F: '{ print $1 }')
        log $IP $IF
        THRESHOLD=$(echo $IFACE | awk -F: '{ print $2 }')
        LIST=$(ssh -i $SSH_KEY -l $REMOTE_USER $IP /usr/sbin/wl -i $IF assoclist)
        if [ "$?" -ne "0" ]; then
            log "$IP Connection Error 1"
        else
            for LI in $LIST; do
                MAC=$(echo $LI | awk '{ print $2 }')
                RSSI=$(ssh -i $SSH_KEY -l $REMOTE_USER $IP /usr/sbin/wl -i $IF rssi $MAC)
                if [ "$?" -ne "0" ]; then 
                    log "$IP Connection Error 2"
                else
                    log $IP $IF $MAC $RSSI
    
                    # Get clients IP address (apparently an association can still be in the list without being online)
                    CLIENT_HOST=$(ssh -i $SSH_KEY -l $REMOTE_USER $IP /sbin/arp -a | grep $MAC | awk '{print $1}')
                    CH=$?
                    CLIENT_IP=$(ssh -i $SSH_KEY -l $REMOTE_USER $IP /sbin/arp -a | grep $MAC | awk '{print $2}' | sed 's/[\(]//; s/[\)]//')
                    CI=$?
    
                    if [ "$CH" -ne "0" ] || [ "$CI" -ne "0" ]; then
                        log "$IP Connection Error 3&4"
                    else
                        # Only log client presence when it has an IP
                        if [ -n "$CLIENT_IP" ]; then
                            if [ ! -d $DIR/data/$IP ]; then
                                log "Dir $IP"
                                mkdir -p $DIR/data/$IP
                            fi
                    
                            # Log data to file
                            echo $NOW,$RSSI,$CLIENT_IP,$CLIENT_HOST >> $DIR/data/$IP/$MAC
                        fi
                    fi
                fi
            done
        fi
    done
done

sleep $SLEEP
done
