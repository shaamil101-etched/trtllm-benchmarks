#!/bin/bash

# Fixed sweep runner v9 - addresses stdin consumption issue
# This version extracts CSV to temp file and reads directly from it

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/sweep_config.csv"
RESULTS_DIR="$SCRIPT_DIR/results"
DATASETS_DIR="$SCRIPT_DIR/datasets"
LOGS_DIR="$SCRIPT_DIR/logs"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"

# Create necessary directories
mkdir -p "$RESULTS_DIR" "$DATASETS_DIR" "$LOGS_DIR"

# Initialize progress tracking
echo "0" > "$PROGRESS_FILE"

# Create temporary config file to avoid stdin issues
TEMP_CONFIG_FILE=$(mktemp)
trap "rm -f $TEMP_CONFIG_FILE" EXIT

# Extract configurations to temp file (skip header)
tail -n +2 "$CONFIG_FILE" > "$TEMP_CONFIG_FILE"

# Count total configurations
TOTAL_CONFIGS=$(wc -l < "$TEMP_CONFIG_FILE")

echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"
echo "Starting benchmark sweep at $(date)" | tee -a "$LOGS_DIR/sweep.log"
echo "Total configurations to process: $TOTAL_CONFIGS" | tee -a "$LOGS_DIR/sweep.log"
echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"

CONFIG_COUNT=0

# Read configurations from temp file
while IFS=',' read -r isl osl num_requests; do
    CONFIG_COUNT=$((CONFIG_COUNT + 1))
    
    echo "Processing config $CONFIG_COUNT/$TOTAL_CONFIGS: ISL=$isl, OSL=$osl, Requests=$num_requests" | tee -a "$LOGS_DIR/sweep.log"
    
    # Define dataset and result paths
    DATASET_FILE="$DATASETS_DIR/synthetic_${isl}_${osl}_${num_requests}.jsonl"
    RESULT_FILE="$RESULTS_DIR/benchmark_${isl}_${osl}_${num_requests}.json"
    
    # Step 1: Create dataset if it doesn't exist
    if [[ ! -f "$DATASET_FILE" ]]; then
        echo "Creating dataset: $DATASET_FILE" | tee -a "$LOGS_DIR/sweep.log"
        
        python3 -c "
import json
import random

def create_synthetic_data(input_seq_len, output_seq_len, num_requests):
    data = []
    for i in range(num_requests):
        # Create synthetic input of specified length
        input_text = ' '.join(['word'] * input_seq_len)
        
        # Create expected output length
        output_length = output_seq_len
        
        data.append({
            'input_text': input_text,
            'output_tokens': output_length
        })
    
    return data

# Generate data
data = create_synthetic_data($isl, $osl, $num_requests)

# Save to JSONL format
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
    else
        echo "Dataset already exists: $DATASET_FILE" | tee -a "$LOGS_DIR/sweep.log"
    fi
    
    # Step 2: Run benchmark
    echo "Running benchmark for ISL=$isl, OSL=$osl, Requests=$num_requests" | tee -a "$LOGS_DIR/sweep.log"
    
    # Run benchmark with proper error handling and stdin redirection
    if trtllm-bench \
        --model llama \
        --dataset "$DATASET_FILE" \
        --max_input_len $isl \
        --max_output_len $osl \
        --output_dir "$RESULTS_DIR" \
        --num_requests $num_requests \
        --batch_size 1 \
        --streaming \
        --log_level INFO \
        --warm_up 0 \
        --results_file "$RESULT_FILE" \
        < /dev/null 2>&1 | tee -a "$LOGS_DIR/sweep.log"; then
        
        echo "Benchmark completed successfully for config $CONFIG_COUNT/$TOTAL_CONFIGS" | tee -a "$LOGS_DIR/sweep.log"
        
        # Update progress
        echo "$CONFIG_COUNT" > "$PROGRESS_FILE"
        
    else
        echo "ERROR: Benchmark failed for ISL=$isl, OSL=$osl, Requests=$num_requests" | tee -a "$LOGS_DIR/sweep.log"
        continue
    fi
    
    echo "Completed config $CONFIG_COUNT/$TOTAL_CONFIGS" | tee -a "$LOGS_DIR/sweep.log"
    echo "---" | tee -a "$LOGS_DIR/sweep.log"
    
done < "$TEMP_CONFIG_FILE"

echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"
echo "Benchmark sweep completed at $(date)" | tee -a "$LOGS_DIR/sweep.log"
echo "Processed $CONFIG_COUNT configurations" | tee -a "$LOGS_DIR/sweep.log"
echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"
