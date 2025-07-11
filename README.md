# TensorRT-LLM Benchmark Suite

A comprehensive benchmarking suite for TensorRT-LLM with extensive configuration testing across various input/output sequence lengths.

## Overview

This repository contains scripts and results from a comprehensive TensorRT-LLM benchmark study that tested 64 different configurations across 8 input sequence lengths (ISL) and 8 output sequence lengths (OSL) combinations.

## Key Results

- **Total Successful Benchmarks**: 63 out of 64 configurations
- **Execution Time**: ~7 hours (04:27 - 11:40 UTC)
- **Model**: Llama-3.1-70B-Instruct (TP=8, PP=1)
- **Total Requests Processed**: 221,675 requests across all configurations

## Repository Structure

```
tensorrt-llm-benchmark-suite/
├── scripts/                    # Benchmark scripts
│   ├── test_comprehensive_configs.sh  # Main successful script
│   ├── trtllm_benchmark.sh    # Original benchmark script
│   ├── test_three_configs.sh  # Test script for smaller runs
│   └── *.csv                  # Configuration files
├── results/                   # Complete benchmark results
│   ├── summary_results.log    # Performance summary
│   ├── main_execution.log     # Execution timeline
│   ├── full_execution.log     # Detailed execution log
│   ├── result_*.txt           # Individual benchmark results
│   └── detailed_*.log         # Detailed logs per configuration
├── benchmark_sweep/           # Alternative benchmark approach
│   ├── sweep_*.sh            # Various sweep scripts
│   ├── logs/                 # Engine build logs
│   └── sweep_config.csv      # Sweep configuration
└── logs/                     # Additional logs
```

## Performance Highlights

### Best Performing Configurations
- **Highest Throughput**: 19,787 tokens/sec (ISL=128, OSL=1024)
- **Lowest Latency**: 163,474 ms (ISL=8192, OSL=512)
- **Most Requests**: 30,000 requests (ISL=128, OSL=128)

### Configuration Matrix
| ISL\OSL | 128 | 256 | 512 | 1024 | 2048 | 4096 | 8192 | 16384 |
|---------|-----|-----|-----|------|------|------|------|-------|
| 128     | ✓   | ✓   | ✓   | ✓    | ✓    | ✓    | ✓    | ✓     |
| 256     | ✓   | ✓   | ✓   | ✓    | ✓    | ✓    | ✓    | ✓     |
| 512     | ✓   | ✓   | ✓   | ✓    | ✓    | ✓    | ✓    | ✓     |
| 1024    | ✓   | ✓   | ✓   | ✓    | ✓    | ✓    | ✓    | ✓     |
| 2048    | ✓   | ✓   | ✓   | ✓    | ✓    | ✓    | ✓    | ✓     |
| 4096    | ✓   | ✓   | ✓   | ✓    | ✓    | ✓    | ✓    | ✓     |
| 8192    | ✓   | ✓   | ✓   | ✓    | ✓    | ✓    | ✓    | ✓     |
| 16384   | ✓   | ✓   | ✓   | ✓    | ✓    | ✓    | ✓    | ✗     |

## Usage

### Running the Complete Benchmark Suite

```bash
# Make the script executable
chmod +x scripts/test_comprehensive_configs.sh

# Run the full benchmark suite
./scripts/test_comprehensive_configs.sh
```

### Running Individual Benchmarks

```bash
# Run a specific configuration
./scripts/trtllm_benchmark.sh meta-llama/Llama-3.1-70B-Instruct 128 128 1000 8 1 FP8
```

### Monitoring Progress

```bash
# Monitor real-time results
tail -f /tmp/test_results/summary_results.log

# Monitor execution progress
tail -f /tmp/test_results/main_execution.log
```

## Environment Setup

### Prerequisites
- CUDA-enabled GPU with sufficient VRAM
- TensorRT-LLM installed
- Python 3.10+
- Required environment variables set

### Environment Variables
export HF_TOKEN="your_huggingface_token_here"
```bash
export LD_LIBRARY_PATH=/home/shaamil-karim/.local/lib/python3.10/site-packages/tensorrt_libs:/home/shaamil-karim/.local/lib/python3.10/site-packages/tensorrt_llm/libs:$LD_LIBRARY_PATH
export HF_TOKEN="your_huggingface_token"
```

## Results Analysis

### Performance Trends
1. **Throughput**: Generally decreases with longer sequences
2. **Latency**: Increases with sequence length complexity
3. **Scaling**: Shows predictable scaling patterns across configurations

### Failed Configuration
- **ISL=16384, OSL=16384**: The only configuration that failed
- **Reason**: Likely memory constraints with maximum sequence lengths

## Key Files

### Scripts
- `test_comprehensive_configs.sh`: Main benchmark script that successfully ran all tests
- `trtllm_benchmark.sh`: Original benchmark wrapper script
- `sweep_*.sh`: Alternative benchmark sweep approaches

### Results
- `summary_results.log`: CSV format summary of all benchmark results
- `main_execution.log`: Timeline of benchmark execution
- `result_*.txt`: Individual TensorRT-LLM output for each configuration

### Configurations
- Request counts scaled inversely with sequence length complexity
- Higher sequence lengths used fewer requests to manage memory usage

## Lessons Learned

1. **Memory Management**: Very long sequences (32K+ total tokens) can cause failures
2. **Request Scaling**: Appropriate request count scaling is crucial for stability
3. **Execution Time**: Full benchmarks require significant time investment
4. **Engine Reuse**: Pre-built engines enable faster benchmark execution

## Future Improvements

1. **Memory Optimization**: Implement dynamic memory management
2. **Parallel Execution**: Run multiple configurations in parallel
3. **Result Visualization**: Add graphical performance analysis
4. **Error Recovery**: Implement retry logic for failed configurations

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve the benchmark suite.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
