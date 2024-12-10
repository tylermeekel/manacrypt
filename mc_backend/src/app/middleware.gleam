import cors_builder as cors
import gleam/http
import wisp

fn cors() {
  cors.new()
  |> cors.allow_origin("http://localhost:1234")
  |> cors.allow_origin("http://127.0.0.1:1234")
  |> cors.allow_method(http.Get)
}

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  // CORS stuff?
  use req <- cors.wisp_middleware(req, cors())

  handle_request(req)
}
