import algorithms.{simulate_algorithm}
import gleam/int
import gleam/io
import gleam/list
import topology.{build_topology}
import types.{
  type Arguments, Full, Gossip, Grid3D, Imperfect3D, Line, PushSum,
  algorithm_to_string, topology_to_string,
}

// Run comprehensive tests with different network sizes
pub fn run_comprehensive_tests() {
  io.println("Comprehensive Gossip Algorithm Tests")
  io.println("====================================")

  let network_sizes = [5, 10, 20, 50]
  let topologies = [Full, Line, Grid3D, Imperfect3D]
  let algorithms = [Gossip, PushSum]

  list.each(network_sizes, fn(num_nodes) {
    io.println("")
    io.println("Testing with " <> int.to_string(num_nodes) <> " nodes:")
    io.println("------------------------------------------------")

    list.each(topologies, fn(topology) {
      list.each(algorithms, fn(algorithm) {
        let neighbors_map = build_topology(num_nodes, topology)
        let convergence_time = simulate_algorithm(neighbors_map, algorithm)

        io.println(
          "  "
          <> topology_to_string(topology)
          <> " + "
          <> algorithm_to_string(algorithm)
          <> ": "
          <> int.to_string(convergence_time)
          <> " ms",
        )
      })
    })
  })
}

// Run a single simulation
pub fn run_single_simulation(args: Arguments) {
  io.println("Running simulation with:")
  io.println("  Nodes: " <> int.to_string(args.num_nodes))
  io.println("  Topology: " <> topology_to_string(args.topology))
  io.println("  Algorithm: " <> algorithm_to_string(args.algorithm))
  io.println("")

  let neighbors_map = build_topology(args.num_nodes, args.topology)
  let convergence_time = simulate_algorithm(neighbors_map, args.algorithm)

  io.println("Convergence time: " <> int.to_string(convergence_time) <> " ms")
}
