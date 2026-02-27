#!/usr/bin/env bash


API_LAUNCHES="https://ll.thespacedevs.com/2.3.0/launches/upcoming"
VAN_SFB=11 # Vandenberg SFB location_id

CACHE_FILE="/tmp/spacex_vandenberg_cache"
CACHE_TTL=300 # 5 minutes

if [[ -f "$CACHE_FILE" ]]; then
    cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE")))
    if [[ $cache_age -lt $CACHE_TTL ]]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

launch_data=$(curl -s "$API_LAUNCHES/?location__ids=$VAN_SFB&limit=1")

launch_time=$(echo "$launch_data" | jq -r '.results[0].net // empty')

if [[ -z "$launch_time" ]]; then
    echo "🚀 --" | tee "$CACHE_FILE"
    exit 0 
fi

launch_time_unix=$(date -d "$launch_time" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$launch_time" +%s)
now=$(date +%s)
time_delta=$((launch_time_unix - now))

if [[ $time_delta -lt 0 ]]; then 
    echo "🚀 LIVE?" | tee $CACHE_FILE
    exit 0
fi

days=$((time_delta / 86400))
hours=$(((time_delta % 86400) / 3600))
mins=$(((time_delta % 3600 / 60)))

if [[ $days -gt 0 ]]; then
    output="🚀 ${days}d ${hours}h ${mins}m"
else
    output="🚀 ${hours}h ${mins}m"
fi

echo "$output" | tee $CACHE_FILE
