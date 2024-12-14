import app/router
import app/state
import dot_env as dot
import dot_env/env
import gleam/erlang/process
import gleam/io
import gleam/option
import mist
import pog
import wisp
import wisp/wisp_mist

pub fn main() {
  // load .env
  dot.load_default()

  let db_username = case env.get_string("POSTGRES_USER") {
    Error(e) -> {
      io.debug(e)
      ""
    }
    Ok(var) -> var
  }

  let db_password = case env.get_string("POSTGRES_PASSWORD") {
    Error(e) -> {
      io.debug(e)
      ""
    }
    Ok(var) -> var
  }

  // Setup DB
  let db =
    pog.default_config()
    |> pog.host("localhost")
    |> pog.database("manacrypt")
    |> pog.user(db_username)
    |> pog.password(option.Some(db_password))
    |> pog.pool_size(10)
    |> pog.connect

  // setup wisp
  wisp.configure_logger()

  let secret_key_base = wisp.random_string(64)

  // Create new application state, create a function capture
  // that includes it
  let app_state = state.State(db)
  let handle_request = router.handle_request(app_state, _)

  // Start the server
  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}
