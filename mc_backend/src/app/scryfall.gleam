import decode/zero
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/io
import gleam/json
import mc_shared.{type Card, Card}

pub fn get_cards(search_query: String) -> Result(List(Card), Nil) {
  let assert Ok(base_req) = request.to("https://api.scryfall.com/cards/search")

  let req =
    request.set_method(base_req, http.Get)
    |> request.set_query([#("q", search_query)])

  let resp_result = httpc.send(req)
  case resp_result {
    Error(e) -> {
      io.debug("get_cards Response Result Error")
      io.debug(e)
      Error(Nil)
    }
    Ok(resp) -> {
      let decoder = {
        use id <- zero.field("id", zero.string)
        use name <- zero.field("name", zero.string)
        zero.success(Card(id:, name:, count: 1))
      }

      case
        json.decode(resp.body, fn(data) {
          zero.run(data, zero.at(["data"], zero.list(decoder)))
        })
      {
        Error(e) -> {
          io.debug("get_cards Decode Error")
          io.debug(e)
          Error(Nil)
        }
        Ok(card_list) -> Ok(card_list)
      }
    }
  }
}
