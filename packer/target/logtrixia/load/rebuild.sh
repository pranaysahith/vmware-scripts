#!/bin/bash
set -eux
ICAP_SERVER=$1
RESULT_FILE=$2  
UUID=$(cat /proc/sys/kernel/random/uuid)
#c-icap-client -i $ICAP_SERVER -p 1344 -s gw_rebuild?traceId=$UUID -f Execute+Java+Script_JS_PDF.pdf -o $UUID.pdf -v > $UUID.log 2>&1
{ time c-icap-client -i $ICAP_SERVER -p 1344 -s gw_rebuild?traceId=$UUID -f Execute+Java+Script_JS_PDF.pdf -o $UUID.pdf -v ; } 2> $UUID.log
#result=$(sed -n '12,12'p $UUID.log)
result=$(cat $UUID.log | grep HTTP)
elapsed_time=$(cat $UUID.log | grep real | sed -E 's/[^0-9\.]+//g' | tr -d '\n' | (cat && echo ' * 1000') | bc)
echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"),$ICAP_SERVER,$UUID,$result,$elapsed_time" >> $RESULT_FILE
rm $UUID.log
rm $UUID.pdf

