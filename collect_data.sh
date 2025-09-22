#!/bin/bash

# Script to collect convergence data for different network sizes, algorithms, and topologies

# Define network sizes to test
NETWORK_SIZES=(10 20 50 100 200 500)

# Define algorithms to test
ALGORITHMS=("gossip" "push-sum")

# Define topologies to test
TOPOLOGIES=("full" "line" "3d" "imperfect3d")

# Output file for data
OUTPUT_FILE="convergence_data.csv"

# Create CSV header
echo "network_size,algorithm,topology,convergence_time" > $OUTPUT_FILE

# Function to run simulation and extract convergence time
run_simulation() {
    local size=$1
    local algorithm=$2
    local topology=$3
    
    echo "Running: size=$size, algorithm=$algorithm, topology=$topology"
    
    # Run the simulation and capture output
    output=$(gleam run -- $size $topology $algorithm 2>/dev/null)
    
    # Extract convergence time (last line of output)
    convergence_time=$(echo "$output" | tail -n 1 | tr -d '\n')
    
    # Check if we got a valid number
    if [[ $convergence_time =~ ^[0-9]+$ ]]; then
        echo "$size,$algorithm,$topology,$convergence_time" >> $OUTPUT_FILE
        echo "  -> Convergence time: $convergence_time"
    else
        echo "  -> Failed to get convergence time"
        echo "$size,$algorithm,$topology,-1" >> $OUTPUT_FILE
    fi
}

# Build the project first
echo "Building project..."
gleam build

# Run simulations for all combinations
for size in "${NETWORK_SIZES[@]}"; do
    for algorithm in "${ALGORITHMS[@]}"; do
        for topology in "${TOPOLOGIES[@]}"; do
            run_simulation $size $algorithm $topology
        done
    done
done

echo "Data collection complete. Results saved to $OUTPUT_FILE"
