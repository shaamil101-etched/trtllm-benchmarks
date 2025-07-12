#!/bin/bash

CONFIG_FILE="sweep_config.csv"
COMPLETED_BENCHMARKS=0
FAILED_BENCHMARKS=0
CURRENT_BENCHMARK=0

echo "Starting debug sweep..."

while IFS=',' read -r isl osl requests; do
    ((CURRENT_BENCHMARK++))
    echo "=== PROCESSING BENCHMARK $CURRENT_BENCHMARK ==="
    echo "ISL=$isl, OSL=$osl, Requests=$requests"
    
    # Simulate create_dataset function
    echo "  -> Creating dataset..."
    if [[ $CURRENT_BENCHMARK -eq 1 ]]; then
        echo "  -> Dataset exists, skipping creation"
        dataset_success=true
    else
        echo "  -> Would create new dataset"
        dataset_success=true
    fi
    
    if [[ $dataset_success == true ]]; then
        echo "  -> Running benchmark..."
        # Simulate benchmark run
        echo "  -> Benchmark running... (simulated)"
        ((COMPLETED_BENCHMARKS++))
        echo "  -> Benchmark completed successfully"
    else
        echo "  -> Skipping benchmark due to dataset failure"
        ((FAILED_BENCHMARKS++))
    fi
    
    echo "  -> Current stats: Completed=$COMPLETED_BENCHMARKS, Failed=$FAILED_BENCHMARKS"
    echo ""
    
    # Break after 3 for testing
    if [[ $CURRENT_BENCHMARK -ge 3 ]]; then
        echo "Breaking after 3 for debug purposes"
        break
    fi
    
done < <(tail -n +2 "$CONFIG_FILE")

echo "Final stats:"
echo "Total benchmarks processed: $CURRENT_BENCHMARK"
echo "Completed: $COMPLETED_BENCHMARKS"
echo "Failed: $FAILED_BENCHMARKS"
