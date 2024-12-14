import decode/zero
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/uri
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html
import lustre/event
import lustre_http
import mc_shared.{type Card, type LoginResponse, type RegisterResponse, Card} as shared

pub const api_base_url = "http://localhost:8000/v1"

// FFI
@external(javascript, "./ffi.mjs", "downloadObjectAsJson")
fn download_object_as_json(json_string: String, export_name: String) -> Nil

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
    auth_status: AuthenticationStatus,
    login_fields: #(String, String),
  )
}

type AuthenticationStatus {
  Authenticated(jwt: String, username: String)
  Unauthenticated
}

fn init(_flags) -> #(Model, Effect(a)) {
  #(
    Model(
      collection: [],
      searched_cards: [],
      search_query: "",
      auth_status: Unauthenticated,
      login_fields: #("", ""),
    ),
    effect.none(),
  )
}

// ------ VIEW ------
fn view(model: Model) {
  html.div(
    [attribute.class("flex flex-col max-h-screen overflow-y-auto h-screen")],
    [
      header_view(model),
      html.div([attribute.class("flex h-full")], [
        collection_view(model.collection),
        search_view(model.search_query, model.searched_cards),
      ]),
    ],
  )
}

fn header_view(model: Model) {
  html.header(
    [
      attribute.class(
        "flex items-center h-20 px-6 bg-slate-900 justify-between min-h-20",
      ),
    ],
    [
      html.h1([attribute.class("text-2xl font-extrabold")], [
        html.span([attribute.class("text-sky-400")], [element.text("Mana")]),
        html.span([attribute.class("text-white")], [element.text("crypt")]),
      ]),
      login_form_view(model),
    ],
  )
}

fn login_form_view(model: Model) {
  case model.auth_status {
    Authenticated(_, _) -> {
      html.div([attribute.class("flex gap-2")], [
        html.button(
          [
            attribute.class("text-lg text-white rounded-md px-4 bg-slate-600"),
            event.on_click(UserClickedLogoutButton),
          ],
          [element.text("Logout")],
        ),
      ])
    }
    Unauthenticated -> {
      html.div([attribute.class("flex gap-2")], [
        html.input([
          attribute.class("text-lg rounded-md px-2"),
          attribute.placeholder("Username"),
          event.on_input(UserChangedUsernameField),
          attribute.value(model.login_fields.0),
        ]),
        html.input([
          attribute.class("text-lg rounded-md px-2"),
          attribute.placeholder("Password"),
          attribute.type_("password"),
          event.on_input(UserChangedPasswordField),
          attribute.value(model.login_fields.1),
        ]),
        html.button(
          [
            attribute.class("text-lg text-white rounded-md px-4 bg-slate-600"),
            event.on_click(UserClickedLoginButton),
          ],
          [element.text("Login")],
        ),
        html.button(
          [
            attribute.class("text-lg text-white rounded-md px-4 bg-slate-600"),
            event.on_click(UserClickedRegisterButton),
          ],
          [element.text("Register")],
        ),
      ])
    }
  }
}

fn collection_view(collection: List(Card)) {
  html.div(
    [
      attribute.class(
        "flex-1 gap-2 flex flex-col p-4 max-h-full overflow-y-auto",
      ),
    ],
    [
      html.h1([attribute.class("text-center font-bold text-3xl")], [
        element.text("Collection List"),
      ]),
      html.div([], [
        html.button(
          [
            attribute.class("text-white rounded-md px-2 bg-slate-600"),
            event.on_click(UserClickedExportButton),
          ],
          [element.text("Export Data")],
        ),
        collection_cards_list_view(collection),
      ]),
    ],
  )
}

