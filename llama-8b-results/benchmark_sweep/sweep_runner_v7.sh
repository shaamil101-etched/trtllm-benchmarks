#!/bin/bash

# Enhanced TensorRT-LLM Benchmark Sweep Runner with Correct Dataset Generation
# This script runs throughput benchmarks for various input/output length configurations

# Configuration
MODEL_NAME="meta-llama/Llama-3.1-70B"
ENGINE_DIR="/tmp/meta-llama/Llama-3.1-70B/tp_8_pp_1"
QUANTIZATION="FP8"
TP_SIZE=8
PP_SIZE=1
CONFIG_FILE="sweep_config.csv"
RESULTS_DIR="results"
DATASETS_DIR="datasets"
LOGS_DIR="logs"

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWEEP_LOG="$SCRIPT_DIR/$LOGS_DIR/sweep.log"
DEBUG_LOG="$SCRIPT_DIR/$LOGS_DIR/debug.log"
PREPARE_DATASET_SCRIPT="/home/shaamil-karim/TensorRT-LLM/benchmarks/cpp/prepare_dataset.py"

# Progress tracking
TOTAL_BENCHMARKS=0
CURRENT_BENCHMARK=0
COMPLETED_BENCHMARKS=0
FAILED_BENCHMARKS=0

# Create directories first
mkdir -p "$SCRIPT_DIR/$RESULTS_DIR" "$SCRIPT_DIR/$DATASETS_DIR" "$SCRIPT_DIR/$LOGS_DIR"

# Initialize logs
echo "=== TensorRT-LLM Benchmark Sweep Debug Log ===" > "$DEBUG_LOG"
echo "=== TensorRT-LLM Benchmark Sweep Log ===" > "$SWEEP_LOG"

# Enhanced logging function
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$SWEEP_LOG"
    echo "[$timestamp] [$level] $message" >> "$DEBUG_LOG"
}

# Debug logging function
debug_log() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [DEBUG] $message" >> "$DEBUG_LOG"
}

# Safe arithmetic function
safe_increment() {
    local var_name=$1
    local current_value
    eval "current_value=\$$var_name"
    local new_value=$((current_value + 1))
    eval "$var_name=$new_value"
    debug_log "Incremented $var_name from $current_value to $new_value"
}

# Function to create synthetic dataset
create_dataset() {
    local isl=$1
    local osl=$2
    local num_requests=$3
    local dataset_file="$SCRIPT_DIR/$DATASETS_DIR/synthetic_${isl}_${osl}_${num_requests}.jsonl"
    local log_file="$SCRIPT_DIR/$LOGS_DIR/dataset_creation_${isl}_${osl}_${num_requests}.log"
    
    debug_log "create_dataset called with isl=$isl, osl=$osl, num_requests=$num_requests"
    debug_log "Dataset file: $dataset_file"
    debug_log "Log file: $log_file"
    
    if [[ -f "$dataset_file" ]]; then
        local request_count
        request_count=$(wc -l < "$dataset_file" 2>/dev/null || echo "0")
        if [[ $request_count -ge $num_requests ]]; then
            log_message "INFO" "Dataset already exists: $dataset_file ($request_count requests)"
            debug_log "Dataset validation passed for $dataset_file"
            return 0
        else
            log_message "INFO" "Dataset incomplete: $dataset_file ($request_count/$num_requests requests), recreating..."
            debug_log "Dataset incomplete, removing and recreating"
            rm -f "$dataset_file"
        fi
    fi
    
    log_message "INFO" "Creating dataset: ISL=$isl, OSL=$osl, Requests=$num_requests"
    debug_log "Starting dataset creation command"
    
    # Change to home directory
    local original_dir=$(pwd)
    cd /home/shaamil-karim || {
        debug_log "ERROR: Failed to change to /home/shaamil-karim"
        return 1
    }
    
    debug_log "Changed to directory: $(pwd)"
    debug_log "Running: python3 $PREPARE_DATASET_SCRIPT --tokenizer=$MODEL_NAME --stdout token-norm-dist --num-requests=$num_requests --input-mean=$isl --output-mean=$osl --input-stdev=0 --output-stdev=0"
    
    # Run dataset creation with explicit error handling
    local exit_code=0
    python3 "$PREPARE_DATASET_SCRIPT" \
        --tokenizer="$MODEL_NAME" \
        --stdout token-norm-dist \
        --num-requests="$num_requests" \
        --input-mean="$isl" \
        --output-mean="$osl" \
        --input-stdev=0 \
        --output-stdev=0 \
        > "$dataset_file" 2> "$log_file" || exit_code=$?
    
    # Return to original directory
    cd "$original_dir" || {
        debug_log "ERROR: Failed to return to original directory"
        return 1
    }
    
    if [[ $exit_code -eq 0 ]]; then
        local request_count
        request_count=$(wc -l < "$dataset_file" 2>/dev/null || echo "0")
        log_message "INFO" "Dataset created: $dataset_file ($request_count requests)"
        debug_log "Dataset creation successful, created $request_count requests"
        return 0
    else
        log_message "ERROR" "Dataset creation failed: ISL=$isl, OSL=$osl, Requests=$num_requests (exit code: $exit_code)"
        debug_log "Dataset creation failed with exit code $exit_code"
        if [[ -f "$log_file" ]]; then
            debug_log "Error log contents: $(cat "$log_file")"
        fi
        return $exit_code
    fi
}

