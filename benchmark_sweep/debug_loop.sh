#!/bin/bash
CONFIG_FILE="sweep_config.csv"
COMPLETED_BENCHMARKS=0
FAILED_BENCHMARKS=0
CURRENT_BENCHMARK=0

echo "Starting debug loop..."
while IFS=',' read -r isl osl requests; do
    echo "Read line: isl=$isl, osl=$osl, requests=$requests"
    
    # Skip header
    if [[ "$isl" == "isl" ]]; then
        echo "Skipping header line"
        continue
    fi
    
    ((CURRENT_BENCHMARK++))
    echo "Processing benchmark $CURRENT_BENCHMARK: ISL=$isl, OSL=$osl, Requests=$requests"
    
    # Simulate processing
    if [[ $CURRENT_BENCHMARK -le 3 ]]; then
        echo "  -> Processing (simulated)"
        ((COMPLETED_BENCHMARKS++))
    else
        echo "  -> Breaking after 3 for testing"
        break
    fi
    
done < "$CONFIG_FILE"

echo "Loop completed. Total processed: $COMPLETED_BENCHMARKS"
