import args
import gleam/int
import gleam/io
import types.{Arguments}
import working_actor_simulation

/// Main entry point for the Gossip Algorithm Simulator
/// Parses command line arguments and runs the appropriate simulation
/// Outputs only the convergence time in milliseconds as required by the project specification
pub fn main() {
  case args.parse_arguments() {
    Ok(parsed_arguments) -> {
      // Run simulation with parsed command line arguments
      let simulation_result =
        working_actor_simulation.run_actor_simulation(
          parsed_arguments.num_nodes,
          parsed_arguments.topology,
          parsed_arguments.algorithm,
          parsed_arguments.failure_model,
          parsed_arguments.failure_rate,
        )
      // Print only the convergence time as required by project specification
      io.println(int.to_string(simulation_result.convergence_time_ms))
    }
    Error(_) -> {
      // Fallback: run default simulation if argument parsing fails
      let default_arguments =
        Arguments(
          num_nodes: 10,
          topology: types.Full,
          algorithm: types.Gossip,
          failure_model: types.NoFailure,
          failure_rate: 0.0,
        )
      let simulation_result =
        working_actor_simulation.run_actor_simulation(
          default_arguments.num_nodes,
          default_arguments.topology,
          default_arguments.algorithm,
          default_arguments.failure_model,
          default_arguments.failure_rate,
        )
      // Print only the convergence time as required by project specification
      io.println(int.to_string(simulation_result.convergence_time_ms))
    }
  }
}
