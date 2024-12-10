import gleam/json

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