# Function to run benchmark
run_benchmark() {
    local isl=$1
    local osl=$2
    local requests=$3
    local dataset_file="$SCRIPT_DIR/$DATASETS_DIR/synthetic_${isl}_${osl}_${requests}.jsonl"
    local output_file="$SCRIPT_DIR/$RESULTS_DIR/results_${isl}_${osl}_${requests}.json"
    local error_file="$SCRIPT_DIR/$LOGS_DIR/error_${isl}_${osl}_${requests}.log"
    
    debug_log "run_benchmark called with isl=$isl, osl=$osl, requests=$requests"
    debug_log "Dataset file: $dataset_file"
    debug_log "Output file: $output_file"
    debug_log "Error file: $error_file"
    
    log_message "INFO" "Starting benchmark: ISL=$isl, OSL=$osl, Requests=$requests"
    debug_log "Benchmark command preparation started"
    
    # Change to home directory
    local original_dir=$(pwd)
    cd /home/shaamil-karim || {
        debug_log "ERROR: Failed to change to /home/shaamil-karim"
        return 1
    }
    
    debug_log "About to execute trtllm-bench command"
    
    # Run the benchmark with comprehensive error capture
    local exit_code=0
    timeout 1800 trtllm-bench \
        --model "$MODEL_NAME" \
        --dataset "$dataset_file" \
        --engine_dir "$ENGINE_DIR" \
        --output_file "$output_file" \
        --quantization "$QUANTIZATION" \
        --tp_size "$TP_SIZE" \
        --pp_size "$PP_SIZE" \
        > "$error_file" 2>&1 || exit_code=$?
    
    # Return to original directory
    cd "$original_dir" || {
        debug_log "ERROR: Failed to return to original directory"
        return 1
    }
    
    if [[ $exit_code -eq 0 ]]; then
        debug_log "trtllm-bench command completed with exit code $exit_code"
        log_message "INFO" "✓ Benchmark completed: ISL=$isl, OSL=$osl, Requests=$requests"
        safe_increment "COMPLETED_BENCHMARKS"
        return 0
    else
        debug_log "trtllm-bench command failed with exit code $exit_code"
        log_message "ERROR" "✗ Benchmark failed: ISL=$isl, OSL=$osl, Requests=$requests (exit code: $exit_code, see $error_file)"
        safe_increment "FAILED_BENCHMARKS"
        return $exit_code
    fi
}

# Function to update progress
update_progress() {
    local isl=$1
    local osl=$2
    local requests=$3
    local status=$4
    
    debug_log "update_progress called: $CURRENT_BENCHMARK/$TOTAL_BENCHMARKS - ISL=$isl, OSL=$osl, Requests=$requests, Status=$status"
    log_message "INFO" "Progress: $CURRENT_BENCHMARK/$TOTAL_BENCHMARKS - ISL=$isl, OSL=$osl, Requests=$requests ($status)"
}

# Trap function for cleanup
cleanup() {
    local exit_code=$?
    debug_log "cleanup function called with exit code $exit_code"
    log_message "INFO" "Received signal, shutting down gracefully..."
    log_message "INFO" "Final stats: Completed=$COMPLETED_BENCHMARKS, Failed=$FAILED_BENCHMARKS"
    exit $exit_code
}

