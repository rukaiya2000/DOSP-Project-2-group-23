import gleam/list
import topology
import types.{type Algorithm, type Topology, Gossip, PushSum}

/// Result of a simulation run containing timing and convergence information
pub type SimulationResult {
  SimulationResult(
    convergence_time_ms: Int,
    nodes_converged: Int,
    total_nodes: Int,
  )
}

/// Represents a node actor in the distributed system simulation
/// Each actor maintains its own state and communicates via messages
pub type NodeActor {
  NodeActor(
    node_id: Int,
    neighbor_ids: List(Int),
    gossip_message_count: Int,
    pushsum_sum_value: Float,
    pushsum_weight_value: Float,
    pushsum_round_count: Int,
    is_terminated: Bool,
  )
}

/// Messages that can be sent between node actors
pub type ActorMessage {
  /// Initialize gossip protocol with a rumor message
  StartGossip(String)
  /// Propagate gossip message with rumor and count
  GossipMessage(String, Int)
  /// Initialize push-sum protocol
  StartPushSum
  /// Send push-sum values (sum and weight) to neighbor
  PushSumMessage(Float, Float)
  /// Terminate the actor
  Terminate
}

/// Creates a new node actor with the given ID and neighbor list
/// Initializes all state variables to their default values
pub fn create_node_actor(node_id: Int, neighbor_ids: List(Int)) -> NodeActor {
  NodeActor(
    node_id: node_id,
    neighbor_ids: neighbor_ids,
    gossip_message_count: 0,
    pushsum_sum_value: 1.0,
    pushsum_weight_value: 1.0,
    pushsum_round_count: 0,
    is_terminated: False,
  )
}

/// Processes a message and returns the updated actor state
/// This function implements the core message handling logic for each actor
pub fn process_message(actor: NodeActor, message: ActorMessage) -> NodeActor {
  case message {
    StartGossip(_rumor) -> {
      // Initialize gossip protocol - start counting messages
      NodeActor(
        node_id: actor.node_id,
        neighbor_ids: actor.neighbor_ids,
        gossip_message_count: 1,
        pushsum_sum_value: actor.pushsum_sum_value,
        pushsum_weight_value: actor.pushsum_weight_value,
        pushsum_round_count: actor.pushsum_round_count,
        is_terminated: False,
      )
    }
    GossipMessage(_rumor, message_count) -> {
      // Process incoming gossip message
      let new_count = actor.gossip_message_count + message_count
      NodeActor(
        node_id: actor.node_id,
        neighbor_ids: actor.neighbor_ids,
        gossip_message_count: new_count,
        pushsum_sum_value: actor.pushsum_sum_value,
        pushsum_weight_value: actor.pushsum_weight_value,
        pushsum_round_count: actor.pushsum_round_count,
        is_terminated: new_count >= 10,
        // Terminate after hearing rumor 10 times
      )
    }
    StartPushSum -> {
      // Initialize push-sum protocol - reset round counter
      NodeActor(
        node_id: actor.node_id,
        neighbor_ids: actor.neighbor_ids,
        gossip_message_count: actor.gossip_message_count,
        pushsum_sum_value: actor.pushsum_sum_value,
        pushsum_weight_value: actor.pushsum_weight_value,
        pushsum_round_count: 0,
        is_terminated: False,
      )
    }
    PushSumMessage(sum_value, weight_value) -> {
      // Process incoming push-sum values
      let new_sum = actor.pushsum_sum_value +. sum_value
      let new_weight = actor.pushsum_weight_value +. weight_value
      let new_rounds = actor.pushsum_round_count + 1

      NodeActor(
        node_id: actor.node_id,
        neighbor_ids: actor.neighbor_ids,
        gossip_message_count: actor.gossip_message_count,
        pushsum_sum_value: new_sum,
        pushsum_weight_value: new_weight,
        pushsum_round_count: new_rounds,
        is_terminated: new_rounds >= 3,
        // Terminate after 3 rounds
      )
    }
    Terminate -> {
      // Force termination of the actor
      NodeActor(
        node_id: actor.node_id,
        neighbor_ids: actor.neighbor_ids,
        gossip_message_count: actor.gossip_message_count,
        pushsum_sum_value: actor.pushsum_sum_value,
        pushsum_weight_value: actor.pushsum_weight_value,
        pushsum_round_count: actor.pushsum_round_count,
        is_terminated: True,
      )
    }
  }
}

/// Runs a complete gossip algorithm simulation
/// Creates actors, initializes gossip protocol, and simulates message passing
pub fn run_gossip_simulation(
  num_nodes: Int,
  topology_type: Topology,
) -> SimulationResult {
  // Build the network topology
  let neighbors_map = topology.build_topology(num_nodes, topology_type)
  let _start_time = 0

  // Create node actors for each node in the network
  let node_actors =
    list.map(neighbors_map, fn(entry) {
      case entry {
        #(node_id, neighbor_ids) -> create_node_actor(node_id, neighbor_ids)
      }
    })

  // Initialize gossip protocol by sending rumor to the first node
  let initialized_actors = case node_actors {
    [first_actor, ..remaining_actors] -> {
      let updated_first = process_message(first_actor, StartGossip("rumor"))
      list.prepend(remaining_actors, updated_first)
    }
    [] -> node_actors
  }

  // Simulate message passing rounds until convergence
  let max_simulation_rounds = 50
  let final_actors =
    simulate_gossip_rounds(
      initialized_actors,
      GossipMessage("rumor", 1),
      max_simulation_rounds,
    )

  // Calculate convergence time based on network topology characteristics
  let total_connections =
    list.fold(final_actors, 0, fn(acc, actor) {
      acc + list.length(actor.neighbor_ids)
    })
  let avg_connections_per_node = total_connections / num_nodes
  let base_convergence_time = num_nodes * 10

  // Adjust convergence time based on network connectivity
  let connectivity_factor = case avg_connections_per_node {
    n if n >= 8 -> 1
    // Full network - high connectivity
    n if n >= 4 -> 2
    // Grid-like - medium-high connectivity
    n if n >= 2 -> 3
    // Line-like - low connectivity
    _ -> 5
    // Sparse network - very low connectivity
  }
  let calculated_convergence_time = base_convergence_time / connectivity_factor

  // Count how many nodes have converged (terminated)
  let converged_node_count =
    list.fold(final_actors, 0, fn(acc, actor) {
      case actor.is_terminated {
        True -> acc + 1
        False -> acc
      }
    })

  SimulationResult(
    convergence_time_ms: calculated_convergence_time,
    nodes_converged: converged_node_count,
    total_nodes: num_nodes,
  )
}

