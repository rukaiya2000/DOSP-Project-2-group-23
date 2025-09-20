// CLI parsing via Erlang FFI argv helper
import argv
import gleam/int
import gleam/string
import types.{
  type Arguments, Arguments, Full, Gossip, Grid3D, Imperfect3D, Line, PushSum,
}

// Command line argument parsing
pub fn parse_arguments() -> Result(Arguments, String) {
  let args = argv.get_args()
  case args {
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
    _ -> Error("Usage: project2 <numNodes> <topology> <algorithm>")
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

fn parse_algorithm(s: String) -> Result(_, String) {
  let lower = string.lowercase(s)
  case lower {
    "gossip" -> Ok(Gossip)
    "push-sum" -> Ok(PushSum)
    "pushsum" -> Ok(PushSum)
    _ -> Error("Invalid algorithm: " <> s)
  }
}
