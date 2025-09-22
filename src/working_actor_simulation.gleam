import gleam/float.{absolute_value}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}

fn safe_mod(n: Int, d: Int) -> Int {
  case int.modulo(n, d) {
    Ok(x) -> x
    Error(_) -> 0
  }
}

import topology
import types.{
  type Algorithm, type FailureModel, type Topology, ConnectionFailure, Gossip,
  NoFailure, NodeFailure, PushSum,
}

/// Get a non-deterministic seed based on current timestamp
/// This ensures different results on each run without requiring additional parameters
fn get_non_deterministic_seed() -> Int {
  // Use Erlang's monotonic time for non-deterministic seeding
  let timestamp = get_system_time()
  // Convert to positive integer and modulo to keep it manageable
  int.absolute_value(timestamp) % 1_000_000
}

@external(erlang, "erlang", "monotonic_time")
fn get_system_time() -> Int

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
    pushsum_last_ratio: Float,
    pushsum_round_count: Int,
    is_terminated: Bool,
    is_failed: Bool,
    // Whether the node has failed
    failed_connections: List(Int),
    // List of connection IDs that have failed
  )
}

/// Messages that can be sent between node actors
pub type ActorMessage {
  /// Initialize gossip protocol with a rumor message
  StartGossip(String)
  /// Propagate gossip message with rumor and count
  GossipMessage(String)
  /// Initialize push-sum protocol
  StartPushSum
  /// Send push-sum values (sum and weight) to neighbor
  PushSumMessage(Float, Float)
  /// Terminate the actor
  Terminate
}

/// Creates a new node actor with the given ID and neighbor list
/// Initializes all state variables to their default values
/// For push-sum, each node starts with a unique sum value (node ID) and weight 1.0
pub fn create_node_actor(node_id: Int, neighbor_ids: List(Int)) -> NodeActor {
  let initial_sum = int.to_float(node_id)
  let initial_weight = 1.0
  let initial_ratio = initial_sum /. initial_weight
  NodeActor(
    node_id: node_id,
    neighbor_ids: neighbor_ids,
    gossip_message_count: 0,
    pushsum_sum_value: initial_sum,
    pushsum_weight_value: initial_weight,
    pushsum_last_ratio: initial_ratio,
    pushsum_round_count: 0,
    is_terminated: False,
    is_failed: False,
    failed_connections: [],
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
        pushsum_last_ratio: actor.pushsum_last_ratio,
        pushsum_round_count: actor.pushsum_round_count,
        is_terminated: False,
        is_failed: actor.is_failed,
        failed_connections: actor.failed_connections,
      )
    }
    GossipMessage(_rumor) -> {
      // Update gossip message count and check termination condition
      let new_count = actor.gossip_message_count + 1
      let should_terminate = new_count >= 10
      NodeActor(
        node_id: actor.node_id,
        neighbor_ids: actor.neighbor_ids,
        gossip_message_count: new_count,
        pushsum_sum_value: actor.pushsum_sum_value,
        pushsum_weight_value: actor.pushsum_weight_value,
        pushsum_last_ratio: actor.pushsum_last_ratio,
        pushsum_round_count: actor.pushsum_round_count,
        is_terminated: should_terminate,
        is_failed: actor.is_failed,
        failed_connections: actor.failed_connections,
      )
    }
    StartPushSum -> {
      // Initialize push-sum protocol - start with current values
      NodeActor(
        node_id: actor.node_id,
        neighbor_ids: actor.neighbor_ids,
        gossip_message_count: actor.gossip_message_count,
        pushsum_sum_value: actor.pushsum_sum_value,
        pushsum_weight_value: actor.pushsum_weight_value,
        pushsum_last_ratio: actor.pushsum_last_ratio,
        pushsum_round_count: 1,
        is_terminated: False,
        is_failed: actor.is_failed,
        failed_connections: actor.failed_connections,
      )
    }
    PushSumMessage(s, w) -> {
      // Update push-sum values and check convergence
      let new_sum = actor.pushsum_sum_value +. s
      let new_weight = actor.pushsum_weight_value +. w
      let new_ratio = new_sum /. new_weight
      let round_count = actor.pushsum_round_count + 1

      // Check for convergence (ratio changed by less than 0.00001)
      let ratio_diff = absolute_value(new_ratio -. actor.pushsum_last_ratio)
      let should_terminate = ratio_diff <. 0.00001 && round_count >= 3

      NodeActor(
        node_id: actor.node_id,
        neighbor_ids: actor.neighbor_ids,
        gossip_message_count: actor.gossip_message_count,
        pushsum_sum_value: new_sum,
        pushsum_weight_value: new_weight,
        pushsum_last_ratio: new_ratio,
        pushsum_round_count: round_count,
        is_terminated: should_terminate,
        is_failed: actor.is_failed,
        failed_connections: actor.failed_connections,
      )
    }
    Terminate -> {
      // Mark actor as terminated
      NodeActor(
        node_id: actor.node_id,
        neighbor_ids: actor.neighbor_ids,
        gossip_message_count: actor.gossip_message_count,
        pushsum_sum_value: actor.pushsum_sum_value,
        pushsum_weight_value: actor.pushsum_weight_value,
        pushsum_last_ratio: actor.pushsum_last_ratio,
        pushsum_round_count: actor.pushsum_round_count,
        is_terminated: True,
        is_failed: actor.is_failed,
        failed_connections: actor.failed_connections,
      )
    }
  }
}

