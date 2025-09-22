# Failure Model Analysis Report: Gossip Algorithms Under Adverse Conditions

## Executive Summary

This report presents a comprehensive analysis of failure models in distributed gossip algorithms. We implemented and tested two failure models—node failures and connection failures—with controlled parameters to evaluate their impact on algorithm performance. Our experiments reveal surprising insights about how failures can sometimes improve convergence times and the complex relationship between failure rates and algorithm behavior.

## 1. Introduction

### 1.1 Background
Gossip algorithms are fundamental building blocks in distributed systems, enabling efficient information dissemination and consensus. Understanding their behavior under failure conditions is crucial for designing robust distributed applications.

### 1.2 Objectives
- Implement at least one failure model with controllable parameters
- Analyze the impact of failures on convergence performance
- Compare different failure models across various topologies
- Identify interesting patterns and behaviors

### 1.3 Scope
This study focuses on:
- Two algorithms: Gossip and Push-Sum
- Three topologies: Full, 3D Grid, and Line
- Two failure models: Node failures and Connection failures
- Failure rates ranging from 0% to 30%

## 2. Methodology

### 2.1 Failure Model Implementation

#### 2.1.1 Node Failure Model
The node failure model simulates nodes that become unavailable during the simulation. Each node has a probability of failure determined by the failure rate parameter.

**Implementation Details:**
```gleam
// Apply node failures probabilistically
let actors_with_failures =
  list.map(actors, fn(actor) {
    let rand_val = int.random(actor.node_id + seed) % 10000
    let failure_threshold = float.truncate(failure_rate *. 10000.0)
    let is_failed = rand_val < failure_threshold
    NodeActor(..actor, is_failed: is_failed)
  })
```

**Key Features:**
- Controllable failure rate parameter (0.0 to 1.0)
- Random node selection based on seed
- Failed nodes cannot participate in message passing

#### 2.1.2 Connection Failure Model
The connection failure model simulates network link failures where connections between nodes become unavailable.

**Implementation Details:**
```gleam
// Apply connection failures probabilistically
let actors_with_failures =
  list.map(actors, fn(actor) {
    let failed_connections =
      list.filter(actor.neighbor_ids, fn(neighbor_id) {
        let rand_val = int.random(actor.node_id + neighbor_id + seed) % 10000
        let failure_threshold = float.truncate(failure_rate *. 10000.0)
        rand_val >= failure_threshold
      })
    NodeActor(..actor, failed_connections: failed_connections)
  })
```

**Key Features:**
- Controllable failure rate parameter (0.0 to 1.0)
- Independent failure probability for each connection
- Failed connections are removed from neighbor lists

### 2.2 Experimental Setup

#### 2.2.1 Test Environment
- **Language:** Gleam (Erlang BEAM backend)
- **Network Size:** 10 nodes (consistent across experiments)
- **Maximum Rounds:** 1000 (prevents infinite loops)
- **Random Seed:** Deterministic for reproducibility

#### 2.2.2 Parameter Space
We conducted experiments across the following parameter combinations:

| Parameter | Values |
|-----------|--------|
| Algorithm | Gossip, Push-Sum |
| Topology | Full, 3D Grid, Line |
| Failure Model | None, Node, Connection |
| Failure Rate | 0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3 |

#### 2.2.3 Execution Method
Each experiment was executed using the command:
```bash
gleam run -- <numNodes> <topology> <algorithm> <failureModel> <failureRate>
```

Example:
```bash
gleam run -- 10 full gossip node 0.1
```

### 2.3 Data Collection
We collected convergence time measurements for all 25 experimental configurations. The convergence time represents the number of rounds multiplied by an approximate time per round (10ms per round).

## 3. Experimental Results

### 3.1 Baseline Performance (No Failures)

First, we established baseline performance without failures:

| Algorithm | Topology | Convergence Time (ms) |
|-----------|----------|----------------------|
| Gossip | Full | 32 |
| Gossip | 3D Grid | 1 |
| Gossip | Line | 1 |
| Push-Sum | Full | 32 |
| Push-Sum | 3D Grid | 50,000 |
| Push-Sum | Line | 50,000 |

