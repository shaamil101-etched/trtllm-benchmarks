#!/bin/bash

echo "Starting test..."
counter=0

while IFS=',' read -r isl osl requests; do
    ((counter++))
    echo "Processing $counter: $isl,$osl,$requests"
    
    # Simulate the cd command that happens in the functions
    echo "  -> Changing to /home/shaamil-karim"
    if cd /home/shaamil-karim; then
        echo "  -> Changed directory successfully"
        echo "  -> Current directory: $(pwd)"
    else
        echo "  -> Failed to change directory"
    fi
    
    # Try to change back
    echo "  -> Changing back to benchmark_sweep"
    if cd /home/shaamil-karim/benchmark_sweep; then
        echo "  -> Changed back successfully"
    else
        echo "  -> Failed to change back"
    fi
    
    if [[ $counter -ge 2 ]]; then
        echo "Breaking after 2 for test"
        break
    fi
    
done < <(tail -n +2 sweep_config.csv)

echo "Final counter: $counter"
