#!/bin/bash

echo "================================================================="
echo "=== TensorRT-LLM Three Configuration Loop Test ==="
echo "================================================================="
echo "Start Time: $(date)"
echo ""

# Setup environment
export LD_LIBRARY_PATH=/home/shaamil-karim/.local/lib/python3.10/site-packages/tensorrt_libs:/home/shaamil-karim/.local/lib/python3.10/site-packages/tensorrt_llm/libs:$LD_LIBRARY_PATH
ENGINE_DIR="/tmp/meta-llama/Llama-3.1-70B-Instruct/tp_8_pp_1"

# Create directories
mkdir -p /tmp/test_results
mkdir -p /tmp/test_datasets

# Initialize main log
MAIN_LOG="/tmp/test_results/main_execution.log"
echo "=== TensorRT-LLM Loop Test Started ===" > $MAIN_LOG
echo "Start Time: $(date)" >> $MAIN_LOG
echo "" >> $MAIN_LOG

# Configuration array - each element is "isl,osl,num_requests"
configs=(
    "128,128,100"
    "256,1024,1"
    "2048,128,5"
)

echo "📋 Configurations to process: ${#configs[@]}"
for i in "${!configs[@]}"; do
    echo "  Config $((i+1)): ${configs[i]}"
done
echo ""

# Process each configuration
for i in "${!configs[@]}"; do
    # Parse configuration
    IFS=',' read -r isl osl num_requests <<< "${configs[i]}"
    
    config_num=$((i+1))
    echo "================================================================="
    echo "=== Processing Config $config_num of ${#configs[@]}: ISL=$isl, OSL=$osl, Requests=$num_requests ==="
    echo "================================================================="
    
    # Log to main log
    echo "$(date): Starting Config $config_num: ISL=$isl, OSL=$osl, Requests=$num_requests" >> $MAIN_LOG
    
    # Define file paths
    dataset_file="/tmp/test_datasets/synthetic_${isl}_${osl}_${num_requests}.txt"
    result_file="/tmp/test_results/result_${isl}_${osl}_${num_requests}.txt"
    detailed_log="/tmp/test_results/detailed_${isl}_${osl}_${num_requests}.log"
    
    echo "📁 Files for this config:"
    echo "  Dataset: $dataset_file"
    echo "  Results: $result_file"
    echo "  Detailed Log: $detailed_log"
    echo ""
    
    # Step 1: Create dataset
    echo "📊 Step 1: Creating dataset..."
    echo "Dataset creation started at $(date)" > $detailed_log
    echo "Command: python3 benchmarks/cpp/prepare_dataset.py --stdout --tokenizer meta-llama/Llama-3.1-70B-Instruct token-norm-dist --input-mean $isl --output-mean $osl --input-stdev 0 --output-stdev 0 --num-requests $num_requests" >> $detailed_log
    echo "" >> $detailed_log
    
    cd /home/shaamil-karim/TensorRT-LLM && python3 benchmarks/cpp/prepare_dataset.py \
        --stdout \
        --tokenizer meta-llama/Llama-3.1-70B-Instruct \
        token-norm-dist \
        --input-mean $isl \
        --output-mean $osl \
        --input-stdev 0 \
        --output-stdev 0 \
        --num-requests $num_requests > "$dataset_file" 2>> $detailed_log
    
    if [ $? -eq 0 ]; then
        lines=$(wc -l < "$dataset_file")
        echo "✅ Dataset created successfully: $lines lines"
        echo "$(date): Dataset created successfully: $lines lines" >> $MAIN_LOG
        echo "Dataset created successfully at $(date) - $lines lines" >> $detailed_log
    else
        echo "❌ Dataset creation failed!"
        echo "$(date): Dataset creation FAILED" >> $MAIN_LOG
        echo "Dataset creation failed at $(date)" >> $detailed_log
        continue
    fi
    
    # Step 2: Run benchmark
    echo "🚀 Step 2: Running benchmark..."
    echo "" >> $detailed_log
    echo "Benchmark started at $(date)" >> $detailed_log
    echo "Command: trtllm-bench --model meta-llama/Llama-3.1-70B-Instruct throughput --dataset $dataset_file --engine_dir $ENGINE_DIR" >> $detailed_log
    echo "" >> $detailed_log
    
    trtllm-bench \
        --model meta-llama/Llama-3.1-70B-Instruct \
        throughput \
        --dataset "$dataset_file" \
        --engine_dir "$ENGINE_DIR" > "$result_file" 2>> $detailed_log
    
    if [ $? -eq 0 ]; then
        echo "✅ Benchmark completed successfully!"
        echo "$(date): Benchmark completed successfully" >> $MAIN_LOG
        echo "Benchmark completed at $(date)" >> $detailed_log
        
        # Extract and display key metrics
        if grep -q "Token Throughput" "$result_file"; then
            throughput=$(grep "Token Throughput" "$result_file" | awk '{print $4}')
            latency=$(grep "Total Latency" "$result_file" | awk '{print $4}')
            avg_input=$(grep "Average Input Length" "$result_file" | awk '{print $5}')
            avg_output=$(grep "Average Output Length" "$result_file" | awk '{print $5}')
            
            echo "📊 Results:"
            echo "   Token Throughput: $throughput tokens/sec"
            echo "   Total Latency: $latency ms"
            echo "   Average Input Length: $avg_input tokens"
            echo "   Average Output Length: $avg_output tokens"
            
            echo "$(date): Results - Throughput: $throughput tokens/sec, Latency: $latency ms" >> $MAIN_LOG
        fi
    else
        echo "❌ Benchmark failed!"
        echo "$(date): Benchmark FAILED" >> $MAIN_LOG
        echo "Benchmark failed at $(date)" >> $detailed_log
    fi
    
    echo ""
    echo "Config $config_num completed. Next config in 2 seconds..."
    sleep 2
    echo ""
done

echo "================================================================="
echo "=== ALL CONFIGURATIONS COMPLETED ==="
echo "================================================================="
echo "End Time: $(date)"
echo ""

echo "📁 Generated Files:"
ls -la /tmp/test_results/
echo ""
echo "📁 Generated Datasets:"
ls -la /tmp/test_datasets/
echo ""

echo "$(date): All configurations completed successfully" >> $MAIN_LOG
echo "=== Test completed ===" >> $MAIN_LOG

