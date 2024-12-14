import app/middleware
import app/router/v1
import app/state
import wisp.{type Request, type Response}

pub fn handle_request(state: state.State, req: Request) -> Response {
  use req <- middleware.middleware(req)

  case wisp.path_segments(req) {
    ["v1", ..rest] -> v1.handle_request(state, req, rest)
    _ -> wisp.not_found()
  }
}
