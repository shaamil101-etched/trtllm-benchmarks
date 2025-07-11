#!/bin/bash
CONFIG_FILE="sweep_config.csv"
counter=0

echo "=== Testing CSV reading ==="
while IFS=',' read -r isl osl requests; do
    echo "Line $counter: isl=$isl, osl=$osl, requests=$requests"
    ((counter++))
    if [[ $counter -ge 5 ]]; then
        echo "Breaking after 5 lines for testing"
        break
    fi
done < "$CONFIG_FILE"

echo "Total lines processed: $counter"
