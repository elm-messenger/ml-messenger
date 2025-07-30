module Html = Js_of_ocaml.Dom_html
module Dom = Js_of_ocaml.Dom
module Js = Js_of_ocaml.Js
module Ui = Messenger.Ui

let _ = print_endline "Test module loaded successfully."

type model = { count : int }

let init : Ui.init_env -> model = fun _ -> { count = 2 }

let update : Ui.world_event -> model -> model * Ui.side_effect =
 fun _ model -> ({ count = model.count + 1 }, { renderable = true })

let ui : model Ui.ui = { init; update }
let _ = Messenger.Ui.export ui
