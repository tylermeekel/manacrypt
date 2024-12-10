import app/middleware
import app/router/v1
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use req <- middleware.middleware(req)

  case wisp.path_segments(req) {
    ["v1", ..rest] -> v1.handle_request(req, rest)
    _ -> wisp.not_found()
  }
}
