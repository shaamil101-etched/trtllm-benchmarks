# TensorRT-LLM Benchmark Suite

A comprehensive benchmarking suite for TensorRT-LLM with extensive configuration testing across various models and sequence lengths.

## Repository Contents

### 🔥 **NEW: Llama 3.1 8B Results** (July 2025)
- **Location**: `llama-8b-results/`
- **Model**: meta-llama/Llama-3.1-8B-Instruct
- **Hardware**: Single NVIDIA H100 80GB
- **Peak Performance**: **19,787 tokens/sec**
- **Configurations**: 63/64 successful benchmarks
- **Key Features**: FP8 quantization, synthetic dataset generation, comprehensive analysis

### 📊 **Original: Llama 3.1 70B Results** (Previous)
- **Location**: `scripts/`, `results/`, `benchmark_sweep/` (root level)
- **Model**: Llama-3.1-70B-Instruct  
- **Hardware**: 8x H100 GPUs (TP=8)
- **Configurations**: 64 different ISL/OSL combinations
- **Status**: Complete historical benchmark suite

## Quick Start - Llama 8B

```bash
cd llama-8b-results/

# View complete results
cat analysis/throughput_summary.csv

# Run individual benchmark
python3 scripts/create_synthetic_dataset.py --num_requests 1000 --input_length 128 --output_length 512 --output_file dataset.jsonl
trtllm-bench --model meta-llama/Llama-3.1-8B-Instruct throughput --engine_dir /path/to/engine --dataset dataset.jsonl

# Run full benchmark suite
chmod +x benchmark_sweep/sweep_runner_8b_fixed.sh
nohup ./benchmark_sweep/sweep_runner_8b_fixed.sh > logs/benchmark.out 2>&1 &
```

## Performance Comparison

| Model | Hardware | Peak Throughput | Efficiency |
|-------|----------|----------------|------------|
| **Llama 3.1 8B** | 1x H100 | **19,787 tok/sec** | 19,787 tok/sec per GPU |
| **Llama 3.1 70B** | 8x H100 | ~19,787 tok/sec | ~2,473 tok/sec per GPU |

*The 8B model demonstrates exceptional single-GPU efficiency!*

## Repository Structure

```
trtllm-benchmarks/
├── llama-8b-results/              # 🔥 NEW: Complete 8B benchmark suite
│   ├── README.md                  # Detailed 8B documentation
│   ├── analysis/                  # Performance analysis and CSV results
│   ├── benchmark_sweep/           # 8B benchmark execution files
│   └── scripts/                   # 8B-specific utilities
├── scripts/                       # Original 70B benchmark scripts
├── results/                       # Original 70B results
├── benchmark_sweep/               # Original 70B sweep files
└── README.md                      # This file
```

## Key Features

### Llama 8B Suite Features
- **Synthetic Dataset Generation**: Automated dataset creation for any ISL/OSL
- **Comprehensive Coverage**: 8x8 configuration matrix testing
- **Real-time Monitoring**: Live progress tracking and statistics
- **Memory Optimization**: Efficient single-GPU utilization
- **Detailed Analysis**: Complete performance breakdown and insights

### Original 70B Suite Features  
- **Multi-GPU Scaling**: Tensor parallelism across 8 H100 GPUs
- **Production Scale**: Large-scale model benchmarking
- **Historical Results**: Complete 64-configuration test suite
- **Memory Management**: Large model optimization techniques

## Contributing

When adding new benchmark results:
1. Create a dedicated directory (e.g., `llama-[size]b-results/`)
2. Include comprehensive README and analysis
3. Separate scripts and results clearly
4. Update this main README with comparison data

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---
*Updated July 12, 2025 - Added Llama 3.1 8B comprehensive benchmark results*
