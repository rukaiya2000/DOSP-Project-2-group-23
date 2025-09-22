#!/usr/bin/env python3
"""
Script to generate convergence plots for gossip and push-sum algorithms
across different network sizes and topologies.
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os

# Set up matplotlib for better looking plots
plt.style.use('seaborn-v0_8')
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 12

def load_data():
    """Load the convergence data from CSV file."""
    return pd.read_csv('convergence_data.csv')

def create_plots(df):
    """Create convergence plots for all algorithms and topologies."""
    
    # Create figure with subplots
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle('Convergence Time vs Network Size for Different Algorithms and Topologies', 
                 fontsize=16, fontweight='bold')
    
    # Flatten axes for easier iteration
    axes = axes.flatten()
    
    # Get unique algorithms and topologies
    algorithms = df['algorithm'].unique()
    topologies = df['topology'].unique()
    
    # Color and marker schemes
    colors = {'gossip': '#2E86AB', 'push-sum': '#A23B72'}
    markers = {'full': 'o', 'line': 's', '3d': '^', 'imperfect3d': 'D'}
    
    # Plot for each topology
    for i, topology in enumerate(topologies):
        ax = axes[i]
        
        # Filter data for this topology
        topology_data = df[df['topology'] == topology]
        
        # Plot each algorithm
        for algorithm in algorithms:
            algorithm_data = topology_data[topology_data['algorithm'] == algorithm]
            
            # Handle convergence cap (50000) - these are non-converging cases
            convergence_times = algorithm_data['convergence_time'].values
            network_sizes = algorithm_data['network_size'].values
            
            # Create a mask for non-converging cases
            converged_mask = convergence_times < 50000
            
            # Plot converged points
            if np.any(converged_mask):
                ax.plot(network_sizes[converged_mask], 
                       convergence_times[converged_mask],
                       marker=markers[topology],
                       color=colors[algorithm],
                       markersize=8,
                       linewidth=2,
                       label=f'{algorithm.capitalize()} (converged)',
                       alpha=0.8)
            
            # Plot non-converged points with different style
            if np.any(~converged_mask):
                ax.plot(network_sizes[~converged_mask], 
                       convergence_times[~converged_mask],
                       marker=markers[topology],
                       color=colors[algorithm],
                       markersize=8,
                       linestyle='--',
                       linewidth=2,
                       alpha=0.5,
                       label=f'{algorithm.capitalize()} (did not converge)',
                       markerfacecolor='none',
                       markeredgewidth=2)
        
        ax.set_xlabel('Network Size')
        ax.set_ylabel('Convergence Time (rounds)')
        ax.set_title(f'{topology.capitalize()} Topology')
        ax.legend()
        ax.grid(True, alpha=0.3)
        ax.set_xscale('log')
        ax.set_yscale('log')
        
        # Set reasonable axis limits
        ax.set_xlim(8, 600)
        ax.set_ylim(0.8, 100000)
    
    plt.tight_layout()
    plt.savefig('convergence_analysis.png', dpi=300, bbox_inches='tight')
    print("Plot saved as 'convergence_analysis.png'")
    
    # Create a summary plot comparing algorithms across all topologies
    create_summary_plot(df)

def create_summary_plot(df):
    """Create a summary plot comparing algorithms."""
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
    
    # Colors for topologies
    topology_colors = {
        'full': '#1f77b4',
        'line': '#ff7f0e', 
        '3d': '#2ca02c',
        'imperfect3d': '#d62728'
    }
    
    # Plot 1: Gossip Algorithm
    gossip_data = df[df['algorithm'] == 'gossip']
    for topology in gossip_data['topology'].unique():
        topology_data = gossip_data[gossip_data['topology'] == topology]
        ax1.plot(topology_data['network_size'], topology_data['convergence_time'],
                marker='o', linewidth=2, markersize=8,
                color=topology_colors[topology],
                label=f'{topology.capitalize()}')
    
    ax1.set_xlabel('Network Size')
    ax1.set_ylabel('Convergence Time (rounds)')
    ax1.set_title('Gossip Algorithm - All Topologies')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    ax1.set_xscale('log')
    ax1.set_yscale('log')
    ax1.set_xlim(8, 600)
    ax1.set_ylim(0.8, 1000)
    
    # Plot 2: Push-Sum Algorithm
    pushsum_data = df[df['algorithm'] == 'push-sum']
    for topology in pushsum_data['topology'].unique():
        topology_data = pushsum_data[pushsum_data['topology'] == topology]
        convergence_times = topology_data['convergence_time'].values
        network_sizes = topology_data['network_size'].values
        
        # Handle non-converging cases
        converged_mask = convergence_times < 50000
        
        if np.any(converged_mask):
            ax2.plot(network_sizes[converged_mask], convergence_times[converged_mask],
                    marker='s', linewidth=2, markersize=8,
                    color=topology_colors[topology],
                    label=f'{topology.capitalize()} (converged)')
        
        if np.any(~converged_mask):
            ax2.plot(network_sizes[~converged_mask], convergence_times[~converged_mask],
                    marker='s', linewidth=2, markersize=8,
                    color=topology_colors[topology],
                    linestyle='--', alpha=0.5,
                    label=f'{topology.capitalize()} (did not converge)',
                    markerfacecolor='none', markeredgewidth=2)
    
    ax2.set_xlabel('Network Size')
    ax2.set_ylabel('Convergence Time (rounds)')
    ax2.set_title('Push-Sum Algorithm - All Topologies')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    ax2.set_xscale('log')
    ax2.set_yscale('log')
    ax2.set_xlim(8, 600)
    ax2.set_ylim(0.8, 100000)
    
    plt.tight_layout()
    plt.savefig('convergence_summary.png', dpi=300, bbox_inches='tight')
    print("Summary plot saved as 'convergence_summary.png'")

def print_statistics(df):
    """Print summary statistics."""
    print("\n=== CONVERGENCE ANALYSIS SUMMARY ===\n")
    
    # Overall statistics
    print("Overall Statistics:")
    print(f"Total simulations run: {len(df)}")
    print(f"Network sizes tested: {sorted(df['network_size'].unique())}")
    print(f"Algorithms tested: {list(df['algorithm'].unique())}")
    print(f"Topologies tested: {list(df['topology'].unique())}")
    
    # Convergence success rate
    total_simulations = len(df)
    converged_simulations = len(df[df['convergence_time'] < 50000])
    convergence_rate = (converged_simulations / total_simulations) * 100
    print(f"\nConvergence Success Rate: {convergence_rate:.1f}% ({converged_simulations}/{total_simulations})")
    
    # Statistics by algorithm
    print("\n--- By Algorithm ---")
    for algorithm in df['algorithm'].unique():
        algo_data = df[df['algorithm'] == algorithm]
        converged = len(algo_data[algo_data['convergence_time'] < 50000])
        total = len(algo_data)
        rate = (converged / total) * 100
        avg_time = algo_data[algo_data['convergence_time'] < 50000]['convergence_time'].mean()
        print(f"{algorithm.capitalize()}:")
        print(f"  Success rate: {rate:.1f}% ({converged}/{total})")
        if not pd.isna(avg_time):
            print(f"  Avg convergence time: {avg_time:.1f} rounds")
    
    # Statistics by topology
    print("\n--- By Topology ---")
    for topology in df['topology'].unique():
        topo_data = df[df['topology'] == topology]
        converged = len(topo_data[topo_data['convergence_time'] < 50000])
        total = len(topo_data)
        rate = (converged / total) * 100
        avg_time = topo_data[topo_data['convergence_time'] < 50000]['convergence_time'].mean()
        print(f"{topology.capitalize()}:")
        print(f"  Success rate: {rate:.1f}% ({converged}/{total})")
        if not pd.isna(avg_time):
            print(f"  Avg convergence time: {avg_time:.1f} rounds")

def main():
    """Main function to generate plots and statistics."""
    print("Loading convergence data...")
    df = load_data()
    
    print("Generating plots...")
    create_plots(df)
    
    print("Generating statistics...")
    print_statistics(df)
    
    print("\n=== PLOTS GENERATED ===")
    print("1. convergence_analysis.png - Detailed analysis by topology")
    print("2. convergence_summary.png - Summary comparison by algorithm")
    print("\nBoth plots saved in the project root directory.")

if __name__ == "__main__":
    main()