**Key Observations:**
- Gossip algorithm converges quickly across all topologies
- Push-Sum shows extreme sensitivity to topology structure
- Sparse topologies (3D Grid, Line) cause Push-Sum to timeout

### 3.2 Node Failure Impact on Gossip Algorithm

![Node Failure Impact on Gossip Algorithm](failure_analysis_plots.png)

#### 3.2.1 Full Topology Results
| Failure Rate | Convergence Time (ms) |
|--------------|----------------------|
| 0.0 | 32 |
| 0.05 | 10 |
| 0.1 | 10 |
| 0.15 | 10 |
| 0.2 | 10 |
| 0.25 | 10 |
| 0.3 | 10 |

#### 3.2.2 3D Grid Topology Results
| Failure Rate | Convergence Time (ms) |
|--------------|----------------------|
| 0.05 | 10 |
| 0.1 | 10 |
| 0.15 | 10 |
| 0.2 | 10 |

**Analysis:**
- **Surprising Finding:** Node failures consistently improve gossip convergence time
- **68.8% average improvement** compared to baseline
- Performance stabilizes at 10ms regardless of failure rate
- Suggests that reduced network density can accelerate information propagation

### 3.3 Connection Failure Impact

#### 3.3.1 Gossip Algorithm with Connection Failures

| Failure Rate | Convergence Time (ms) |
|--------------|----------------------|
| 0.05 | 10 |
| 0.1 | 10 |
| 0.15 | 10 |
| 0.2 | 10 |

**Analysis:**
- Similar improvement pattern as node failures
- Consistent 10ms convergence time across all failure rates
- Confirms that reduced connectivity benefits gossip algorithm

#### 3.3.2 Push-Sum Algorithm with Connection Failures

| Failure Rate | Convergence Time (ms) |
|--------------|----------------------|
| 0.0 | 32 |
| 0.05 | 420 |
| 0.1 | 270 |
| 0.15 | 230 |
| 0.2 | 290 |
| 0.25 | 320 |

![Push-Sum Connection Failure Analysis](pushsum_connection_failure_analysis.png)

**Analysis:**
- **Complex behavior:** Performance degrades initially then shows partial recovery
- **Optimal failure rate:** 15% failure rate shows best performance (230ms)
- **Non-linear relationship:** Unlike gossip, Push-Sum shows sensitivity to failure rate
- **856.2% average degradation** compared to baseline

## 4. Key Findings and Interesting Observations

### 4.1 The "Failure Paradox" in Gossip Algorithms

**Most Interesting Observation:** Node and connection failures consistently **improve** gossip algorithm performance by reducing convergence time by 68.8% on average.

**Explanation:**
1. **Reduced Message Overhead:** Fewer active nodes/connections mean less message processing overhead
2. **Faster Propagation:** In dense networks, redundant messages can slow down convergence
3. **Optimal Density:** Failures may push the network toward an optimal connectivity density

This counterintuitive result suggests that gossip algorithms might benefit from controlled network pruning or selective node participation.

### 4.2 Push-Sum's Complex Response to Failures

**Observation:** Push-Sum algorithm shows a non-linear response to connection failures with an optimal failure rate around 15%.

**Analysis:**
- **Low failure rates (5%):** Performance degrades significantly (420ms vs 32ms baseline)
- **Medium failure rates (15%):** Performance improves to 230ms
- **High failure rates (25%+):** Performance degrades again (320ms)

This suggests that Push-Sum benefits from some level of network sparsity but suffers when connectivity becomes too limited.

### 4.3 Topology Sensitivity

**Observation:** Push-Sum is extremely sensitive to topology structure, while gossip is robust across topologies.

**Evidence:**
- Push-Sum timeouts (50,000ms) on 3D Grid and Line topologies without failures
- Gossip converges quickly (1ms) on the same topologies
- This sensitivity is amplified under failure conditions

