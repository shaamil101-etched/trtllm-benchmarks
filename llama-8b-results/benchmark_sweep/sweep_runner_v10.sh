#!/bin/bash

# TensorRT-LLM Benchmark Sweep Runner v10 - Comprehensive Solution
# Fixes all previous issues and implements proper trtllm-bench workflow

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/sweep_config.csv"
RESULTS_DIR="$SCRIPT_DIR/results"
DATASETS_DIR="$SCRIPT_DIR/datasets"
LOGS_DIR="$SCRIPT_DIR/logs"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ENGINE_DIR="$SCRIPT_DIR/engines"

# Clean up and create directories
echo "Cleaning up previous runs..."
rm -rf "$RESULTS_DIR" "$DATASETS_DIR" "$LOGS_DIR" "$ENGINE_DIR"
mkdir -p "$RESULTS_DIR" "$DATASETS_DIR" "$LOGS_DIR" "$ENGINE_DIR"

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
echo "Starting TensorRT-LLM benchmark sweep at $(date)" | tee -a "$LOGS_DIR/sweep.log"
echo "Total configurations to process: $TOTAL_CONFIGS" | tee -a "$LOGS_DIR/sweep.log"
echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"

CONFIG_COUNT=0

# Read configurations from temp file
while IFS=',' read -r isl osl num_requests; do
    CONFIG_COUNT=$((CONFIG_COUNT + 1))
    
    echo "Processing config $CONFIG_COUNT/$TOTAL_CONFIGS: ISL=$isl, OSL=$osl, Requests=$num_requests" | tee -a "$LOGS_DIR/sweep.log"
    
    # Define paths
    DATASET_FILE="$DATASETS_DIR/synthetic_${isl}_${osl}_${num_requests}.jsonl"
    ENGINE_PATH="$ENGINE_DIR/engine_${isl}_${osl}"
    RESULT_FILE="$RESULTS_DIR/benchmark_${isl}_${osl}_${num_requests}.json"
    
    # Step 1: Create dataset
    if [[ ! -f "$DATASET_FILE" ]]; then
        echo "Creating dataset: $DATASET_FILE" | tee -a "$LOGS_DIR/sweep.log"
        
        python3 -c "
import json
import random

def create_synthetic_data(input_seq_len, output_seq_len, num_requests):
    data = []
    for i in range(num_requests):
        # Create synthetic input text
        input_text = ' '.join(['word'] * input_seq_len)
        
        # For trtllm-bench, we need proper format
        data.append({
            'input_text': input_text,
            'output_tokens': output_seq_len
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
    
    # Step 2: Build engine for this configuration if it doesn't exist
    if [[ ! -d "$ENGINE_PATH" ]]; then
        echo "Building engine for ISL=$isl, OSL=$osl" | tee -a "$LOGS_DIR/sweep.log"
        
        # Calculate max_seq_len (input + output + buffer)
        MAX_SEQ_LEN=$((isl + osl + 100))
        
        # Build engine with gpt2 model (simpler than llama)
        ENGINE_LOG="$LOGS_DIR/engine_build_${isl}_${osl}.log"
        
        if timeout 300 trtllm-bench -m gpt2 build \
            --max_seq_len $MAX_SEQ_LEN \
            --target_input_len $isl \
            --target_output_len $osl \
            --max_batch_size 1 \
            --max_num_tokens $((isl + osl)) \
            < /dev/null >> "$ENGINE_LOG" 2>&1; then
            
            echo "Engine built successfully for ISL=$isl, OSL=$osl" | tee -a "$LOGS_DIR/sweep.log"
            
            # Move engine to proper location
            if [[ -d "gpt2" ]]; then
                mv "gpt2" "$ENGINE_PATH"
            fi
            
        else
            echo "WARNING: Engine build failed for ISL=$isl, OSL=$osl (timeout or error)" | tee -a "$LOGS_DIR/sweep.log"
            echo "Continuing with dataset creation only..." | tee -a "$LOGS_DIR/sweep.log"
        fi
    else
        echo "Engine already exists: $ENGINE_PATH" | tee -a "$LOGS_DIR/sweep.log"
    fi
    
    # Step 3: Run benchmark if engine exists
    if [[ -d "$ENGINE_PATH" ]]; then
        echo "Running benchmark for ISL=$isl, OSL=$osl, Requests=$num_requests" | tee -a "$LOGS_DIR/sweep.log"
        
        BENCHMARK_LOG="$LOGS_DIR/benchmark_${isl}_${osl}_${num_requests}.log"
        
        if timeout 600 trtllm-bench -m gpt2 throughput \
            --engine_dir "$ENGINE_PATH" \
            --dataset "$DATASET_FILE" \
            --num_requests $num_requests \
            --streaming \
            < /dev/null >> "$BENCHMARK_LOG" 2>&1; then
            
            echo "Benchmark completed successfully for config $CONFIG_COUNT/$TOTAL_CONFIGS" | tee -a "$LOGS_DIR/sweep.log"
            
            # Extract results if they exist
            if [[ -f "$BENCHMARK_LOG" ]]; then
                echo "Results saved to: $BENCHMARK_LOG" | tee -a "$LOGS_DIR/sweep.log"
            fi
            
        else
            echo "WARNING: Benchmark failed for ISL=$isl, OSL=$osl, Requests=$num_requests" | tee -a "$LOGS_DIR/sweep.log"
        fi
    else
        echo "Skipping benchmark (no engine available) for ISL=$isl, OSL=$osl" | tee -a "$LOGS_DIR/sweep.log"
    fi
    
    # Update progress
    echo "$CONFIG_COUNT" > "$PROGRESS_FILE"
    
    echo "Completed config $CONFIG_COUNT/$TOTAL_CONFIGS" | tee -a "$LOGS_DIR/sweep.log"
    echo "---" | tee -a "$LOGS_DIR/sweep.log"
    
done < "$TEMP_CONFIG_FILE"

echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"
echo "Benchmark sweep completed at $(date)" | tee -a "$LOGS_DIR/sweep.log"
echo "Processed $CONFIG_COUNT configurations" | tee -a "$LOGS_DIR/sweep.log"
echo "Results summary:" | tee -a "$LOGS_DIR/sweep.log"
echo "- Datasets created: $(ls -1 "$DATASETS_DIR"/*.jsonl 2>/dev/null | wc -l)" | tee -a "$LOGS_DIR/sweep.log"
echo "- Engines built: $(ls -1d "$ENGINE_DIR"/engine_* 2>/dev/null | wc -l)" | tee -a "$LOGS_DIR/sweep.log"
echo "- Benchmarks completed: $(ls -1 "$LOGS_DIR"/benchmark_*.log 2>/dev/null | wc -l)" | tee -a "$LOGS_DIR/sweep.log"
echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"
