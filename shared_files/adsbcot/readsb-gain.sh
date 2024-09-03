#!/bin/bash

AOS_CONFIG="/etc/aryaos/aryaos-config.txt"

if [ -f $AOS_CONFIG ]; then
  # shellcheck source=aryaos-config.txt
  . $AOS_CONFIG
fi

READSB_CONFIG="/etc/readsb-config.txt"

validre='^(-10|[0-9]+([.][0-9]+)?)$'
gain=$(echo $1 | tr -cd '[:digit:].-')

if ! [[ $gain =~ $validre ]] ; then echo "Error, invalid gain!"; exit 1; fi
if ! grep gain $READSB_CONFIG &>/dev/null; then sudo sed -i -e 's/RECEIVER_OPTIONS="/RECEIVER_OPTIONS="--gain 49.6 /' $READSB_CONFIG; fi


sed -i -E -e "s/--gain .?[0-9]*.?[0-9]* /--gain $gain /" $READSB_CONFIG

echo "Don't forget to: sudo systemctl restart readsb"
