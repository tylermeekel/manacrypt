import app/scryfall
import gleam/http
import gleam/json
import gleam/list
import mc_shared
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, api_path: List(String)) -> Response {
  case api_path {
    ["cards"] -> search_cards(req)
    ["auth", "login"] -> login(req)
    ["auth", "register"] -> register(req)
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
            json.object([#("cards", json.array(cards, mc_shared.card_to_json))])
          let obj_string = json.to_string_tree(object)
          wisp.json_response(obj_string, 200)
        }
      }
    }
    Error(_) -> wisp.bad_request()
  }
}

fn login(req: Request) -> Response {
  todo
}

fn register(req: Request) -> Response {
  todo
}