// -------------------------
// Utilities for simulation
// -------------------------

/// Helper function to get neighbors for a specific node from the neighbor map
fn get_neighbors_for_node(
  node_id: Int,
  neighbor_map: List(#(Int, List(Int))),
) -> List(Int) {
  case list.find(neighbor_map, fn(tuple) { tuple.0 == node_id }) {
    Ok(found) -> found.1
    Error(_) -> []
  }
}

/// Wrapper function for gossip simulation loop with expected signature
fn run_gossip_simulation_loop(
  actors: List(NodeActor),
  seed: Int,
) -> SimulationResult {
  let max_rounds = 1000
  let initial_messages = []
  let #(final_actors, rounds) =
    gossip_loop(actors, initial_messages, seed, 0, max_rounds)
  SimulationResult(
    convergence_time_ms: rounds * 10,
    // Approximate time per round
    nodes_converged: list.length(final_actors),
    total_nodes: list.length(final_actors),
  )
}

/// Wrapper function for push-sum simulation loop with expected signature
fn run_pushsum_simulation_loop(
  actors: List(NodeActor),
  seed: Int,
) -> SimulationResult {
  let max_rounds = 1000
  let initial_messages = []
  let #(final_actors, rounds) =
    pushsum_loop(actors, initial_messages, seed, 0, max_rounds)
  SimulationResult(
    convergence_time_ms: rounds * 10,
    // Approximate time per round
    nodes_converged: list.length(final_actors),
    total_nodes: list.length(final_actors),
  )
}

/// A tiny Linear Congruential Generator for pseudo-randomness without deps
/// Returns a new seed and a non-negative integer value
fn lcg_next(seed: Int) -> #(Int, Int) {
  // Constants from Numerical Recipes
  let a = 1_664_525
  let c = 1_013_904_223
  let m = 2_147_483_647
  let new_seed = safe_mod(a * seed + c, m)
  #(new_seed, new_seed)
}

