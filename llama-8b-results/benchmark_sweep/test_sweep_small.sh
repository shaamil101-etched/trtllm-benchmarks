#!/bin/bash

# Test with smaller configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/test_config_small.csv"
RESULTS_DIR="$SCRIPT_DIR/results"
DATASETS_DIR="$SCRIPT_DIR/datasets"
LOGS_DIR="$SCRIPT_DIR/logs"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"

# Clean up and create directories
rm -rf "$RESULTS_DIR" "$DATASETS_DIR" "$LOGS_DIR"
mkdir -p "$RESULTS_DIR" "$DATASETS_DIR" "$LOGS_DIR"

echo "0" > "$PROGRESS_FILE"

TEMP_CONFIG_FILE=$(mktemp)
trap "rm -f $TEMP_CONFIG_FILE" EXIT

tail -n +2 "$CONFIG_FILE" > "$TEMP_CONFIG_FILE"
TOTAL_CONFIGS=$(wc -l < "$TEMP_CONFIG_FILE")

echo "Testing with $TOTAL_CONFIGS configurations" | tee -a "$LOGS_DIR/sweep.log"

CONFIG_COUNT=0

while IFS=',' read -r isl osl num_requests; do
    CONFIG_COUNT=$((CONFIG_COUNT + 1))
    
    echo "Processing config $CONFIG_COUNT/$TOTAL_CONFIGS: ISL=$isl, OSL=$osl, Requests=$num_requests" | tee -a "$LOGS_DIR/sweep.log"
    
    DATASET_FILE="$DATASETS_DIR/synthetic_${isl}_${osl}_${num_requests}.jsonl"
    
    # Create dataset
    python3 -c "
import json

def create_synthetic_data(input_seq_len, output_seq_len, num_requests):
    data = []
    for i in range(num_requests):
        input_text = ' '.join(['word'] * input_seq_len)
        data.append({
            'input_text': input_text,
            'output_tokens': output_seq_len
        })
    return data

data = create_synthetic_data($isl, $osl, $num_requests)

with open('$DATASET_FILE', 'w') as f:
    for item in data:
        f.write(json.dumps(item) + '\n')

print(f'Created dataset with {len(data)} samples')
"
    
    if [[ $? -eq 0 ]]; then
        echo "Dataset created successfully: $DATASET_FILE" | tee -a "$LOGS_DIR/sweep.log"
    else
        echo "ERROR: Failed to create dataset: $DATASET_FILE" | tee -a "$LOGS_DIR/sweep.log"
        continue
    fi
    
    echo "$CONFIG_COUNT" > "$PROGRESS_FILE"
    
done < "$TEMP_CONFIG_FILE"

echo "Test completed. Created $(ls -1 "$DATASETS_DIR"/*.jsonl 2>/dev/null | wc -l) datasets" | tee -a "$LOGS_DIR/sweep.log"
