import decode/zero
import gleam/int
import gleam/list
import gleam/uri
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html
import lustre/event
import lustre_http
import mc_shared.{type Card, Card}

pub const api_base_url = "http://localhost:8000/v1"

// ------ MAIN ------
pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

// ------ MODEL ------
type Model {
  Model(
    collection: List(Card),
    searched_cards: List(Card),
    search_query: String,
  )
}

fn init(_flags) -> #(Model, Effect(a)) {
  #(Model([], [], ""), effect.none())
}

// ------ VIEW ------
fn view(model: Model) {
  html.div([attribute.class("flex h-screen")], [
    collection_view(model.collection),
    search_view(model.search_query, model.searched_cards),
  ])
}

fn collection_view(collection: List(Card)) {
  html.div(
    [
      attribute.class(
        "flex-1 gap-2 flex flex-col p-4 max-h-screen overflow-y-auto",
      ),
    ],
    [
      html.h1([attribute.class("text-center font-bold text-3xl")], [
        element.text("Collection List"),
      ]),
      html.div([], [collection_cards_list_view(collection)]),
    ],
  )
}

fn collection_cards_list_view(cards: List(Card)) {
  html.ul(
    [],
    list.map(cards, fn(card) {
      let card_count_text = int.to_string(card.count)

      html.li([attribute.class("flex p-2 justify-between hover:bg-slate-400")], [
        html.div([], [element.text(card.name)]),
        html.div([attribute.class("flex gap-2")], [
          html.button(
            [
              attribute.class("bg-slate-600 text-white rounded-md px-2"),
              event.on_click(UserDecreasedCountCollectionCard(card.id)),
            ],
            [element.text("-")],
          ),
          html.p([attribute.class("bg-slate-600 text-white rounded-md px-2")], [
            element.text(card_count_text),
          ]),
          html.button(
            [
              attribute.class("bg-slate-600 text-white rounded-md px-2"),
              event.on_click(UserIncreasedCountCollectionCard(card.id)),
            ],
            [element.text("+")],
          ),
        ]),
      ])
    }),
  )
}

fn search_view(search_query: String, searched_cards: List(Card)) {
  html.div(
    [
      attribute.class(
        "gap-2 flex-1 flex flex-col p-4 bg-slate-200 max-h-screen overflow-y-auto",
      ),
    ],
    [
      html.h1([attribute.class("text-center font-bold text-3xl")], [
        element.text("Search for Cards"),
      ]),
      html.div([attribute.class("flex gap-2")], [
        html.input([
          attribute.value(search_query),
          attribute.class("basis-4/6 border px-2 border-slate-600 rounded-md"),
          event.on_input(UserTypedInSearchBox),
          event.on_keypress(UserPressedKeyInSearchBox),
        ]),
        html.button(
          [
            attribute.class(
              "basis-2/6 bg-slate-600 rounded-md text-white text-lg",
            ),
            event.on_click(UserClickedSearchButton),
          ],
          [element.text("Search")],
        ),
      ]),
      html.div([], [searched_cards_list_view(searched_cards)]),
    ],
  )
}

fn searched_cards_list_view(cards: List(Card)) {
  html.ul(
    [],
    list.map(cards, fn(card) {
      let card_count_text = int.to_string(card.count)

      html.li([attribute.class("flex p-2 justify-between hover:bg-slate-400")], [
        html.div([], [element.text(card.name)]),
        html.div([attribute.class("flex gap-2")], [
          html.button(
            [
              attribute.class("bg-slate-600 text-white rounded-md px-2"),
              event.on_click(UserDecreasedCountSearchedCard(card.id)),
            ],
            [element.text("-")],
          ),
          html.button(
            [
              attribute.class("bg-slate-600 text-white rounded-md px-2"),
              event.on_click(UserAddedCard(card)),
            ],
            [element.text("Add " <> card_count_text)],
          ),
          html.button(
            [
              attribute.class("bg-slate-600 text-white rounded-md px-2"),
              event.on_click(UserIncreasedCountSearchedCard(card.id)),
            ],
            [element.text("+")],
          ),
        ]),
      ])
    }),
  )
}

