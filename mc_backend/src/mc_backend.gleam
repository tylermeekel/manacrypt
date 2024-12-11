import app/router
import app/state
import gleam/erlang/process
import mist
import pog
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)

  let db =
    pog.default_config()
    |> pog.host("localhost")
    |> pog.database("manacrypt")
    |> pog.pool_size(10)
    |> pog.connect

  // Create new application state, create a function capture
  // that includes it
  let app_state = state.State(db)
  let handle_request = router.handle_request(app_state, _)

  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
