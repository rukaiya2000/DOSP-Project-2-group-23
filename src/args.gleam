// CLI parsing via Erlang FFI argv helper
import argv
import gleam/float
import gleam/int
import gleam/string
import types.{
  type Algorithm, type Arguments, type FailureModel, Arguments,
  ConnectionFailure, Full, Gossip, Grid3D, Imperfect3D, Line, NoFailure,
  NodeFailure, PushSum,
}

// Command line argument parsing
pub fn parse_arguments() -> Result(Arguments, String) {
  let args = argv.get_args()
  case args {
    // Full specification with failure parameters
    [num_nodes_s, topology_s, algorithm_s, failure_model_s, failure_rate_s, ..] -> {
      case int.parse(num_nodes_s) {
        Ok(num_nodes) -> {
          case parse_topology(topology_s) {
            Ok(topology) -> {
              case parse_algorithm(algorithm_s) {
                Ok(algorithm) -> {
                  case parse_failure_model(failure_model_s) {
                    Ok(failure_model) -> {
                      case float.parse(failure_rate_s) {
                        Ok(failure_rate) ->
                          Ok(Arguments(
                            num_nodes: num_nodes,
                            topology: topology,
                            algorithm: algorithm,
                            failure_model: failure_model,
                            failure_rate: failure_rate,
                          ))
                        Error(_) -> Error("Invalid failure rate")
                      }
                    }
                    Error(e) -> Error(e)
                  }
                }
                Error(e) -> Error(e)
              }
            }
            Error(e) -> Error(e)
          }
        }
        Error(_) -> Error("Invalid numNodes: " <> num_nodes_s)
      }
    }
    // Basic specification without failure parameters (fallback to no failures)
    [num_nodes_s, topology_s, algorithm_s, ..] -> {
      case int.parse(num_nodes_s) {
        Ok(num_nodes) -> {
          case parse_topology(topology_s) {
            Ok(topology) -> {
              case parse_algorithm(algorithm_s) {
                Ok(algorithm) ->
                  Ok(Arguments(
                    num_nodes: num_nodes,
                    topology: topology,
                    algorithm: algorithm,
                    failure_model: NoFailure,
                    failure_rate: 0.0,
                  ))
                Error(e) -> Error(e)
              }
            }
            Error(e) -> Error(e)
          }
        }
        Error(_) -> Error("Invalid numNodes: " <> num_nodes_s)
      }
    }
    _ ->
      Error(
        "Usage: gleam run -- <numNodes> <topology> <algorithm> [failureModel] [failureRate]\n"
        <> "  Examples:\n"
        <> "    gleam run -- 10 full gossip\n"
        <> "    gleam run -- 10 full gossip node 0.1\n"
        <> "    gleam run -- 10 3d push-sum connection 0.05",
      )
  }
}

fn parse_topology(s: String) -> Result(_, String) {
  let lower = string.lowercase(s)
  case lower {
    "full" -> Ok(Full)
    "3d" -> Ok(Grid3D)
    "line" -> Ok(Line)
    "imp3d" -> Ok(Imperfect3D)
    _ -> Error("Invalid topology: " <> s)
  }
}

pub fn parse_algorithm(algorithm: String) -> Result(Algorithm, String) {
  case string.lowercase(algorithm) {
    "gossip" -> Ok(Gossip)
    "push-sum" -> Ok(PushSum)
    _ -> Error("Invalid algorithm: " <> algorithm)
  }
}

pub fn parse_failure_model(
  failure_model: String,
) -> Result(FailureModel, String) {
  case string.lowercase(failure_model) {
    "node" -> Ok(NodeFailure(0.0))
    "connection" -> Ok(ConnectionFailure(0.0, 0.0))
    "none" -> Ok(NoFailure)
    _ -> Error("Invalid failure model: " <> failure_model)
  }
}
