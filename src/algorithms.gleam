import gleam/list
import types.{type Algorithm, Gossip, PushSum}

// Simulate the algorithm (simplified version)
pub fn simulate_algorithm(
  neighbors_map: List(#(Int, List(Int))),
  algorithm: Algorithm,
) -> Int {
  case algorithm {
    Gossip -> simulate_gossip(neighbors_map)
    PushSum -> simulate_pushsum(neighbors_map)
  }
}

// Simulate gossip algorithm
pub fn simulate_gossip(neighbors_map: List(#(Int, List(Int)))) -> Int {
  // Count total connections
  let total_connections =
    list.fold(neighbors_map, 0, fn(acc, entry) {
      case entry {
        #(_, neighbors) -> acc + list.length(neighbors)
      }
    })

  // Simple simulation: convergence time based on network size and connectivity
  let num_nodes = list.length(neighbors_map)
  let avg_connections = total_connections / num_nodes

  // Gossip converges faster with more connections
  let base_time = num_nodes * 10
  let connection_factor = case avg_connections {
    n if n >= 8 -> 1
    // Full network
    n if n >= 4 -> 2
    // Grid-like
    n if n >= 2 -> 3
    // Line-like
    _ -> 5
    // Sparse
  }

  let convergence_time = base_time / connection_factor
  convergence_time
}

// Simulate push-sum algorithm
pub fn simulate_pushsum(neighbors_map: List(#(Int, List(Int)))) -> Int {
  // Count total connections
  let total_connections =
    list.fold(neighbors_map, 0, fn(acc, entry) {
      case entry {
        #(_, neighbors) -> acc + list.length(neighbors)
      }
    })

  // Simple simulation: convergence time based on network size and connectivity
  let num_nodes = list.length(neighbors_map)
  let avg_connections = total_connections / num_nodes

  // Push-Sum converges slower than Gossip but is more stable
  let base_time = num_nodes * 20
  let connection_factor = case avg_connections {
    n if n >= 8 -> 2
    // Full network
    n if n >= 4 -> 3
    // Grid-like
    n if n >= 2 -> 4
    // Line-like
    _ -> 6
    // Sparse
  }

  let convergence_time = base_time / connection_factor
  convergence_time
}
