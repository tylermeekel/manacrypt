import app/scryfall
import app/state
import gleam/http
import gleam/io
import gleam/json
import gleam/list
import mc_shared.{
  type LoginResponse, type RegisterResponse, LoginResponse, RegisterResponse,
} as shared
import pog
import wisp.{type Request, type Response}

pub fn handle_request(
  state: state.State,
  req: Request,
  api_path: List(String),
) -> Response {
  case api_path {
    ["cards"] -> search_cards(req)
    ["auth", "login"] -> login(req, state.database)
    ["auth", "register"] -> register(req, state.database)
    _ -> wisp.not_found()
  }
}

fn search_cards(req: Request) -> Response {
  // Middleware
  use <- wisp.require_method(req, http.Get)

  let search_query_result =
    wisp.get_query(req)
    |> list.key_find("query")

  case search_query_result {
    Ok(search_query) -> {
      case scryfall.get_cards(search_query) {
        Error(_) -> wisp.bad_request()
        Ok(cards) -> {
          let object =
            json.object([#("cards", json.array(cards, shared.card_to_json))])
          let obj_string = json.to_string_tree(object)
          wisp.json_response(obj_string, 200)
        }
      }
    }
    Error(_) -> wisp.bad_request()
  }
}

fn login(req: Request, db: pog.Connection) -> Response {
  use json <- wisp.require_json(req)
  use <- wisp.require_method(req, http.Post)

  let query =
    "
    SELECT
      username
    FROM
      users
    WHERE username = $1 AND password = $2
  "

  let json_result = shared.decode_login_request(json)

  let login_response = case json_result {
    Error(e) -> {
      io.debug(e)
      #(LoginResponse(False, "", ["Bad Request"]), 400)
    }
    Ok(shared.LoginRequest(username, password)) -> {
      let db_response_result =
        pog.query(query)
        |> pog.parameter(pog.text(username))
        |> pog.parameter(pog.text(password))
        |> pog.execute(db)

      case db_response_result {
        Error(e) -> {
          io.debug(e)
          #(LoginResponse(False, "", ["Internal Server Error"]), 500)
        }
        Ok(pog.Returned(row_count, _)) -> {
          case row_count > 0 {
            // A no-match (no user-pass combination) has to return a 200
            // because I want to be able to handle the error message from
            // the backend, and lustre gets rid of the response if it returns
            // a 401. >:(
            False -> #(
              LoginResponse(False, "", ["Incorrect Username or Password"]),
              200,
            )
            True -> #(LoginResponse(True, "", ["Logged In!"]), 200)
          }
        }
      }
    }
  }

  let #(login_response, status_code) = login_response
  let string_tree =
    json.to_string_tree(shared.login_response_to_json(login_response))

  wisp.json_response(string_tree, status_code)
}

fn register(req: Request, db: pog.Connection) -> Response {
  use json <- wisp.require_json(req)
  use <- wisp.require_method(req, http.Post)

  let query =
    "
    SELECT username FROM users WHERE username = $1
  "
  let json_result = shared.decode_register_request(json)

  let register_response = case json_result {
    Error(e) -> {
      io.debug(e)
      #(RegisterResponse(False, "", ["Bad Request"]), 400)
    }
    Ok(shared.RegisterRequest(requested_username, requested_password)) -> {
      let db_response_result =
        pog.query(query)
        |> pog.parameter(pog.text(requested_username))
        |> pog.execute(db)

      case db_response_result {
        Error(e) -> {
          io.debug(e)
          #(RegisterResponse(False, "", ["Internal Server Error"]), 500)
        }
        Ok(pog.Returned(row_count, _)) -> {
          case row_count > 0 {
            True -> #(
              RegisterResponse(False, "", ["Username Already Exists"]),
              200,
            )
            False -> create_user(requested_username, requested_password, db)
          }
        }
      }
    }
  }

  let #(register_response, status_code) = register_response

  let string_tree =
    json.to_string_tree(shared.register_response_to_json(register_response))

  wisp.json_response(string_tree, status_code)
}

fn create_user(username: String, password: String, db: pog.Connection) {
  let query = "INSERT INTO users(username, password) VALUES($1, $2)"
  // TODO: Add password salting and hashing, I won't for now just to make sure this works!
  let db_response_result =
    pog.query(query)
    |> pog.parameter(pog.text(username))
    |> pog.parameter(pog.text(password))
    |> pog.execute(db)

  case db_response_result {
    Error(e) -> {
      io.debug(e)
      #(RegisterResponse(False, "", ["Internal Server Error"]), 500)
    }
    Ok(_) -> {
      // Add JWT generation, etc
      #(RegisterResponse(True, "", []), 201)
    }
  }
}
