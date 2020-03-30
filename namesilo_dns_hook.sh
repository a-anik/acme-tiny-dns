#!/bin/sh

# DNS-01 challenge hook for modified version of acme-tiny.py
# - Based on: https://github.com/joshp23/NameSilo_Certbot-DNS-01
# - Works for 3rd level names: HOST.domain.gtld registered at NameSilo
# - Uses curl and xmllint utility from libxml2-utils

KEYFILE="$(dirname $0)/api.key"   #  file with APIKEY variable
. "$KEYFILE"

if [ $# -lt 2 ]; then
    echo "Usage: $0 setup|teardown <domain> [args...]" >&2
    exit 1
fi

DOMAIN="$2"
HOST="$(echo $DOMAIN | sed -e 's/\.\?[^.]\+\.[^.]\+$//')"  # everything before last two levels
SLD="$(echo $DOMAIN | sed -e "s/^$HOST\.\?//")"  # second-level domain registered in NameSilo account
KEYAUTHHASH="$3"

## Get the XML & record ID
RECORDS="$(curl -s "https://www.namesilo.com/api/dnsListRecords?version=1&type=xml&key=$APIKEY&domain=$SLD")"
RECORD_ID="$(echo $RECORDS | xmllint --xpath "//namesilo/reply/resource_record/record_id[../host/text() = '_acme-challenge.$DOMAIN' ]" - | grep -oP '(?<=<record_id>).*?(?=</record_id>)')"

case "$1" in
    setup)
	if [ -n "$RECORD_ID" ]; then
	    # Update record
	    curl -s "https://www.namesilo.com/api/dnsUpdateRecord?version=1&type=xml&key=$APIKEY&domain=$SLD&rrid=$RECORD_ID&rrhost=_acme-challenge.$HOST&rrvalue=$KEYAUTHHASH&rrttl=3600"
	else
	    # Add record
	    curl -s "https://www.namesilo.com/api/dnsAddRecord?version=1&type=xml&key=$APIKEY&domain=$SLD&rrtype=TXT&rrhost=_acme-challenge.$HOST&rrvalue=$KEYAUTHHASH&rrttl=3600"
	fi
        ;;
    teardown)
	if [ -n "$RECORD_ID" ]; then
            # Delete record
	    curl -s "https://www.namesilo.com/api/dnsDeleteRecord?version=1&type=xml&key=$APIKEY&domain=$SLD&rrid=$RECORD_ID"
	fi
        ;;
    records)
        echo "$RECORDS" | xmllint --format -
        ;;
    *)
        echo "Unknown action: $1" >&2
        exit 1
        ;;
esac