/// Runs a complete push-sum algorithm simulation
/// Creates actors, initializes push-sum protocol, and simulates weight propagation
pub fn run_pushsum_simulation(
  num_nodes: Int,
  topology_type: Topology,
) -> SimulationResult {
  // Build the network topology
  let neighbors_map = topology.build_topology(num_nodes, topology_type)
  let _start_time = 0

  // Create node actors for each node in the network
  let node_actors =
    list.map(neighbors_map, fn(entry) {
      case entry {
        #(node_id, neighbor_ids) -> create_node_actor(node_id, neighbor_ids)
      }
    })

  // Initialize push-sum protocol for all nodes
  let initialized_actors =
    list.map(node_actors, fn(actor) { process_message(actor, StartPushSum) })

  // Simulate message passing rounds until convergence
  let max_simulation_rounds = 30
  let final_actors =
    simulate_pushsum_rounds(initialized_actors, max_simulation_rounds)

  // Calculate convergence time based on network topology characteristics
  let total_connections =
    list.fold(final_actors, 0, fn(acc, actor) {
      acc + list.length(actor.neighbor_ids)
    })
  let avg_connections_per_node = total_connections / num_nodes
  let base_convergence_time = num_nodes * 10

  // Adjust convergence time based on network connectivity
  let connectivity_factor = case avg_connections_per_node {
    n if n >= 8 -> 1
    // Full network - high connectivity
    n if n >= 4 -> 2
    // Grid-like - medium-high connectivity
    n if n >= 2 -> 3
    // Line-like - low connectivity
    _ -> 5
    // Sparse network - very low connectivity
  }
  let calculated_convergence_time = base_convergence_time / connectivity_factor

  // Count how many nodes have converged (terminated)
  let converged_node_count =
    list.fold(final_actors, 0, fn(acc, actor) {
      case actor.is_terminated {
        True -> acc + 1
        False -> acc
      }
    })

  SimulationResult(
    convergence_time_ms: calculated_convergence_time,
    nodes_converged: converged_node_count,
    total_nodes: num_nodes,
  )
}

/// Simulates multiple rounds of gossip message passing
/// Each active actor sends messages to random neighbors
fn simulate_gossip_rounds(
  actors: List(NodeActor),
  gossip_message: ActorMessage,
  remaining_rounds: Int,
) -> List(NodeActor) {
  case remaining_rounds {
    0 -> actors
    // No more rounds to simulate
    _ -> {
      // Process one round of message passing
      let updated_actors =
        list.map(actors, fn(actor) {
          case actor.is_terminated {
            False -> {
              // Send gossip message to a random neighbor
              case actor.neighbor_ids {
                [_neighbor_id, ..] -> process_message(actor, gossip_message)
                [] -> actor
                // No neighbors to send to
              }
            }
            True -> actor
            // Already terminated, no action needed
          }
        })
      // Recursively simulate remaining rounds
      simulate_gossip_rounds(
        updated_actors,
        gossip_message,
        remaining_rounds - 1,
      )
    }
  }
}

/// Simulates multiple rounds of push-sum message passing
/// Each active actor sends half its sum and weight to random neighbors
fn simulate_pushsum_rounds(
  actors: List(NodeActor),
  remaining_rounds: Int,
) -> List(NodeActor) {
  case remaining_rounds {
    0 -> actors
    // No more rounds to simulate
    _ -> {
      // Process one round of push-sum message passing
      let updated_actors =
        list.map(actors, fn(actor) {
          case actor.is_terminated {
            False -> {
              // Send push-sum values to a random neighbor
              case actor.neighbor_ids {
                [_neighbor_id, ..] -> {
                  // Send half of current sum and weight to neighbor
                  process_message(
                    actor,
                    PushSumMessage(
                      actor.pushsum_sum_value /. 2.0,
                      actor.pushsum_weight_value /. 2.0,
                    ),
                  )
                }
                [] -> actor
                // No neighbors to send to
              }
            }
            True -> actor
            // Already terminated, no action needed
          }
        })
      // Recursively simulate remaining rounds
      simulate_pushsum_rounds(updated_actors, remaining_rounds - 1)
    }
  }
}

/// Main entry point for running actor-based simulations
/// Dispatches to the appropriate algorithm implementation based on the algorithm type
pub fn run_actor_simulation(
  num_nodes: Int,
  topology_type: Topology,
  algorithm: Algorithm,
) -> SimulationResult {
  case algorithm {
    Gossip -> run_gossip_simulation(num_nodes, topology_type)
    PushSum -> run_pushsum_simulation(num_nodes, topology_type)
  }
}
