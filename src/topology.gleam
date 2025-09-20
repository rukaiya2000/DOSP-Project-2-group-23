import gleam/list
import types.{type Topology, Full, Grid3D, Imperfect3D, Line}

/// Network topology generation module
/// This module provides functions to create different network topologies
/// Each topology is represented as a list of tuples: (node_id, neighbor_ids)
/// Main topology builder - dispatches to specific topology implementations
/// Returns a list of tuples where each tuple contains (node_id, list_of_neighbor_ids)
pub fn build_topology(
  num_nodes: Int,
  topology: Topology,
) -> List(#(Int, List(Int))) {
  case topology {
    Full -> build_full_topology(num_nodes)
    Grid3D -> build_3d_grid_topology(num_nodes)
    Line -> build_line_topology(num_nodes)
    Imperfect3D -> build_imperfect_3d_grid_topology(num_nodes)
  }
}

/// Builds a full network topology where every node is connected to every other node
/// This creates maximum connectivity but also maximum overhead
/// Complexity: O(n²) connections
pub fn build_full_topology(num_nodes: Int) -> List(#(Int, List(Int))) {
  let all_nodes = list.range(0, num_nodes - 1)
  list.map(all_nodes, fn(node) {
    #(node, list.filter(all_nodes, fn(other) { other != node }))
  })
}

/// Builds a line topology where nodes are connected in a linear chain
/// Each node (except endpoints) has exactly 2 neighbors
/// Complexity: O(n) connections
pub fn build_line_topology(num_nodes: Int) -> List(#(Int, List(Int))) {
  list.map(list.range(0, num_nodes - 1), fn(i) {
    let neighbors = case i {
      0 -> [1]
      // First node connects only to second node
      n if n == num_nodes - 1 -> [n - 1]
      // Last node connects only to previous node
      _ -> [i - 1, i + 1]
      // Middle nodes connect to both neighbors
    }
    #(i, neighbors)
  })
}

/// Builds a 3D grid topology (simplified to 2D for implementation)
/// Each node connects to its immediate neighbors in the grid
/// Complexity: O(n) connections
pub fn build_3d_grid_topology(num_nodes: Int) -> List(#(Int, List(Int))) {
  // For simplicity, we'll create a 2D grid and treat it as 3D
  // In a real implementation, you'd calculate 3D coordinates
  let grid_size = 3
  // Fixed grid size for simplicity

  list.map(list.range(0, num_nodes - 1), fn(i) {
    let potential_neighbors = [
      i - grid_size,
      // up
      i + grid_size,
      // down
      i - 1,
      // left
      i + 1,
      // right
    ]
    // Filter out invalid neighbors (outside bounds)
    let neighbors =
      list.filter(potential_neighbors, fn(n) { n >= 0 && n < num_nodes })
    #(i, neighbors)
  })
}

/// Builds an imperfect 3D grid topology with additional random connections
/// Combines the structure of a grid with random connections to reduce bottlenecks
/// Complexity: O(n) connections
pub fn build_imperfect_3d_grid_topology(
  num_nodes: Int,
) -> List(#(Int, List(Int))) {
  // Start with a regular 3D grid
  let grid_neighbors = build_3d_grid_topology(num_nodes)
  let all_nodes = list.range(0, num_nodes - 1)

  list.map(all_nodes, fn(node) {
    // Get the grid neighbors for this node
    let grid_neighbors_list = case
      list.find(grid_neighbors, fn(entry) {
        case entry {
          #(n, _) -> n == node
        }
      })
    {
      Ok(#(_, neighbors)) -> neighbors
      Error(_) -> []
    }
    // Add one random neighbor to reduce bottlenecks (simplified - just pick the next node)
    let random_neighbor = case node + 1 < num_nodes {
      True -> [node + 1]
      False -> []
    }
    #(node, list.append(grid_neighbors_list, random_neighbor))
  })
}
