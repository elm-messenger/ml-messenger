module Js = Js_of_ocaml.Js

type init_env = { client : string; version : string; viewport : int * int }
type side_effect = { renderable : bool }

type world_event =
  | MouseMove of int * int
  | MouseDown of int * int
  | MouseUp of int * int
  | KeyDown of int
  | KeyUp of int

type 'a ui = {
  init : init_env -> 'a;
  update : world_event -> 'a -> 'a * side_effect;
}

(* let show_field o field = Js.to_string (Js.Unsafe.get o field) *)

let export opts =
  Js.export "MessengerUI"
    (object%js
       method init = opts.init
       method update = opts.update
    end)
