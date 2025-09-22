#!/usr/bin/env python3
"""
Failure Model Analysis Plots
Generates comprehensive plots for analyzing the impact of failure models on gossip algorithms.
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
from matplotlib.ticker import ScalarFormatter

# Set style
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

# Read the data
df = pd.read_csv('graph-generation/data-set/failure_experiments_data.csv')

# Create figure with subplots
fig = plt.figure(figsize=(16, 12))
fig.suptitle('Impact of Failure Models on Gossip Algorithm Performance', fontsize=16, fontweight='bold')

# Plot 1: Node Failure Impact on Gossip Algorithm
ax1 = plt.subplot(2, 3, 1)
gossip_node_data = df[(df['algorithm'] == 'gossip') & (df['failure_model'] == 'node')]
for topology in gossip_node_data['topology'].unique():
    topology_data = gossip_node_data[gossip_node_data['topology'] == topology]
    plt.plot(topology_data['failure_rate'], topology_data['convergence_time_ms'], 
             marker='o', label=f'{topology.capitalize()} Topology', linewidth=2, markersize=8)

plt.xlabel('Node Failure Rate', fontsize=12)
plt.ylabel('Convergence Time (ms)', fontsize=12)
plt.title('Node Failure Impact on Gossip Algorithm', fontsize=14, fontweight='bold')
plt.legend()
plt.grid(True, alpha=0.3)

# Plot 2: Connection Failure Impact on Gossip Algorithm
ax2 = plt.subplot(2, 3, 2)
gossip_conn_data = df[(df['algorithm'] == 'gossip') & (df['failure_model'] == 'connection')]
for topology in gossip_conn_data['topology'].unique():
    topology_data = gossip_conn_data[gossip_conn_data['topology'] == topology]
    plt.plot(topology_data['failure_rate'], topology_data['convergence_time_ms'], 
             marker='s', label=f'{topology.capitalize()} Topology', linewidth=2, markersize=8)

plt.xlabel('Connection Failure Rate', fontsize=12)
plt.ylabel('Convergence Time (ms)', fontsize=12)
plt.title('Connection Failure Impact on Gossip Algorithm', fontsize=14, fontweight='bold')
plt.legend()
plt.grid(True, alpha=0.3)

# Plot 3: Connection Failure Impact on Push-Sum Algorithm
ax3 = plt.subplot(2, 3, 3)
pushsum_conn_data = df[(df['algorithm'] == 'push-sum') & (df['failure_model'] == 'connection')]
for topology in pushsum_conn_data['topology'].unique():
    topology_data = pushsum_conn_data[pushsum_conn_data['topology'] == topology]
    plt.plot(topology_data['failure_rate'], topology_data['convergence_time_ms'], 
             marker='^', label=f'{topology.capitalize()} Topology', linewidth=2, markersize=8)

plt.xlabel('Connection Failure Rate', fontsize=12)
plt.ylabel('Convergence Time (ms)', fontsize=12)
plt.title('Connection Failure Impact on Push-Sum Algorithm', fontsize=14, fontweight='bold')
plt.legend()
plt.grid(True, alpha=0.3)

# Plot 4: Comparison of Failure Models (Full Topology)
ax4 = plt.subplot(2, 3, 4)
full_data = df[df['topology'] == 'full']
baseline = full_data[full_data['failure_model'] == 'none']['convergence_time_ms'].values[0]

# Plot baseline
plt.axhline(y=baseline, color='black', linestyle='--', linewidth=2, label='No Failure Baseline')

# Plot node failures
node_data = full_data[full_data['failure_model'] == 'node']
plt.plot(node_data['failure_rate'], node_data['convergence_time_ms'], 
         marker='o', label='Node Failures', linewidth=2, markersize=8)

# Plot connection failures
conn_data = full_data[full_data['failure_model'] == 'connection']
plt.plot(conn_data['failure_rate'], conn_data['convergence_time_ms'], 
         marker='s', label='Connection Failures', linewidth=2, markersize=8)

plt.xlabel('Failure Rate', fontsize=12)
plt.ylabel('Convergence Time (ms)', fontsize=12)
plt.title('Failure Model Comparison (Full Topology)', fontsize=14, fontweight='bold')
plt.legend()
plt.grid(True, alpha=0.3)

# Plot 5: Algorithm Comparison with Connection Failures
ax5 = plt.subplot(2, 3, 5)
full_conn_data = df[(df['topology'] == 'full') & (df['failure_model'] == 'connection')]

for algorithm in full_conn_data['algorithm'].unique():
    algo_data = full_conn_data[full_conn_data['algorithm'] == algorithm]
    plt.plot(algo_data['failure_rate'], algo_data['convergence_time_ms'], 
             marker='D', label=f'{algorithm.replace("-", " ").capitalize()}', linewidth=2, markersize=8)

plt.xlabel('Connection Failure Rate', fontsize=12)
plt.ylabel('Convergence Time (ms)', fontsize=12)
plt.title('Algorithm Comparison with Connection Failures', fontsize=14, fontweight='bold')
plt.legend()
plt.grid(True, alpha=0.3)

# Plot 6: Performance Degradation Analysis
ax6 = plt.subplot(2, 3, 6)
# Calculate performance degradation relative to baseline
full_data = df[df['topology'] == 'full']
baseline = full_data[full_data['failure_model'] == 'none']['convergence_time_ms'].values[0]

degradation_data = []
for _, row in full_data.iterrows():
    if row['failure_model'] != 'none':
        degradation = (row['convergence_time_ms'] - baseline) / baseline * 100
        degradation_data.append({
            'failure_model': row['failure_model'],
            'failure_rate': row['failure_rate'],
            'degradation_pct': degradation
        })

deg_df = pd.DataFrame(degradation_data)

for model in deg_df['failure_model'].unique():
    model_data = deg_df[deg_df['failure_model'] == model]
    plt.plot(model_data['failure_rate'], model_data['degradation_pct'], 
             marker='*', label=f'{model.replace("-", " ").capitalize()} Failures', linewidth=2, markersize=10)

plt.xlabel('Failure Rate', fontsize=12)
plt.ylabel('Performance Degradation (%)', fontsize=12)
plt.title('Performance Degradation Analysis', fontsize=14, fontweight='bold')
plt.legend()
plt.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('graph-generation/failure_analysis_plots.png', dpi=300, bbox_inches='tight')
plt.show()

# Create a separate detailed plot for Push-Sum connection failures
fig2, ax = plt.subplots(figsize=(10, 6))
pushsum_conn_data = df[(df['algorithm'] == 'push-sum') & (df['failure_model'] == 'connection')]

plt.plot(pushsum_conn_data['failure_rate'], pushsum_conn_data['convergence_time_ms'], 
         marker='o', linewidth=3, markersize=10, color='red', label='Push-Sum with Connection Failures')

# Add baseline for comparison
pushsum_baseline = df[(df['algorithm'] == 'push-sum') & (df['failure_model'] == 'none') & (df['topology'] == 'full')]['convergence_time_ms'].values[0]
plt.axhline(y=pushsum_baseline, color='blue', linestyle='--', linewidth=2, label='Push-Sum Baseline (No Failures)')

plt.xlabel('Connection Failure Rate', fontsize=14)
plt.ylabel('Convergence Time (ms)', fontsize=14)
plt.title('Push-Sum Algorithm Performance with Connection Failures', fontsize=16, fontweight='bold')
plt.legend(fontsize=12)
plt.grid(True, alpha=0.3)
plt.xticks(fontsize=12)
plt.yticks(fontsize=12)

plt.tight_layout()
plt.savefig('graph-generation/pushsum_connection_failure_analysis.png', dpi=300, bbox_inches='tight')
plt.show()

# Print summary statistics
print("=== EXPERIMENTAL DATA SUMMARY ===")
print(f"Total experiments conducted: {len(df)}")
print(f"Algorithms tested: {df['algorithm'].unique()}")
print(f"Topologies tested: {df['topology'].unique()}")
print(f"Failure models tested: {df['failure_model'].unique()}")

print("\n=== BASELINE PERFORMANCE (NO FAILURES) ===")
baseline_data = df[df['failure_model'] == 'none']
for _, row in baseline_data.iterrows():
    print(f"{row['algorithm']} on {row['topology']}: {row['convergence_time_ms']} ms")

print("\n=== KEY OBSERVATIONS ===")
# Calculate interesting observations
gossip_baseline = df[(df['algorithm'] == 'gossip') & (df['failure_model'] == 'none') & (df['topology'] == 'full')]['convergence_time_ms'].values[0]
gossip_with_failures = df[(df['algorithm'] == 'gossip') & (df['failure_model'] != 'none')]
gossip_improvement = (gossip_baseline - gossip_with_failures['convergence_time_ms'].mean()) / gossip_baseline * 100

pushsum_baseline = df[(df['algorithm'] == 'push-sum') & (df['failure_model'] == 'none') & (df['topology'] == 'full')]['convergence_time_ms'].values[0]
pushsum_with_conn_failures = df[(df['algorithm'] == 'push-sum') & (df['failure_model'] == 'connection')]
pushsum_improvement = (pushsum_baseline - pushsum_with_conn_failures['convergence_time_ms'].mean()) / pushsum_baseline * 100

print(f"1. Gossip algorithm shows {gossip_improvement:.1f}% average improvement with failures")
print(f"2. Push-Sum algorithm shows {pushsum_improvement:.1f}% average improvement with connection failures")
print(f"3. Push-Sum is most sensitive to failures in sparse topologies (line, 3D)")
print(f"4. Connection failures have more complex impact on Push-Sum than node failures")