// ------ UPDATE ------
type Msg {
  // User Msgs
  UserAddedCard(card: Card)
  UserTypedInSearchBox(search_query: String)
  UserPressedKeyInSearchBox(key: String)
  UserClickedSearchButton
  UserIncreasedCountSearchedCard(card_id: String)
  UserDecreasedCountSearchedCard(card_id: String)
  UserIncreasedCountCollectionCard(card_id: String)
  UserDecreasedCountCollectionCard(card_id: String)

  // Backend Msgs
  ApiReturnedSearchedCards(cards: Result(List(Card), lustre_http.HttpError))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    // User Msgs
    UserAddedCard(card) -> {
      case
        list.any(model.collection, fn(collection_card) {
          collection_card.id == card.id
        })
      {
        False -> {
          #(
            Model(..model, collection: [card, ..model.collection]),
            effect.none(),
          )
        }
        True -> {
          let updated_cards =
            list.map(model.collection, fn(collection_card) {
              case collection_card.id == card.id {
                False -> collection_card
                True ->
                  Card(
                    ..collection_card,
                    count: collection_card.count + card.count,
                  )
              }
            })
          #(Model(..model, collection: updated_cards), effect.none())
        }
      }
    }
    UserTypedInSearchBox(query) -> {
      #(Model(..model, search_query: query), effect.none())
    }
    UserClickedSearchButton -> {
      #(model, get_cards(model.search_query))
    }
    UserDecreasedCountSearchedCard(card_id) -> {
      let updated_cards =
        list.map(model.searched_cards, fn(card) {
          case card.id == card_id {
            False -> card
            True -> Card(..card, count: card.count - 1)
          }
        })

      #(Model(..model, searched_cards: updated_cards), effect.none())
    }
    UserPressedKeyInSearchBox(key) -> {
      case key {
        "Enter" -> #(model, get_cards(model.search_query))
        _ -> #(model, effect.none())
      }
    }
    UserIncreasedCountSearchedCard(card_id) -> {
      let updated_cards =
        list.map(model.searched_cards, fn(card) {
          case card.id == card_id {
            False -> card
            True -> Card(..card, count: card.count + 1)
          }
        })
      #(Model(..model, searched_cards: updated_cards), effect.none())
    }
    UserDecreasedCountCollectionCard(card_id) -> {
      let updated_cards =
        list.map(model.collection, fn(card) {
          case card.id == card_id {
            False -> card
            True -> Card(..card, count: card.count - 1)
          }
        })
      #(Model(..model, collection: updated_cards), effect.none())
    }
    UserIncreasedCountCollectionCard(card_id) -> {
      let updated_cards =
        list.map(model.collection, fn(card) {
          case card.id == card_id {
            False -> card
            True -> Card(..card, count: card.count + 1)
          }
        })
      #(Model(..model, collection: updated_cards), effect.none())
    }
    // API Msgs
    ApiReturnedSearchedCards(cards_result) -> {
      case cards_result {
        Ok(cards) -> #(Model(..model, searched_cards: cards), effect.none())
        Error(_) -> #(model, effect.none())
      }
    }
  }
}

// ------ EFFECTS ------
fn get_cards(search_query: String) -> Effect(Msg) {
  let decoder = {
    use name <- zero.field("name", zero.string)
    use id <- zero.field("id", zero.string)
    use count <- zero.field("count", zero.int)
    zero.success(Card(name:, id:, count:))
  }

  let encoded_search_query = uri.percent_encode(search_query)
  let url = api_base_url <> "/cards?query=" <> encoded_search_query

  lustre_http.get(
    url,
    lustre_http.expect_json(
      fn(data) { zero.run(data, zero.at(["cards"], zero.list(decoder))) },
      ApiReturnedSearchedCards,
    ),
  )
}
