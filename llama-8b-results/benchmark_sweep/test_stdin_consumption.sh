#!/bin/bash

echo "Testing stdin consumption hypothesis..."

# Function that simulates run_benchmark with actual subprocess
simulate_benchmark() {
    local isl=$1
    local osl=$2
    local requests=$3
    
    echo "  -> Running simulated benchmark: ISL=$isl, OSL=$osl, Requests=$requests"
    
    # Use the same command pattern but with a simpler command that might consume stdin
    if cd /home/shaamil-karim && echo "test" > /tmp/test_output.log 2>&1; then
        echo "  -> Benchmark completed"
        return 0
    else
        echo "  -> Benchmark failed"
        return 1
    fi
}

counter=0
while IFS=',' read -r isl osl requests; do
    ((counter++))
    echo "Processing $counter: $isl,$osl,$requests"
    
    # Call the function
    if simulate_benchmark "$isl" "$osl" "$requests"; then
        echo "  -> Success"
    else
        echo "  -> Failed"
    fi
    
    if [[ $counter -ge 3 ]]; then
        echo "Breaking after 3 for test"
        break
    fi
    
done < <(tail -n +2 sweep_config.csv)

echo "Final counter: $counter"
echo "Expected: 3, Actual: $counter"
if [[ $counter -eq 3 ]]; then
    echo "✓ No stdin consumption issue detected"
else
    echo "✗ Potential stdin consumption issue"
fi
