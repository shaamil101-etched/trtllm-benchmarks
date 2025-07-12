#!/bin/bash

echo "TensorRT-LLM Llama 3.1 8B Benchmark Sweep Monitor"
echo "=================================================="
echo

while true; do
    clear
    echo "TensorRT-LLM Llama 3.1 8B Benchmark Sweep Monitor"
    echo "=================================================="
    echo "Time: $(date)"
    echo

    # Check if process is running
    if ps aux | grep -q "[s]weep_runner_8b_final.sh"; then
        echo "✅ Benchmark sweep is RUNNING"
    else
        echo "❌ Benchmark sweep is NOT RUNNING"
    fi
    echo

    # Show progress
    if [ -f "benchmark_sweep/progress.txt" ]; then
        echo "📊 Progress:"
        cat benchmark_sweep/progress.txt
        echo
    fi

    # Show latest log entries
    if [ -f "benchmark_sweep/logs/sweep.log" ]; then
        echo "📝 Latest Log Entries:"
        tail -5 benchmark_sweep/logs/sweep.log
        echo
    fi

    # Show completed and failed benchmarks count
    if [ -d "benchmark_sweep/results" ]; then
        COMPLETED=$(ls benchmark_sweep/results/*.json 2>/dev/null | wc -l)
        echo "✅ Completed benchmarks: $COMPLETED"
    fi

    if [ -d "benchmark_sweep/logs" ]; then
        FAILED=$(ls benchmark_sweep/logs/error_*.log 2>/dev/null | wc -l)
        echo "❌ Error logs: $FAILED"
    fi

    echo
    echo "Press Ctrl+C to exit monitor (benchmark will continue running)"
    
    sleep 10
done
