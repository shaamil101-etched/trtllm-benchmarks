#!/usr/bin/env python3
"""
TensorRT-LLM Benchmark Results Analysis
Analyzes the comprehensive benchmark results and generates insights
"""

import csv
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

def load_results(file_path):
    """Load benchmark results from CSV file"""
    results = []
    with open(file_path, 'r') as f:
        # Skip header lines
        lines = f.readlines()
        header_idx = None
        for i, line in enumerate(lines):
            if line.startswith('ISL,OSL'):
                header_idx = i
                break
        
        if header_idx is not None:
            reader = csv.DictReader(lines[header_idx:])
            for row in reader:
                if row['Status'] == 'SUCCESS':
                    results.append({
                        'ISL': int(row['ISL']),
                        'OSL': int(row['OSL']),
                        'Requests': int(row['Requests']),
                        'Throughput': float(row['Throughput(tokens/sec)']),
                        'Latency': float(row['Latency(ms)'])
                    })
    return results

def analyze_performance(results):
    """Analyze performance patterns"""
    print("=== TensorRT-LLM Benchmark Analysis ===\n")
    
    # Basic statistics
    throughputs = [r['Throughput'] for r in results]
    latencies = [r['Latency'] for r in results]
    
    print(f"Total Successful Configurations: {len(results)}")
    print(f"Throughput Range: {min(throughputs):.1f} - {max(throughputs):.1f} tokens/sec")
    print(f"Latency Range: {min(latencies):.1f} - {max(latencies):.1f} ms")
    print(f"Average Throughput: {np.mean(throughputs):.1f} tokens/sec")
    print(f"Average Latency: {np.mean(latencies):.1f} ms\n")
    
    # Best performing configurations
    best_throughput = max(results, key=lambda x: x['Throughput'])
    best_latency = min(results, key=lambda x: x['Latency'])
    
    print("Best Performing Configurations:")
    print(f"Highest Throughput: {best_throughput['Throughput']:.1f} tokens/sec")
    print(f"  - ISL: {best_throughput['ISL']}, OSL: {best_throughput['OSL']}")
    print(f"Lowest Latency: {best_latency['Latency']:.1f} ms")
    print(f"  - ISL: {best_latency['ISL']}, OSL: {best_latency['OSL']}\n")
    
    # ISL vs OSL analysis
    isl_groups = {}
    osl_groups = {}
    
    for result in results:
        isl = result['ISL']
        osl = result['OSL']
        
        if isl not in isl_groups:
            isl_groups[isl] = []
        isl_groups[isl].append(result['Throughput'])
        
        if osl not in osl_groups:
            osl_groups[osl] = []
        osl_groups[osl].append(result['Throughput'])
    
    print("Average Throughput by Input Sequence Length:")
    for isl in sorted(isl_groups.keys()):
        avg_throughput = np.mean(isl_groups[isl])
        print(f"  ISL {isl:5d}: {avg_throughput:8.1f} tokens/sec")
    
    print("\nAverage Throughput by Output Sequence Length:")
    for osl in sorted(osl_groups.keys()):
        avg_throughput = np.mean(osl_groups[osl])
        print(f"  OSL {osl:5d}: {avg_throughput:8.1f} tokens/sec")

def create_visualizations(results):
    """Create performance visualizations"""
    print("\n=== Creating Visualizations ===")
    
    # Throughput heatmap
    isl_values = sorted(set(r['ISL'] for r in results))
    osl_values = sorted(set(r['OSL'] for r in results))
    
    throughput_matrix = np.zeros((len(isl_values), len(osl_values)))
    
    for result in results:
        isl_idx = isl_values.index(result['ISL'])
        osl_idx = osl_values.index(result['OSL'])
        throughput_matrix[isl_idx, osl_idx] = result['Throughput']
    
    plt.figure(figsize=(12, 8))
    plt.imshow(throughput_matrix, cmap='YlOrRd', aspect='auto')
    plt.colorbar(label='Throughput (tokens/sec)')
    plt.xlabel('Output Sequence Length')
    plt.ylabel('Input Sequence Length')
    plt.title('TensorRT-LLM Throughput Heatmap')
    plt.xticks(range(len(osl_values)), osl_values)
    plt.yticks(range(len(isl_values)), isl_values)
    
    # Add text annotations
    for i in range(len(isl_values)):
        for j in range(len(osl_values)):
            if throughput_matrix[i, j] > 0:
                plt.text(j, i, f'{throughput_matrix[i, j]:.0f}', 
                        ha='center', va='center', fontsize=8)
    
    plt.tight_layout()
    plt.savefig('throughput_heatmap.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    # Throughput vs Sequence Length
    plt.figure(figsize=(10, 6))
    total_lengths = [r['ISL'] + r['OSL'] for r in results]
    throughputs = [r['Throughput'] for r in results]
    
    plt.scatter(total_lengths, throughputs, alpha=0.6)
    plt.xlabel('Total Sequence Length (ISL + OSL)')
    plt.ylabel('Throughput (tokens/sec)')
    plt.title('Throughput vs Total Sequence Length')
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig('throughput_vs_length.png', dpi=300, bbox_inches='tight')
    plt.show()

if __name__ == "__main__":
    # Load results
    results_file = Path("../results/summary_results.log")
    if results_file.exists():
        results = load_results(results_file)
        analyze_performance(results)
        
        try:
            create_visualizations(results)
        except ImportError:
            print("Matplotlib not available. Skipping visualizations.")
    else:
        print(f"Results file not found: {results_file}")
