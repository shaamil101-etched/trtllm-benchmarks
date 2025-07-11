#!/bin/bash

# TensorRT-LLM Benchmark Sweep Runner
# This script creates synthetic datasets and runs throughput benchmarks for all configurations

# Configuration
MODEL="meta-llama/Llama-3.1-70B"
TP=8
PP=1
QUANTIZATION="FP8"
ENGINE_DIR="/tmp/meta-llama/Llama-3.1-70B/tp_8_pp_1"
CONFIG_FILE="sweep_config.csv"

# Directories
DATASETS_DIR="datasets"
RESULTS_DIR="results"
LOGS_DIR="logs"
PROGRESS_FILE="progress.txt"
SWEEP_LOG="logs/sweep.log"

# Create directories if they don't exist
mkdir -p "$DATASETS_DIR" "$RESULTS_DIR" "$LOGS_DIR"

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

# Function to create synthetic dataset using official TensorRT-LLM script
create_dataset() {
    local isl=$1
    local osl=$2
    local requests=$3
    
    local dataset_file="$DATASETS_DIR/synthetic_${isl}_${osl}_${requests}.jsonl"
    
    # Check if dataset already exists and is not empty
    if [[ -f "$dataset_file" && -s "$dataset_file" ]]; then
        local file_requests=$(wc -l < "$dataset_file")
        if [[ $file_requests -ge $requests ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dataset already exists: $dataset_file ($file_requests requests)" | tee -a "$SWEEP_LOG"
            return 0
        fi
    fi
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating dataset: ISL=$isl, OSL=$osl, Requests=$requests" | tee -a "$SWEEP_LOG"
    
    # Create synthetic dataset using official TensorRT-LLM script
    if cd /home/shaamil-karim && python3 TensorRT-LLM/benchmarks/cpp/prepare_dataset.py \
        --stdout \
        --tokenizer "$MODEL" \
        token-norm-dist \
        --input-mean "$isl" \
        --output-mean "$osl" \
        --input-stdev 0 \
        --output-stdev 0 \
        --num-requests "$requests" \
        > "/home/shaamil-karim/benchmark_sweep/$dataset_file" \
        2> "/home/shaamil-karim/benchmark_sweep/$LOGS_DIR/dataset_creation_${isl}_${osl}_${requests}.log"; then
        
        local created_requests=$(wc -l < "/home/shaamil-karim/benchmark_sweep/$dataset_file")
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ Dataset created: $dataset_file ($created_requests requests)" | tee -a "$SWEEP_LOG"
        return 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✗ Failed to create dataset: $dataset_file" | tee -a "$SWEEP_LOG"
        return 1
    fi
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
    
    # Run the benchmark using dataset file
    if cd /home/shaamil-karim && HF_TOKEN=$HF_TOKEN trtllm-bench \
        --model "$MODEL" \
        throughput \
        --engine_dir "$ENGINE_DIR" \
        --dataset "benchmark_sweep/$dataset_file" \
        --num_requests "$requests" \
        > "benchmark_sweep/$error_file" 2>&1; then
        
        # Parse results from the error file (which contains the output)
        if grep -q "Token Throughput" "benchmark_sweep/$error_file"; then
            # Extract key metrics and save to result file
            {
                echo "{"
                echo "  \"timestamp\": \"$(date -Iseconds)\","
                echo "  \"config\": {"
                echo "    \"isl\": $isl,"
                echo "    \"output_length\": $osl,"
                echo "    \"num_requests\": $requests,"
                echo "    \"model\": \"$MODEL\","
                echo "    \"tp\": $TP,"
                echo "    \"pp\": $PP,"
                echo "    \"quantization\": \"$QUANTIZATION\""
                echo "  },"
                echo "  \"results\": {"
                grep "Token Throughput" "benchmark_sweep/$error_file" | sed 's/.*Token Throughput (tokens\/sec):\s*\([0-9.]*\).*/    "token_throughput": \1,/'
                grep "Request Throughput" "benchmark_sweep/$error_file" | sed 's/.*Request Throughput (req\/sec):\s*\([0-9.]*\).*/    "request_throughput": \1,/'
                grep "Total Latency" "benchmark_sweep/$error_file" | sed 's/.*Total Latency (ms):\s*\([0-9.]*\).*/    "total_latency_ms": \1/'
                echo "  }"
                echo "}"
            } > "benchmark_sweep/$result_file"
        fi
        
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
    
    ((CURRENT_BENCHMARK++))
    update_progress "$isl" "$osl" "$requests" "running"
    
    # Create dataset first
    if create_dataset "$isl" "$osl" "$requests"; then
        # Run benchmark
        if run_benchmark "$isl" "$osl" "$requests"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Benchmark successful, moving to next..." | tee -a "$SWEEP_LOG"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Continuing with next benchmark despite failure..." | tee -a "$SWEEP_LOG"
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skipping benchmark due to dataset creation failure..." | tee -a "$SWEEP_LOG"
        ((FAILED_BENCHMARKS++))
    fi
    
    echo "" | tee -a "$SWEEP_LOG"
    
done < <(tail -n +2 "$CONFIG_FILE")

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