fn collection_cards_list_view(cards: List(Card)) {
  html.ul(
    [],
    list.map(cards, fn(card) {
      let card_count_text = int.to_string(card.count)

      let reduce_button_text = case card.count {
        1 -> "Remove"
        _ -> "-"
      }

      html.li([attribute.class("flex p-2 justify-between hover:bg-slate-400")], [
        html.div([], [element.text(card.name)]),
        html.div([attribute.class("flex gap-2")], [
          html.button(
            [
              attribute.class("text-white rounded-md px-2 bg-slate-600"),
              event.on_click(UserDecreasedCountCollectionCard(card.id)),
            ],
            [element.text(reduce_button_text)],
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
        "gap-2 flex-1 flex flex-col p-4 bg-slate-200 max-h-full overflow-y-auto",
      ),
    ],
    [
      html.h1([attribute.class("text-center font-bold text-3xl")], [
        element.text("Search for Cards"),
      ]),
      html.div([attribute.class("flex gap-2")], [
        html.input([
          attribute.value(search_query),
          attribute.class("basis-4/6 px-2 rounded-md"),
          attribute.placeholder("Card Name"),
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
  UserClickedExportButton
  UserClickedLoginButton
  UserClickedLogoutButton
  UserClickedRegisterButton
  UserChangedUsernameField(username: String)
  UserChangedPasswordField(password: String)

  // Backend Msgs
  ApiReturnedSearchedCards(cards: Result(List(Card), lustre_http.HttpError))
  ApiReturnedLoginResponse(
    response: Result(LoginResponse, lustre_http.HttpError),
  )
  ApiReturnedRegisterResponse(
    response: Result(RegisterResponse, lustre_http.HttpError),
  )
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
      let assert Ok(card) =
        list.find(model.collection, fn(card) { card.id == card_id })

      case card.count == 1 {
        False -> {
          let updated_cards =
            list.map(model.collection, fn(card) {
              case card.id == card_id {
                False -> card
                True -> Card(..card, count: card.count - 1)
              }
            })
          #(Model(..model, collection: updated_cards), effect.none())
        }
        True -> {
          let updated_cards =
            list.filter(model.collection, fn(card) { card.id != card_id })

          #(Model(..model, collection: updated_cards), effect.none())
        }
      }
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
    UserClickedExportButton -> {
      let json_string = cards_to_json_string(model.collection)
      download_object_as_json(json_string, "cards")
      #(model, effect.none())
    }
    UserClickedLoginButton -> {
      #(model, do_login(model.login_fields.0, model.login_fields.1))
    }
    UserClickedLogoutButton -> {
      // TODO: Clear JWT from localStorage
      #(Model(..model, auth_status: Unauthenticated), effect.none())
    }
    UserClickedRegisterButton -> {
      #(model, do_register(model.login_fields.0, model.login_fields.1))
    }
    UserChangedUsernameField(username) -> {
      #(
        Model(..model, login_fields: #(username, model.login_fields.1)),
        effect.none(),
      )
    }
    UserChangedPasswordField(password) -> {
      #(
        Model(..model, login_fields: #(model.login_fields.0, password)),
        effect.none(),
      )
    }
    // API Msgs
    ApiReturnedSearchedCards(cards_result) -> {
      case cards_result {
        Ok(cards) -> #(Model(..model, searched_cards: cards), effect.none())
        Error(_) -> #(model, effect.none())
      }
    }
    ApiReturnedLoginResponse(response_result) -> {
      case response_result {
        Error(e) -> {
          io.debug(e)
          #(model, effect.none())
        }
        Ok(response) -> {
          case response.success {
            False -> {
              // TODO: Add error message to login!
              #(model, effect.none())
            }
            True -> {
              // TODO: Get username from response!
              #(
                Model(
                  ..model,
                  auth_status: Authenticated(jwt: response.jwt, username: ""),
                ),
                effect.none(),
              )
            }
          }
        }
      }
    }
    ApiReturnedRegisterResponse(response_result) -> {
      case response_result {
        Error(e) -> {
          io.debug(e)
          #(model, effect.none())
        }
        Ok(response) -> {
          case response.success {
            False -> {
              // TODO: Add error message!
              io.println("Error registering")
              #(model, effect.none())
            }
            True -> {
              // TODO: Get username from response!
              #(
                Model(
                  ..model,
                  auth_status: Authenticated(jwt: response.jwt, username: ""),
                ),
                effect.none(),
              )
            }
          }
        }
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

fn do_login(username: String, password: String) -> Effect(Msg) {
  let request_body =
    json.object([
      #("username", json.string(username)),
      #("password", json.string(password)),
    ])

  let url = api_base_url <> "/auth/login"

  let response_decoder = {
    use success <- zero.field("success", zero.bool)
    use jwt <- zero.field("jwt", zero.string)
    use errors <- zero.field("errors", zero.list(zero.string))
    zero.success(shared.LoginResponse(success:, jwt:, errors:))
  }

  lustre_http.post(
    url,
    request_body,
    lustre_http.expect_json(
      fn(data) { zero.run(data, response_decoder) },
      ApiReturnedLoginResponse,
    ),
  )
}

fn do_register(username: String, password: String) -> Effect(Msg) {
  let request_body =
    json.object([
      #("username", json.string(username)),
      #("password", json.string(password)),
    ])

  let url = api_base_url <> "/auth/register"

  let response_decoder = {
    use success <- zero.field("success", zero.bool)
    use jwt <- zero.field("jwt", zero.string)
    use errors <- zero.field("errors", zero.list(zero.string))
    zero.success(shared.RegisterResponse(success:, jwt:, errors:))
  }

  lustre_http.post(
    url,
    request_body,
    lustre_http.expect_json(
      fn(data) { zero.run(data, response_decoder) },
      ApiReturnedRegisterResponse,
    ),
  )
}

// ------ UTIL ------
fn cards_to_json_string(cards: List(Card)) -> String {
  json.array(cards, shared.card_to_json)
  |> json.to_string
}
