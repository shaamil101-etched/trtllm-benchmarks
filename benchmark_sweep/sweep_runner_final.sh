#!/bin/bash

# TensorRT-LLM Benchmark Sweep Runner - Final Version
# Comprehensive solution addressing all issues from previous attempts

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/sweep_config.csv"
RESULTS_DIR="$SCRIPT_DIR/results"
DATASETS_DIR="$SCRIPT_DIR/datasets"
LOGS_DIR="$SCRIPT_DIR/logs"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ENGINE_DIR="$SCRIPT_DIR/engines"

# Function to cleanup and initialize directories
cleanup_and_init() {
    echo "Cleaning up previous runs..."
    rm -rf "$RESULTS_DIR" "$DATASETS_DIR" "$LOGS_DIR" "$ENGINE_DIR"
    mkdir -p "$RESULTS_DIR" "$DATASETS_DIR" "$LOGS_DIR" "$ENGINE_DIR"
    echo "0" > "$PROGRESS_FILE"
}

# Function to create synthetic dataset
create_dataset() {
    local isl=$1
    local osl=$2
    local num_requests=$3
    local dataset_file=$4
    
    echo "Creating dataset: $dataset_file" | tee -a "$LOGS_DIR/sweep.log"
    
    python3 -c "
import json
import random

def create_synthetic_data(input_seq_len, output_seq_len, num_requests):
    data = []
    for i in range(num_requests):
        # Create varied synthetic input
        words = ['word', 'test', 'data', 'sample', 'input', 'text', 'benchmark']
        input_text = ' '.join(random.choices(words, k=input_seq_len))
        
        data.append({
            'input_text': input_text,
            'output_tokens': output_seq_len
        })
    
    return data

# Generate data
data = create_synthetic_data($isl, $osl, $num_requests)

# Save to JSONL format
with open('$dataset_file', 'w') as f:
    for item in data:
        f.write(json.dumps(item) + '\n')

print(f'Created dataset with {len(data)} samples')
"
    
    return $?
}

# Function to attempt engine building
build_engine() {
    local isl=$1
    local osl=$2
    local engine_path=$3
    local engine_log=$4
    
    echo "Attempting to build engine for ISL=$isl, OSL=$osl" | tee -a "$LOGS_DIR/sweep.log"
    
    # Calculate appropriate max_seq_len
    local max_seq_len=$((isl + osl + 200))
    
    # Try building with gpt2 (most compatible)
    if timeout 180 trtllm-bench -m gpt2 build \
        --max_seq_len $max_seq_len \
        --target_input_len $isl \
        --target_output_len $osl \
        --max_batch_size 1 \
        --max_num_tokens $max_seq_len \
        > "$engine_log" 2>&1; then
        
        # Check if engine directory was created
        if [[ -d "gpt2" ]]; then
            mv "gpt2" "$engine_path"
            echo "Engine built successfully: $engine_path" | tee -a "$LOGS_DIR/sweep.log"
            return 0
        else
            echo "Engine build completed but no output directory found" | tee -a "$LOGS_DIR/sweep.log"
            return 1
        fi
    else
        echo "Engine build failed or timed out" | tee -a "$LOGS_DIR/sweep.log"
        return 1
    fi
}

# Function to run benchmark
run_benchmark() {
    local isl=$1
    local osl=$2
    local num_requests=$3
    local engine_path=$4
    local dataset_file=$5
    local benchmark_log=$6
    
    echo "Running benchmark for ISL=$isl, OSL=$osl, Requests=$num_requests" | tee -a "$LOGS_DIR/sweep.log"
    
    if timeout 300 trtllm-bench -m gpt2 throughput \
        --engine_dir "$engine_path" \
        --dataset "$dataset_file" \
        --num_requests $num_requests \
        --streaming \
        > "$benchmark_log" 2>&1; then
        
        echo "Benchmark completed successfully" | tee -a "$LOGS_DIR/sweep.log"
        return 0
    else
        echo "Benchmark failed or timed out" | tee -a "$LOGS_DIR/sweep.log"
        return 1
    fi
}

