#!/bin/bash

echo "Testing Python subprocess hypothesis..."

simulate_python_benchmark() {
    local isl=$1
    local osl=$2
    local requests=$3
    
    echo "  -> Running Python subprocess: ISL=$isl, OSL=$osl, Requests=$requests"
    
    # Use python3 subprocess similar to the actual command
    if cd /home/shaamil-karim && python3 -c "
import time
print('Python subprocess running...')
time.sleep(0.1)  # Brief delay
print('Python subprocess completed')
" > /tmp/test_python_output.log 2>&1; then
        echo "  -> Python subprocess completed"
        return 0
    else
        echo "  -> Python subprocess failed"
        return 1
    fi
}

counter=0
while IFS=',' read -r isl osl requests; do
    ((counter++))
    echo "Processing $counter: $isl,$osl,$requests"
    
    if simulate_python_benchmark "$isl" "$osl" "$requests"; then
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
    echo "✓ No Python subprocess issue detected"
else
    echo "✗ Python subprocess is affecting the loop"
fi
