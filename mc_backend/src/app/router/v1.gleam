import app/scryfall
import gleam/http
import gleam/json
import gleam/list
import mc_shared.{type Card, Card}
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, api_path: List(String)) -> Response {
  case api_path {
    ["cards"] -> search_cards(req)
    _ -> wisp.not_found()
  }
}

fn search_cards(req: Request) -> Response {
  // Middleware
  use <- wisp.require_method(req, http.Get)

  // Function Body
  let search_query_result =
    wisp.get_query(req)
    |> list.key_find("query")

  case search_query_result {
    Ok(search_query) -> {
      case scryfall.get_cards(search_query) {
        Error(_) -> wisp.bad_request()
        Ok(cards) -> {
          let object =
            json.object([#("cards", json.array(cards, card_to_json))])
          let obj_string = json.to_string_tree(object)
          wisp.json_response(obj_string, 200)
        }
      }
    }
    Error(_) -> wisp.bad_request()
  }
}

fn card_to_json(card: Card) -> json.Json {
  json.object([
    #("id", json.string(card.id)),
    #("name", json.string(card.name)),
    #("count", json.int(card.count)),
  ])
}