# Main execution
main() {
    cleanup_and_init
    
    # Create temporary config file to avoid stdin issues
    local temp_config_file=$(mktemp)
    trap "rm -f $temp_config_file" EXIT
    
    # Extract configurations to temp file (skip header)
    tail -n +2 "$CONFIG_FILE" > "$temp_config_file"
    
    # Count total configurations
    local total_configs=$(wc -l < "$temp_config_file")
    
    echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"
    echo "Starting TensorRT-LLM benchmark sweep at $(date)" | tee -a "$LOGS_DIR/sweep.log"
    echo "Total configurations to process: $total_configs" | tee -a "$LOGS_DIR/sweep.log"
    echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"
    
    local config_count=0
    local datasets_created=0
    local engines_built=0
    local benchmarks_completed=0
    
    # Process each configuration
    while IFS=',' read -r isl osl num_requests; do
        config_count=$((config_count + 1))
        
        echo "Processing config $config_count/$total_configs: ISL=$isl, OSL=$osl, Requests=$num_requests" | tee -a "$LOGS_DIR/sweep.log"
        
        # Define paths
        local dataset_file="$DATASETS_DIR/synthetic_${isl}_${osl}_${num_requests}.jsonl"
        local engine_path="$ENGINE_DIR/engine_${isl}_${osl}"
        local engine_log="$LOGS_DIR/engine_build_${isl}_${osl}.log"
        local benchmark_log="$LOGS_DIR/benchmark_${isl}_${osl}_${num_requests}.log"
        
        # Step 1: Create dataset
        if [[ ! -f "$dataset_file" ]]; then
            if create_dataset $isl $osl $num_requests "$dataset_file"; then
                datasets_created=$((datasets_created + 1))
                echo "Dataset created successfully" | tee -a "$LOGS_DIR/sweep.log"
            else
                echo "ERROR: Failed to create dataset" | tee -a "$LOGS_DIR/sweep.log"
                continue
            fi
        else
            echo "Dataset already exists: $dataset_file" | tee -a "$LOGS_DIR/sweep.log"
        fi
        
        # Step 2: Build engine (if not exists)
        if [[ ! -d "$engine_path" ]]; then
            cd "$ENGINE_DIR"
            if build_engine $isl $osl "$engine_path" "$engine_log"; then
                engines_built=$((engines_built + 1))
            fi
            cd "$SCRIPT_DIR"
        else
            echo "Engine already exists: $engine_path" | tee -a "$LOGS_DIR/sweep.log"
        fi
        
        # Step 3: Run benchmark (if engine exists)
        if [[ -d "$engine_path" ]]; then
            if run_benchmark $isl $osl $num_requests "$engine_path" "$dataset_file" "$benchmark_log"; then
                benchmarks_completed=$((benchmarks_completed + 1))
            fi
        else
            echo "Skipping benchmark - no engine available" | tee -a "$LOGS_DIR/sweep.log"
        fi
        
        # Update progress
        echo "$config_count" > "$PROGRESS_FILE"
        
        echo "Completed config $config_count/$total_configs" | tee -a "$LOGS_DIR/sweep.log"
        echo "---" | tee -a "$LOGS_DIR/sweep.log"
        
    done < "$temp_config_file"
    
    # Final summary
    echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"
    echo "Benchmark sweep completed at $(date)" | tee -a "$LOGS_DIR/sweep.log"
    echo "Summary:" | tee -a "$LOGS_DIR/sweep.log"
    echo "- Configurations processed: $config_count" | tee -a "$LOGS_DIR/sweep.log"
    echo "- Datasets created: $datasets_created" | tee -a "$LOGS_DIR/sweep.log"
    echo "- Engines built: $engines_built" | tee -a "$LOGS_DIR/sweep.log"
    echo "- Benchmarks completed: $benchmarks_completed" | tee -a "$LOGS_DIR/sweep.log"
    echo "=================================================" | tee -a "$LOGS_DIR/sweep.log"
}

# Execute main function
main "$@"
