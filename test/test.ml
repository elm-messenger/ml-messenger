module Html = Js_of_ocaml.Dom_html
module Dom = Js_of_ocaml.Dom
module Js = Js_of_ocaml.Js
module Ui = Messenger.Ui
module Base = Messenger.Base

let _ = print_endline "Test module loaded successfully."

type model = { count : int }

let init : Ui.init_env -> model = fun _ -> { count = 2 }

let update : Base.world_event -> model -> model * Ui.side_effect =
 fun _ model -> ({ count = model.count + 1 }, { renderable = true })

let debug : model -> string =
 fun model -> Printf.sprintf "Count: %d" model.count

(* Define the UI module with the init, update, and debug functions *)

let ui : model Ui.ui = { init; update; debug }
let _ = Messenger.Ui.JsExport.export ui
