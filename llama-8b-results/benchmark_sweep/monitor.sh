#!/bin/bash

# Monitor script for benchmark sweep
SWEEP_DIR="/home/shaamil-karim/benchmark_sweep"

# Function to show current status
show_status() {
    echo "======================================"
    echo "TensorRT-LLM Benchmark Sweep Monitor"
    echo "======================================"
    echo "Current time: $(date)"
    echo ""
    
    if [ -f "$SWEEP_DIR/progress.txt" ]; then
        echo "Current Progress:"
        cat "$SWEEP_DIR/progress.txt"
        echo ""
    fi
    
    echo "Quick Stats:"
    echo "- Completed results: $(ls -1 "$SWEEP_DIR/results/result_*.txt" 2>/dev/null | wc -l)"
    echo "- Failed benchmarks: $(ls -1 "$SWEEP_DIR/logs/error_*.log" 2>/dev/null | wc -l)"
    echo "- Log file size: $(du -h "$SWEEP_DIR/logs/sweep.log" 2>/dev/null | cut -f1 || echo "N/A")"
    echo ""
    
    echo "Latest log entries:"
    if [ -f "$SWEEP_DIR/logs/sweep.log" ]; then
        tail -10 "$SWEEP_DIR/logs/sweep.log"
    else
        echo "No log file found"
    fi
    
    echo ""
    echo "Process status:"
    if pgrep -f "sweep_runner.sh" > /dev/null; then
        echo "✓ Sweep runner is active (PID: $(pgrep -f "sweep_runner.sh"))"
    else
        echo "✗ No sweep runner process found"
    fi
    
    if pgrep -f "trtllm-bench" > /dev/null; then
        echo "✓ TensorRT-LLM benchmark is running (PID: $(pgrep -f "trtllm-bench"))"
    else
        echo "- No active benchmark process"
    fi
}

# Function to show GPU utilization
show_gpu_status() {
    echo ""
    echo "GPU Status:"
    nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
    echo ""
}

# Continuous monitoring
monitor_continuous() {
    while true; do
        clear
        show_status
        show_gpu_status
        echo "Press Ctrl+C to exit monitoring"
        sleep 30
    done
}

# Parse command line arguments
case "${1:-status}" in
    "status")
        show_status
        ;;
    "continuous"|"watch")
        monitor_continuous
        ;;
    "gpu")
        show_gpu_status
        ;;
    "logs")
        if [ -f "$SWEEP_DIR/logs/sweep.log" ]; then
            tail -f "$SWEEP_DIR/logs/sweep.log"
        else
            echo "No log file found"
        fi
        ;;
    "results")
        echo "Completed benchmarks:"
        ls -la "$SWEEP_DIR/results/result_*.txt" 2>/dev/null || echo "No results found"
        ;;
    "errors")
        echo "Failed benchmarks:"
        ls -la "$SWEEP_DIR/logs/error_*.log" 2>/dev/null || echo "No errors found"
        if [ -n "$(ls -A "$SWEEP_DIR/logs/error_*.log" 2>/dev/null)" ]; then
            echo ""
            echo "Recent errors:"
            for error_file in "$SWEEP_DIR/logs/error_"*.log; do
                if [ -f "$error_file" ]; then
                    echo "--- $(basename "$error_file") ---"
                    tail -5 "$error_file"
                    echo ""
                fi
            done
        fi
        ;;
    *)
        echo "Usage: $0 [status|continuous|gpu|logs|results|errors]"
        echo ""
        echo "Commands:"
        echo "  status      - Show current status (default)"
        echo "  continuous  - Continuous monitoring with refresh"
        echo "  gpu         - Show GPU utilization"
        echo "  logs        - Follow main log file"
        echo "  results     - List completed benchmarks"
        echo "  errors      - Show failed benchmarks and recent errors"
        ;;
esac
