#!/usr/bin/env python3
import json
import sys
import random
import argparse

def generate_text_with_length(target_length, tokenizer=None):
    """Generate text with approximately target_length tokens"""
    # Simple word generation - approximately 1.3 tokens per word
    words_needed = max(1, int(target_length / 1.3))
    
    # Common words to use for generation
    common_words = [
        "the", "and", "to", "of", "a", "in", "that", "have", "i", "it", "for", "not", "on", "with", "he", "as", "you", "do", "at", "this", "but", "his", "by", "from", "they", "we", "say", "her", "she", "or", "an", "will", "my", "one", "all", "would", "there", "their", "what", "so", "up", "out", "if", "about", "who", "get", "which", "go", "when", "me", "make", "can", "like", "time", "no", "just", "him", "know", "take", "people", "into", "year", "your", "good", "some", "could", "them", "see", "other", "than", "then", "now", "look", "only", "come", "its", "over", "think", "also", "back", "after", "use", "two", "how", "our", "work", "first", "well", "way", "even", "new", "want", "because", "any", "these", "give", "day", "most", "us"
    ]
    
    text_parts = []
    for _ in range(words_needed):
        text_parts.append(random.choice(common_words))
    
    return " ".join(text_parts)

def create_synthetic_dataset(num_requests, input_length, output_length, output_file=None):
    """Create a synthetic dataset with specified parameters"""
    dataset = []
    
    for i in range(num_requests):
        # Generate prompt with target input length
        prompt = generate_text_with_length(input_length)
        
        # Create dataset entry
        entry = {
            "task_id": i + 1,
            "prompt": prompt,
            "output_tokens": output_length
        }
        
        dataset.append(entry)
    
    # Write to file or stdout
    if output_file:
        with open(output_file, 'w') as f:
            for entry in dataset:
                f.write(json.dumps(entry) + '\n')
    else:
        for entry in dataset:
            print(json.dumps(entry))

def main():
    parser = argparse.ArgumentParser(description='Create synthetic dataset for TensorRT-LLM benchmarking')
    parser.add_argument('--num_requests', type=int, required=True, help='Number of requests to generate')
    parser.add_argument('--input_length', type=int, required=True, help='Target input length in tokens')
    parser.add_argument('--output_length', type=int, required=True, help='Target output length in tokens')
    parser.add_argument('--output_file', type=str, help='Output file path (stdout if not specified)')
    
    args = parser.parse_args()
    
    create_synthetic_dataset(
        num_requests=args.num_requests,
        input_length=args.input_length,
        output_length=args.output_length,
        output_file=args.output_file
    )

if __name__ == "__main__":
    main()
