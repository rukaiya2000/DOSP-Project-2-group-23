import gleam/erlang/charlist
import gleam/list

@external(erlang, "init", "get_plain_arguments")
fn get_plain_arguments() -> List(charlist.Charlist)

pub fn get_args() -> List(String) {
  list.map(get_plain_arguments(), charlist.to_string)
}
