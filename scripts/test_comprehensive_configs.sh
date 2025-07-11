#!/bin/bash

echo "================================================================="
echo "=== TensorRT-LLM Comprehensive Configuration Test ==="
echo "=== 64 Configurations: 8 ISL x 8 OSL combinations ==="
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
SUMMARY_LOG="/tmp/test_results/summary_results.log"
echo "=== TensorRT-LLM Comprehensive Test Started ===" > $MAIN_LOG
echo "Start Time: $(date)" >> $MAIN_LOG
echo "" >> $MAIN_LOG

# Initialize summary log
echo "=== TensorRT-LLM Comprehensive Test Results Summary ===" > $SUMMARY_LOG
echo "Start Time: $(date)" >> $SUMMARY_LOG
echo "" >> $SUMMARY_LOG
echo "ISL,OSL,Requests,Throughput(tokens/sec),Latency(ms),Status" >> $SUMMARY_LOG

# Comprehensive configuration array - 64 configurations
configs=(
    # ISL=128
    "128,128,30000"
    "128,256,20000"
    "128,512,15000"
    "128,1024,7500"
    "128,2048,3000"
    "128,4096,1500"
    "128,8192,750"
    "128,16384,400"
    
    # ISL=256
    "256,128,20000"
    "256,256,15000"
    "256,512,10000"
    "256,1024,6000"
    "256,2048,2500"
    "256,4096,1200"
    "256,8192,600"
    "256,16384,300"
    
    # ISL=512
    "512,128,15000"
    "512,256,10000"
    "512,512,7500"
    "512,1024,5000"
    "512,2048,2000"
    "512,4096,1000"
    "512,8192,500"
    "512,16384,250"
    
    # ISL=1024
    "1024,128,7500"
    "1024,256,6000"
    "1024,512,5000"
    "1024,1024,3000"
    "1024,2048,1500"
    "1024,4096,800"
    "1024,8192,400"
    "1024,16384,200"
    
    # ISL=2048
    "2048,128,3000"
    "2048,256,2500"
    "2048,512,2000"
    "2048,1024,1500"
    "2048,2048,1500"
    "2048,4096,750"
    "2048,8192,400"
    "2048,16384,200"
    
    # ISL=4096
    "4096,128,1500"
    "4096,256,1200"
    "4096,512,1000"
    "4096,1024,800"
    "4096,2048,750"
    "4096,4096,400"
    "4096,8192,200"
    "4096,16384,100"
    
    # ISL=8192
    "8192,128,750"
    "8192,256,600"
    "8192,512,500"
    "8192,1024,400"
    "8192,2048,400"
    "8192,4096,200"
    "8192,8192,150"
    "8192,16384,75"
    
    # ISL=16384
    "16384,128,400"
    "16384,256,300"
    "16384,512,250"
    "16384,1024,200"
    "16384,2048,200"
    "16384,4096,100"
    "16384,8192,75"
    "16384,16384,50"
)

echo "📋 Total configurations to process: ${#configs[@]}"
echo "⏱️  Estimated time: This will take several hours to complete"
echo ""

# Process each configuration
for i in "${!configs[@]}"; do
    # Parse configuration
    IFS=',' read -r isl osl num_requests <<< "${configs[i]}"
    
    config_num=$((i+1))
    echo "================================================================="
    echo "=== Config $config_num/${#configs[@]}: ISL=$isl, OSL=$osl, Requests=$num_requests ==="
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
    start_time=$(date)
    echo "Dataset creation started at $start_time" > $detailed_log
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
        echo "$isl,$osl,$num_requests,FAILED,FAILED,Dataset Creation Failed" >> $SUMMARY_LOG
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
            echo "$isl,$osl,$num_requests,$throughput,$latency,SUCCESS" >> $SUMMARY_LOG
        else
            echo "⚠️  Benchmark completed but no metrics found"
            echo "$isl,$osl,$num_requests,NO_METRICS,NO_METRICS,Completed but no metrics" >> $SUMMARY_LOG
        fi
    else
        echo "❌ Benchmark failed!"
        echo "$(date): Benchmark FAILED" >> $MAIN_LOG
        echo "Benchmark failed at $(date)" >> $detailed_log
        echo "$isl,$osl,$num_requests,FAILED,FAILED,Benchmark Failed" >> $SUMMARY_LOG
    fi
    
    # Progress update
    progress=$((config_num * 100 / ${#configs[@]}))
    echo ""
    echo "📈 Progress: $config_num/${#configs[@]} configs completed ($progress%)"
    echo "⏱️  Config $config_num completed at $(date)"
    echo ""
    
    # Brief pause between configs
    sleep 1
done

echo "================================================================="
echo "=== ALL CONFIGURATIONS COMPLETED ==="
echo "================================================================="
echo "End Time: $(date)"
echo ""

echo "📁 Generated Files:"
echo "Total result files: $(ls -1 /tmp/test_results/result_*.txt | wc -l)"
echo "Total detailed logs: $(ls -1 /tmp/test_results/detailed_*.log | wc -l)"
echo "Total datasets: $(ls -1 /tmp/test_datasets/synthetic_*.txt | wc -l)"
echo ""

echo "📊 Summary Report:"
echo "Check /tmp/test_results/summary_results.log for all results"
echo ""

echo "$(date): All configurations completed successfully" >> $MAIN_LOG
echo "=== Test completed ===" >> $MAIN_LOG

# Display summary
echo "📋 Final Summary:"
successful=$(grep "SUCCESS" $SUMMARY_LOG | wc -l)
failed=$(grep "FAILED" $SUMMARY_LOG | wc -l)
echo "✅ Successful: $successful"
echo "❌ Failed: $failed"
echo "📊 Total: $((successful + failed))"