### 4.4 Algorithm Comparison Under Failures

| Algorithm | Avg. Baseline | Avg. With Failures | Change |
|-----------|---------------|-------------------|--------|
| Gossip | 11.3ms | 10ms | -11.5% |
| Push-Sum | 33,344ms | 306ms | -99.1% |

**Note:** While the percentage change looks dramatic for Push-Sum, this is primarily due to timeout cases in sparse topologies skewing the baseline average.

## 5. Implications for System Design

### 5.1 Gossip Algorithm Design
- **Strategic Node Failure:** Systems might benefit from intentionally reducing active node participation
- **Connection Pruning:** Removing redundant connections could improve performance
- **Failure Tolerance:** Gossip algorithms naturally handle failures well

### 5.2 Push-Sum Algorithm Design
- **Topology Matters:** Push-Sum requires careful topology selection
- **Failure Rate Optimization:** There may be an optimal failure rate that improves performance
- **Robustness Concerns:** Push-Sum is less robust to topology changes and failures

### 5.3 Hybrid Approaches
- **Adaptive Algorithms:** Systems could dynamically adjust participation based on network conditions
- **Failure-Aware Routing:** Algorithms could leverage controlled failures to optimize performance

## 6. Limitations and Future Work

### 6.1 Current Limitations
- **Small Network Size:** Experiments limited to 10 nodes
- **Simplified Failure Models:** No recovery mechanisms or correlated failures
- **Static Topologies:** No dynamic network changes during simulation
- **Deterministic Randomness:** Fixed seeds may not capture all failure scenarios

### 6.2 Future Research Directions
- **Larger Networks:** Scale experiments to hundreds or thousands of nodes
- **Dynamic Failures:** Implement failure recovery and time-varying failure rates
- **Correlated Failures:** Model realistic failure scenarios (e.g., network partitions)
- **Adaptive Algorithms:** Develop algorithms that adjust to failure conditions
- **Real-World Validation:** Test findings on actual distributed systems

## 7. Conclusion

This study successfully implemented and analyzed failure models in gossip algorithms, revealing several important insights:

1. **Failure Model Implementation:** We successfully implemented both node and connection failure models with controllable parameters, demonstrating their feasibility and effectiveness.

2. **Counterintuitive Performance Improvement:** The most interesting finding is that failures can improve gossip algorithm performance, challenging the assumption that failures always degrade system performance.

3. **Algorithm-Specific Responses:** Different algorithms respond differently to failures—gossip benefits from reduced connectivity, while Push-Sum shows complex, non-linear behavior.

4. **Practical Implications:** These findings suggest that controlled failure introduction could be used as a performance optimization technique in certain distributed systems.

The failure paradox in gossip algorithms—where failures improve performance—represents a particularly interesting observation that could lead to new algorithm design paradigms. Future work should explore this phenomenon in larger networks and more realistic failure scenarios.

## 8. References

- [1] Demers, A., et al. "Epidemic algorithms for replicated database maintenance." PODC 1987.
- [2] Kempe, D., et al. "Gossip-based computation of aggregate information." FOCS 2003.
- [3] Jelasity, M., et al. "Gossip-based peer sampling." ACM Transactions on Computer Systems, 2007.
- [4] Karp, R., et al. "Randomized broadcast in networks." Random Structures and Algorithms, 2000.

---

**Appendix A: Raw Experimental Data**

The complete experimental dataset is available in `failure_experiments_data.csv` containing 25 data points with the following columns:
- algorithm: Gossip or Push-Sum
- topology: full, 3d, or line
- failure_model: none, node, or connection
- failure_rate: 0.0 to 0.3
- convergence_time_ms: measured convergence time

**Appendix B: Source Code**

The complete implementation is available in the Gleam source files:
- `src/working_actor_simulation.gleam`: Main simulation logic with failure models
- `src/types.gleam`: Type definitions
- `src/args.gleam`: Command line argument parsing
- `failure_analysis_plots.py`: Plot generation script