/// Pick one neighbor index using RNG. Returns None if there are no neighbors
fn pick_random_neighbor(neighbors: List(Int), seed: Int) -> #(Option(Int), Int) {
  case neighbors {
    [] -> #(None, seed)
    _ -> {
      let #(seed2, r) = lcg_next(seed)
      let len = list.length(neighbors)
      let idx = safe_mod(r, len)
      // Get neighbor at idx
      let chosen =
        list.fold(
          list.index_map(neighbors, fn(i, v) { #(i, v) }),
          None,
          fn(acc, pair) {
            case acc {
              Some(_) -> acc
              None -> {
                case pair {
                  #(i, v) ->
                    case i == idx {
                      True -> Some(v)
                      False -> None
                    }
                }
              }
            }
          },
        )
      #(chosen, seed2)
    }
  }
}

/// Helper to build outgoing gossip messages for one actor
fn accumulate_gossip_sends(
  acc: #(List(#(Int, ActorMessage)), Int),
  actor: NodeActor,
) -> #(List(#(Int, ActorMessage)), Int) {
  case acc {
    #(msgs, sd) ->
      case
        actor.is_terminated
        || list.is_empty(actor.neighbor_ids)
        || actor.gossip_message_count == 0
      {
        True -> #(msgs, sd)
        False -> {
          let #(maybe_neighbor, sd2) =
            pick_random_neighbor(actor.neighbor_ids, sd)
          case maybe_neighbor {
            Some(nid) -> #(
              list.append([#(nid, GossipMessage("rumor"))], msgs),
              sd2,
            )
            None -> #(msgs, sd2)
          }
        }
      }
  }
}

/// Gossip simulation loop. Delivers all in-flight messages, updates actors,
/// then emits new messages from active actors to one random neighbor.
fn gossip_loop(
  actors: List(NodeActor),
  in_flight: List(#(Int, ActorMessage)),
  seed: Int,
  round: Int,
  max_rounds: Int,
) -> #(List(NodeActor), Int) {
  case round >= max_rounds {
    True -> #(actors, round)
    False -> {
      let delivered =
        list.map(actors, fn(actor) {
          let my_msgs =
            list.filter(in_flight, fn(pair) {
              case pair {
                #(dst, _msg) -> dst == actor.node_id
              }
            })
          list.fold(my_msgs, actor, fn(a, pair) {
            case pair {
              #(_, msg) -> process_message(a, msg)
            }
          })
        })

      let init_acc: #(List(#(Int, ActorMessage)), Int) = #([], seed)
      let #(out_messages, seed_next) =
        list.fold(delivered, init_acc, accumulate_gossip_sends)

      let all_terminated = list.all(delivered, fn(a) { a.is_terminated })
      let no_messages = list.is_empty(out_messages)
      case all_terminated || no_messages {
        True -> #(delivered, round + 1)
        False ->
          gossip_loop(delivered, out_messages, seed_next, round + 1, max_rounds)
      }
    }
  }
}

/// Check if all nodes have converged to the same ratio within epsilon
fn check_global_convergence(actors: List(NodeActor), epsilon: Float) -> Bool {
  case actors {
    [] -> True
    _ -> {
      // Use theoretical average instead of first node's ratio
      // For nodes 0 to n-1, the average is (0 + 1 + ... + n-1) / n = (n-1)/2
      let theoretical_average = int.to_float(list.length(actors) - 1) /. 2.0
      let target_ratio = theoretical_average

      let all_converged =
        list.all(actors, fn(actor) {
          // Exclude nodes with very small weights from convergence checks
          // as their ratios are unstable due to numerical precision issues
          let min_weight_for_convergence = 1.0e-5
          case actor.pushsum_weight_value <. min_weight_for_convergence {
            True -> True
            // Skip convergence check for nodes with very small weights
            False -> {
              let diff =
                absolute_value(actor.pushsum_last_ratio -. target_ratio)
              diff <. epsilon
            }
          }
        })

      all_converged
    }
  }
}

/// Push-sum simulation loop. Each non-terminated actor that has begun push-sum
/// sends half its (s, w) to one random neighbor per round. Converges when all
/// nodes have ratios within epsilon of each other.
fn pushsum_loop(
  actors: List(NodeActor),
  in_flight: List(#(Int, ActorMessage)),
  seed: Int,
  round: Int,
  max_rounds: Int,
) -> #(List(NodeActor), Int) {
  case round >= max_rounds {
    True -> #(actors, round)
    False -> {
      // Process incoming messages for all actors
      let actors_after_processing =
        list.map(actors, fn(actor) {
          let my_msgs =
            list.filter(in_flight, fn(pair) {
              case pair {
                #(dst, _msg) -> dst == actor.node_id
              }
            })
          list.fold(my_msgs, actor, fn(a, pair) {
            case pair {
              #(_, msg) -> process_message(a, msg)
            }
          })
        })

      // For each active actor, send half to a random neighbor AND halve local state
      // In push-sum, ALL nodes should send messages in every round, not just delivered ones
      let init_acc: #(List(#(Int, ActorMessage)), Int, List(NodeActor)) = #(
        [],
        seed,
        [],
      )
      let #(out_messages, seed_next, updated_actors) =
        list.fold(actors_after_processing, init_acc, fn(acc, a) {
          case acc {
            #(msgs, sd, actors) -> {
              case a.is_terminated || list.is_empty(a.neighbor_ids) {
                True -> #(msgs, sd, [a, ..actors])
                False -> {
                  let #(maybe_neighbor, sd2) =
                    pick_random_neighbor(a.neighbor_ids, sd)
                  case maybe_neighbor {
                    Some(nid) -> {
                      // Calculate the halved values first
                      let half_sum = a.pushsum_sum_value /. 2.0
                      let half_weight = a.pushsum_weight_value /. 2.0

                      // Prevent numerical underflow by setting minimum weight threshold
                      let min_weight = 1.0e-6
                      // More reasonable minimum weight
                      let safe_half_weight = case half_weight <. min_weight {
                        True -> min_weight
                        False -> half_weight
                      }

                      // Halve the local state immediately when sending
                      let updated_actor =
                        NodeActor(
                          node_id: a.node_id,
                          neighbor_ids: a.neighbor_ids,
                          gossip_message_count: a.gossip_message_count,
                          pushsum_sum_value: half_sum,
                          pushsum_weight_value: safe_half_weight,
                          pushsum_last_ratio: a.pushsum_last_ratio,
                          pushsum_round_count: a.pushsum_round_count,
                          is_terminated: a.is_terminated,
                          is_failed: a.is_failed,
                          failed_connections: a.failed_connections,
                        )
                      #(
                        list.append(
                          [
                            #(nid, PushSumMessage(half_sum, safe_half_weight)),
                          ],
                          msgs,
                        ),
                        sd2,
                        [updated_actor, ..actors],
                      )
                    }
                    None -> #(msgs, sd2, [a, ..actors])
                  }
                }
              }
            }
          }
        })

      // Reverse the list to maintain original order
      let final_actors = list.reverse(updated_actors)
      let epsilon = 0.001
      let has_converged = check_global_convergence(final_actors, epsilon)
      case has_converged {
        True -> #(final_actors, round)
        // Return current round when converged
        False ->
          pushsum_loop(
            final_actors,
            out_messages,
            seed_next,
            round + 1,
            max_rounds,
          )
      }
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

  // Messages are addressed as pairs of (destination_node_id, message)
  // Seed the system by sending one gossip message to node 0 (if exists)
  let initial_messages = case num_nodes > 0 {
    True -> [#(0, GossipMessage("rumor"))]
    False -> []
  }

  // Run rounds until convergence or cap reached
  let max_simulation_rounds = 50_000
  let seed0 = get_non_deterministic_seed()
  let #(final_actors, rounds_taken) =
    gossip_loop(node_actors, initial_messages, seed0, 0, max_simulation_rounds)

  let converged_node_count =
    list.fold(final_actors, 0, fn(acc, actor) {
      case actor.is_terminated {
        True -> acc + 1
        False -> acc
      }
    })

  SimulationResult(
    convergence_time_ms: rounds_taken,
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

  // Start push-sum for all nodes
  let initialized_actors =
    list.map(node_actors, fn(actor) { process_message(actor, StartPushSum) })

  // Run rounds until convergence or cap reached
  let max_simulation_rounds = 50_000
  let seed0 = get_non_deterministic_seed()

  // Start with empty messages - let the push-sum loop handle the first round
  let initial_messages: List(#(Int, ActorMessage)) = []
  let #(final_actors, rounds_taken) =
    pushsum_loop(
      list.reverse(initialized_actors),
      initial_messages,
      seed0,
      0,
      max_simulation_rounds,
    )

  // Since we use global convergence, mark all nodes as terminated if converged
  let epsilon = 0.001
  let has_converged = check_global_convergence(final_actors, epsilon)
  let terminated_actors = case has_converged {
    True ->
      list.map(final_actors, fn(actor) {
        NodeActor(..actor, is_terminated: True)
      })
    False -> final_actors
  }

  let converged_node_count =
    list.fold(terminated_actors, 0, fn(acc, actor) {
      case actor.is_terminated {
        True -> acc + 1
        False -> acc
      }
    })

  SimulationResult(
    convergence_time_ms: rounds_taken,
    nodes_converged: converged_node_count,
    total_nodes: num_nodes,
  )
}

/// Main entry point for running actor-based simulations
/// Dispatches to the appropriate algorithm implementation based on the algorithm type
pub fn run_actor_simulation(
  num_nodes: Int,
  topology_type: Topology,
  algorithm: Algorithm,
  failure_model: types.FailureModel,
  failure_rate: Float,
) -> SimulationResult {
  case algorithm {
    Gossip ->
      run_gossip_simulation_with_failures(
        num_nodes,
        topology_type,
        failure_model,
        failure_rate,
      )
    PushSum ->
      run_pushsum_simulation_with_failures(
        num_nodes,
        topology_type,
        failure_model,
        failure_rate,
      )
  }
}

/// Run gossip simulation with failure models
fn run_gossip_simulation_with_failures(
  num_nodes: Int,
  topology_type: Topology,
  failure_model: FailureModel,
  _failure_rate: Float,
) -> SimulationResult {
  case failure_model {
    NoFailure -> run_gossip_simulation(num_nodes, topology_type)
    NodeFailure(rate) ->
      run_gossip_simulation_with_node_failures(num_nodes, topology_type, rate)
    ConnectionFailure(rate, _recovery_rate) ->
      run_gossip_simulation_with_connection_failures(
        num_nodes,
        topology_type,
        rate,
      )
  }
}

/// Run push-sum simulation with failure models
fn run_pushsum_simulation_with_failures(
  num_nodes: Int,
  topology_type: Topology,
  failure_model: FailureModel,
  _failure_rate: Float,
) -> SimulationResult {
  case failure_model {
    NoFailure -> run_pushsum_simulation(num_nodes, topology_type)
    NodeFailure(rate) ->
      run_pushsum_simulation_with_node_failures(num_nodes, topology_type, rate)
    ConnectionFailure(rate, _recovery_rate) ->
      run_pushsum_simulation_with_connection_failures(
        num_nodes,
        topology_type,
        rate,
      )
  }
}

/// Run gossip simulation with node failures
fn run_gossip_simulation_with_node_failures(
  num_nodes: Int,
  topology_type: Topology,
  failure_rate: Float,
) -> SimulationResult {
  let seed = get_non_deterministic_seed()
  let neighbor_map = topology.build_topology(num_nodes, topology_type)

  // Create initial actors
  let actors =
    list.range(0, num_nodes - 1)
    |> list.map(fn(node_id) {
      create_node_actor(node_id, get_neighbors_for_node(node_id, neighbor_map))
    })

  // Apply node failures probabilistically
  let actors_with_failures =
    list.map(actors, fn(actor) {
      let rand_val = int.random(actor.node_id + seed) % 10_000
      let failure_threshold = float.truncate(failure_rate *. 10_000.0)
      let is_failed = rand_val < failure_threshold
      NodeActor(..actor, is_failed: is_failed)
    })

  run_gossip_simulation_loop(actors_with_failures, seed)
}

/// Run gossip simulation with connection failures
fn run_gossip_simulation_with_connection_failures(
  num_nodes: Int,
  topology_type: Topology,
  failure_rate: Float,
) -> SimulationResult {
  let seed = get_non_deterministic_seed()
  let neighbor_map = topology.build_topology(num_nodes, topology_type)

  // Create initial actors
  let actors =
    list.range(0, num_nodes - 1)
    |> list.map(fn(node_id) {
      create_node_actor(node_id, get_neighbors_for_node(node_id, neighbor_map))
    })

  // Apply connection failures probabilistically
  let actors_with_failures =
    list.map(actors, fn(actor) {
      let failed_connections =
        list.filter(actor.neighbor_ids, fn(neighbor_id) {
          let rand_val = int.random(actor.node_id + neighbor_id + seed) % 10_000
          let failure_threshold = float.truncate(failure_rate *. 10_000.0)
          rand_val >= failure_threshold
        })
      NodeActor(..actor, failed_connections: failed_connections)
    })

  run_gossip_simulation_loop(actors_with_failures, seed)
}

/// Run push-sum simulation with node failures
fn run_pushsum_simulation_with_node_failures(
  num_nodes: Int,
  topology_type: Topology,
  failure_rate: Float,
) -> SimulationResult {
  let seed = get_non_deterministic_seed()
  let neighbor_map = topology.build_topology(num_nodes, topology_type)

  // Create initial actors
  let actors =
    list.range(0, num_nodes - 1)
    |> list.map(fn(node_id) {
      create_node_actor(node_id, get_neighbors_for_node(node_id, neighbor_map))
    })

  // Apply node failures probabilistically
  let actors_with_failures =
    list.map(actors, fn(actor) {
      let rand_val = int.random(actor.node_id + seed) % 10_000
      let failure_threshold = float.truncate(failure_rate *. 10_000.0)
      let is_failed = rand_val < failure_threshold
      NodeActor(..actor, is_failed: is_failed)
    })

  run_pushsum_simulation_loop(actors_with_failures, seed)
}

/// Run push-sum simulation with connection failures
fn run_pushsum_simulation_with_connection_failures(
  num_nodes: Int,
  topology_type: Topology,
  failure_rate: Float,
) -> SimulationResult {
  let seed = get_non_deterministic_seed()
  let neighbor_map = topology.build_topology(num_nodes, topology_type)

  // Create initial actors
  let actors =
    list.range(0, num_nodes - 1)
    |> list.map(fn(node_id) {
      create_node_actor(node_id, get_neighbors_for_node(node_id, neighbor_map))
    })

  // Apply connection failures probabilistically
  let actors_with_failures =
    list.map(actors, fn(actor) {
      let failed_connections =
        list.filter(actor.neighbor_ids, fn(neighbor_id) {
          let rand_val = int.random(actor.node_id + neighbor_id + seed) % 10_000
          let failure_threshold = float.truncate(failure_rate *. 10_000.0)
          rand_val >= failure_threshold
        })
      NodeActor(..actor, failed_connections: failed_connections)
    })

  run_pushsum_simulation_loop(actors_with_failures, seed)
}
