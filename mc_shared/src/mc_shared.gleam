import decode/zero
import gleam/dynamic
import gleam/json

pub type LoginResponse {
  LoginResponse(success: Bool, jwt: String, errors: List(String))
}

pub fn login_response_to_json(response: LoginResponse) {
  json.object([
    #("success", json.bool(response.success)),
    #("jwt", json.string(response.jwt)),
    #("errors", json.array(response.errors, json.string)),
  ])
}

pub type LoginRequest {
  LoginRequest(username: String, password: String)
}

pub fn decode_login_request(request: dynamic.Dynamic) {
  let decoder = {
    use username <- zero.field("username", zero.string)
    use password <- zero.field("password", zero.string)
    zero.success(LoginRequest(username, password))
  }

  zero.run(request, decoder)
}

pub type RegisterResponse {
  RegisterResponse(success: Bool, jwt: String, errors: List(String))
}

pub fn register_response_to_json(register_response: RegisterResponse) {
  json.object([
    #("success", json.bool(register_response.success)),
    #("jwt", json.string(register_response.jwt)),
    #("errors", json.array(register_response.errors, json.string)),
  ])
}

pub type RegisterRequest {
  RegisterRequest(username: String, password: String)
}

pub fn decode_register_request(request: dynamic.Dynamic) {
  let decoder = {
    use username <- zero.field("username", zero.string)
    use password <- zero.field("password", zero.string)
    zero.success(RegisterRequest(username, password))
  }

  zero.run(request, decoder)
}

pub type Card {
  Card(id: String, name: String, count: Int)
}

pub fn card_to_json(card: Card) -> json.Json {
  json.object([
    #("id", json.string(card.id)),
    #("name", json.string(card.name)),
    #("count", json.int(card.count)),
  ])
}