# Set up signal traps
trap cleanup SIGINT SIGTERM

# Start logging
log_message "INFO" "Starting TensorRT-LLM Benchmark Sweep"
log_message "INFO" "Model: $MODEL_NAME"
log_message "INFO" "Configuration: TP=$TP_SIZE, PP=$PP_SIZE, Quantization=$QUANTIZATION"
log_message "INFO" "Engine Directory: $ENGINE_DIR"
log_message "INFO" "Dataset Script: $PREPARE_DATASET_SCRIPT"

debug_log "Script started with PID: $$"
debug_log "Current working directory: $(pwd)"
debug_log "Script directory: $SCRIPT_DIR"
debug_log "Config file: $CONFIG_FILE"

# Verify prepare_dataset.py exists
if [[ ! -f "$PREPARE_DATASET_SCRIPT" ]]; then
    log_message "ERROR" "Dataset preparation script not found: $PREPARE_DATASET_SCRIPT"
    exit 1
fi

# Count total benchmarks
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_message "ERROR" "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

TOTAL_BENCHMARKS=$(tail -n +2 "$CONFIG_FILE" | wc -l)
log_message "INFO" "Total benchmarks to run: $TOTAL_BENCHMARKS"
debug_log "Total benchmarks calculated: $TOTAL_BENCHMARKS"

# Validate CSV header
header=$(head -n 1 "$CONFIG_FILE")
debug_log "CSV header: $header"
if [[ "$header" != "isl,osl,num_requests" ]]; then
    log_message "ERROR" "Invalid CSV header. Expected 'isl,osl,num_requests', got '$header'"
    exit 1
fi

debug_log "Starting main benchmark loop"

# Main benchmark loop with enhanced error handling
while IFS=',' read -r isl osl requests; do
    debug_log "Loop iteration: read isl='$isl', osl='$osl', requests='$requests'"
    
    # Skip empty lines
    if [[ -z "$isl" || -z "$osl" || -z "$requests" ]]; then
        debug_log "Skipping empty line"
        continue
    fi
    
    # Validate that we have numeric values
    if ! [[ "$isl" =~ ^[0-9]+$ ]] || ! [[ "$osl" =~ ^[0-9]+$ ]] || ! [[ "$requests" =~ ^[0-9]+$ ]]; then
        debug_log "Skipping invalid line: isl='$isl', osl='$osl', requests='$requests'"
        log_message "WARNING" "Skipping invalid configuration: ISL=$isl, OSL=$osl, Requests=$requests"
        continue
    fi
    
    safe_increment "CURRENT_BENCHMARK"
    debug_log "Processing benchmark $CURRENT_BENCHMARK/$TOTAL_BENCHMARKS"
    
    update_progress "$isl" "$osl" "$requests" "running"
    
    # Create dataset with error handling
    debug_log "About to call create_dataset"
    if create_dataset "$isl" "$osl" "$requests"; then
        debug_log "create_dataset succeeded"
    else
        debug_log "create_dataset failed, continuing to next benchmark"
        log_message "ERROR" "Dataset creation failed for ISL=$isl, OSL=$osl, Requests=$requests. Continuing with next benchmark."
        continue
    fi
    
    # Run benchmark with error handling
    debug_log "About to call run_benchmark"
    if run_benchmark "$isl" "$osl" "$requests"; then
        debug_log "run_benchmark succeeded"
        update_progress "$isl" "$osl" "$requests" "completed"
    else
        debug_log "run_benchmark failed, continuing to next benchmark"
        log_message "INFO" "Continuing with next benchmark despite failure..."
        update_progress "$isl" "$osl" "$requests" "failed"
    fi
    
    debug_log "Completed processing benchmark $CURRENT_BENCHMARK"
    
done < <(tail -n +2 "$CONFIG_FILE")

debug_log "Main benchmark loop completed"

# Final summary
log_message "INFO" "=== Benchmark Sweep Complete ==="
log_message "INFO" "Total benchmarks: $TOTAL_BENCHMARKS"
log_message "INFO" "Completed successfully: $COMPLETED_BENCHMARKS"
log_message "INFO" "Failed: $FAILED_BENCHMARKS"

debug_log "Script completed successfully"
