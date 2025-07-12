#!/bin/bash

# TensorRT-LLM Benchmark Sweep Runner for 8B Model - FIXED VERSION
# This script runs throughput benchmarks for all configurations in sweep_config.csv

# Configuration
MODEL="meta-llama/Llama-3.1-8B-Instruct"
TP=1
PP=1
QUANTIZATION="FP8"
ENGINE_DIR="/tmp/meta-llama/Llama-3.1-8B-Instruct/tp_1_pp_1"
CONFIG_FILE="benchmark_sweep/sweep_config.csv"
DATASET_GENERATOR="create_synthetic_dataset.py"

# Directories
RESULTS_DIR="benchmark_sweep/results"
LOGS_DIR="benchmark_sweep/logs"
DATASETS_DIR="benchmark_sweep/datasets"
PROGRESS_FILE="benchmark_sweep/progress.txt"
SWEEP_LOG="benchmark_sweep/logs/sweep.log"

# Create directories if they don't exist
mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$DATASETS_DIR"

# Initialize log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting TensorRT-LLM Benchmark Sweep for 8B Model - FIXED" | tee -a "$SWEEP_LOG"
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
    echo "Completed benchmarks: $COMPLETED_BENCHMARKS" >> "$PROGRESS_FILE"
    echo "Failed benchmarks: $FAILED_BENCHMARKS" >> "$PROGRESS_FILE"
}

# Function to run benchmark
run_benchmark() {
    local isl=$1
    local osl=$2
    local requests=$3
    
    local dataset_file="$DATASETS_DIR/synthetic_${isl}_${osl}_${requests}.jsonl"
    local result_file="$RESULTS_DIR/result_${isl}_${osl}_${requests}.json"
    local error_file="$LOGS_DIR/error_${isl}_${osl}_${requests}.log"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting benchmark: ISL=$isl, OSL=$osl, Requests=$requests" | tee -a "$SWEEP_LOG"
    
    # Step 1: Generate synthetic dataset
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generating synthetic dataset..." | tee -a "$SWEEP_LOG"
    if ! python3 "$DATASET_GENERATOR" --num_requests "$requests" --input_length "$isl" --output_length "$osl" --output_file "$dataset_file" > "$error_file" 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Dataset generation failed: ISL=$isl, OSL=$osl, Requests=$requests (see $error_file)" | tee -a "$SWEEP_LOG"
        ((FAILED_BENCHMARKS++))
        return 1
    fi
    
    # Step 2: Run the benchmark
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running benchmark..." | tee -a "$SWEEP_LOG"
    if HF_TOKEN=$HF_TOKEN trtllm-bench \
        --model "$MODEL" \
        throughput \
        --engine_dir "$ENGINE_DIR" \
        --dataset "$dataset_file" \
        --num_requests "$requests" \
        >> "$error_file" 2>&1; then
        
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Benchmark completed: ISL=$isl, OSL=$osl, Requests=$requests" | tee -a "$SWEEP_LOG"
        ((COMPLETED_BENCHMARKS++))
        
        # Clean up dataset file to save space
        rm -f "$dataset_file"
        
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Benchmark failed: ISL=$isl, OSL=$osl, Requests=$requests (see $error_file)" | tee -a "$SWEEP_LOG"
        ((FAILED_BENCHMARKS++))
        return 1
    fi
}

# Read CSV into array to avoid file descriptor issues
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Reading configuration file..." | tee -a "$SWEEP_LOG"
readarray -t CONFIG_LINES < <(tail -n +2 "$CONFIG_FILE")

# Main benchmark loop
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting benchmark sweep..." | tee -a "$SWEEP_LOG"
for line in "${CONFIG_LINES[@]}"; do
    IFS=',' read -r isl osl requests <<< "$line"
    
    ((CURRENT_BENCHMARK++))
    update_progress "$isl" "$osl" "$requests" "running"
    
    if run_benchmark "$isl" "$osl" "$requests"; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Benchmark successful, moving to next..." | tee -a "$SWEEP_LOG"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Continuing with next benchmark despite failure..." | tee -a "$SWEEP_LOG"
    fi
    
    echo "" | tee -a "$SWEEP_LOG"
done

# Final summary
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Benchmark sweep completed!" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Total benchmarks: $TOTAL_BENCHMARKS" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $COMPLETED_BENCHMARKS" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $FAILED_BENCHMARKS" | tee -a "$SWEEP_LOG"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Success rate: $((COMPLETED_BENCHMARKS * 100 / TOTAL_BENCHMARKS))%" | tee -a "$SWEEP_LOG"

# Final progress update
echo "Progress: $TOTAL_BENCHMARKS/$TOTAL_BENCHMARKS (100%) - COMPLETED" > "$PROGRESS_FILE"
echo "Last updated: $(date)" >> "$PROGRESS_FILE"
echo "Completed benchmarks: $COMPLETED_BENCHMARKS" >> "$PROGRESS_FILE"
echo "Failed benchmarks: $FAILED_BENCHMARKS" >> "$PROGRESS_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Benchmark sweep completed successfully!" | tee -a "$SWEEP_LOG"
