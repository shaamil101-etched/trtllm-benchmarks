#!/bin/bash

echo "Testing subprocess execution patterns..."

test_function() {
    local isl=$1
    local osl=$2
    local requests=$3
    
    echo "  -> In test_function: ISL=$isl, OSL=$osl, Requests=$requests"
    
    # Simulate the subprocess call pattern used in run_benchmark
    if cd /home/shaamil-karim && echo "Simulating trtllm-bench command" > /tmp/test_output.log 2>&1; then
        echo "  -> Subprocess succeeded"
        return 0
    else
        echo "  -> Subprocess failed"
        return 1
    fi
}

counter=0
while IFS=',' read -r isl osl requests; do
    ((counter++))
    echo "Processing $counter: $isl,$osl,$requests"
    
    if test_function "$isl" "$osl" "$requests"; then
        echo "  -> Function returned success"
    else
        echo "  -> Function returned failure"
    fi
    
    if [[ $counter -ge 3 ]]; then
        echo "Breaking after 3 for test"
        break
    fi
    
done < <(tail -n +2 sweep_config.csv)

echo "Final counter: $counter"
