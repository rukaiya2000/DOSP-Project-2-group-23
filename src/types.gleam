/// Centralized type definitions for the gossip simulation
/// This module contains all the core types used throughout the application
/// Network topology types supported by the simulation
pub type Topology {
  Full
  // Every node connected to every other node
  Grid3D
  // 3D grid topology (simplified to 2D)
  Line
  // Linear chain topology
  Imperfect3D
  // Grid topology with additional random connections
}

/// Distributed algorithms implemented in the simulation
pub type Algorithm {
  Gossip
  // Information propagation through rumor spreading
  PushSum
  // Distributed sum computation with weight propagation
}

/// Failure models for simulating node and connection failures
pub type FailureModel {
  NodeFailure(failure_rate: Float)
  // Nodes can fail with given probability
  ConnectionFailure(failure_rate: Float, recovery_rate: Float)
  // Connections can fail temporarily and recover
  NoFailure
  // No failures (baseline)
}

/// Message types for actor communication (legacy - used in older implementations)
pub type Message {
  GossipMessage(rumor: String)
  // Propagate gossip message with count
  PushSumMessage(s: Int, w: Int)
  // Send push-sum values (sum and weight)
  StartGossip(rumor: String)
  // Initialize gossip protocol
  StartPushSum
  // Initialize push-sum protocol
  Terminate
  // Terminate actor
}

/// Command line arguments parsed from user input
pub type Arguments {
  Arguments(
    num_nodes: Int,
    // Number of nodes in the network
    topology: Topology,
    // Network topology type
    algorithm: Algorithm,
    // Algorithm to simulate
    failure_model: FailureModel,
    // Failure model to simulate
    failure_rate: Float,
    // Failure rate parameter
  )
}

/// Helper functions for type conversion and display
/// Converts topology type to human-readable string
pub fn topology_to_string(topology: Topology) -> String {
  case topology {
    Full -> "Full"
    Grid3D -> "3D Grid"
    Line -> "Line"
    Imperfect3D -> "Imperfect 3D Grid"
  }
}

/// Converts algorithm type to human-readable string
pub fn algorithm_to_string(algorithm: Algorithm) -> String {
  case algorithm {
    Gossip -> "Gossip"
    PushSum -> "Push-Sum"
  }
}
