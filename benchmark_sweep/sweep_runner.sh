#!/bin/bash

# TensorRT-LLM Benchmark Sweep Runner
# This script runs throughput benchmarks for all configurations in sweep_config.csv

# Configuration
MODEL="meta-llama/Llama-3.1-70B"
TP=8
PP=1
QUANTIZATION="FP8"
ENGINE_DIR="/tmp/meta-llama/Llama-3.1-70B/tp_8_pp_1"
CONFIG_FILE="sweep_config.csv"

# Directories
RESULTS_DIR="results"
LOGS_DIR="logs"
PROGRESS_FILE="progress.txt"
SWEEP_LOG="logs/sweep.log"

# Create directories if they don't exist
mkdir -p "$RESULTS_DIR" "$LOGS_DIR"

# Initialize log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting TensorRT-LLM Benchmark Sweep" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Model: $MODEL" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuration: TP=$TP, PP=$PP, Quantization=$QUANTIZATION" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Engine Directory: $ENGINE_DIR" | tee -a "$SWEEP_LOG"

# Count total benchmarks
TOTAL_BENCHMARKS=$(tail -n +2 "$CONFIG_FILE" | wc -l)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Total benchmarks to run: $TOTAL_BENCHMARKS" | tee -a "$SWEEP_LOG"

# Initialize progress
CURRENT_BENCHMARK=0
COMPLETED_BENCHMARKS=0
FAILED_BENCHMARKS=0

# Function to update progress
update_progress() {
    local isl=$1
    local osl=$2
    local requests=$3
    local status=$4
    
    echo "Progress: $CURRENT_BENCHMARK/$TOTAL_BENCHMARKS ($((CURRENT_BENCHMARK * 100 / TOTAL_BENCHMARKS))%) - Current: ISL=$isl, OSL=$osl, Requests=$requests" > "$PROGRESS_FILE"
    echo "Last updated: $(date)" >> "$PROGRESS_FILE"
    echo "Completed benchmarks:" >> "$PROGRESS_FILE"
    echo "$COMPLETED_BENCHMARKS" >> "$PROGRESS_FILE"
    echo "Failed benchmarks:" >> "$PROGRESS_FILE"
    echo "$FAILED_BENCHMARKS" >> "$PROGRESS_FILE"
}

# Function to run benchmark
run_benchmark() {
    local isl=$1
    local osl=$2
    local requests=$3
    
    local result_file="$RESULTS_DIR/result_${isl}_${osl}_${requests}.json"
    local error_file="$LOGS_DIR/error_${isl}_${osl}_${requests}.log"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting benchmark: ISL=$isl, OSL=$osl, Requests=$requests" | tee -a "$SWEEP_LOG"
    
    # Run the benchmark using synthetic dataset
    if HF_TOKEN=$HF_TOKEN trtllm-bench \
        --model "$MODEL" \
        throughput \
        --engine_dir "$ENGINE_DIR" \
        --dataset "synthetic" \
        --num_requests "$requests" \
        --input_length "$isl" \
        --output_length "$osl" \
        --output_file "$result_file" \
        > "$error_file" 2>&1; then
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Benchmark completed: ISL=$isl, OSL=$osl, Requests=$requests" | tee -a "$SWEEP_LOG"
        ((COMPLETED_BENCHMARKS++))
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Benchmark failed: ISL=$isl, OSL=$osl, Requests=$requests (see $error_file)" | tee -a "$SWEEP_LOG"
        ((FAILED_BENCHMARKS++))
        return 1
    fi
}

# Main benchmark loop
while IFS=',' read -r isl osl requests; do
    # Skip header
    if [[ "$isl" == "input_length" ]]; then
        continue
    fi
    
    ((CURRENT_BENCHMARK++))
    update_progress "$isl" "$osl" "$requests" "running"
    
    if run_benchmark "$isl" "$osl" "$requests"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Benchmark successful, moving to next..." | tee -a "$SWEEP_LOG"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Continuing with next benchmark despite failure..." | tee -a "$SWEEP_LOG"
    fi
    
    echo "" | tee -a "$SWEEP_LOG"
    
done < "$CONFIG_FILE"

# Final summary
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Benchmark sweep completed!" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Total benchmarks: $TOTAL_BENCHMARKS" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $COMPLETED_BENCHMARKS" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $FAILED_BENCHMARKS" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Success rate: $((COMPLETED_BENCHMARKS * 100 / TOTAL_BENCHMARKS))%" | tee -a "$SWEEP_LOG"

# Final progress update
echo "Progress: $TOTAL_BENCHMARKS/$TOTAL_BENCHMARKS (100%) - COMPLETED" > "$PROGRESS_FILE"
echo "Last updated: $(date)" >> "$PROGRESS_FILE"
echo "Completed benchmarks:" >> "$PROGRESS_FILE"
echo "$COMPLETED_BENCHMARKS" >> "$PROGRESS_FILE"
echo "Failed benchmarks:" >> "$PROGRESS_FILE"
echo "$FAILED_BENCHMARKS" >> "$PROGRESS_FILE"
