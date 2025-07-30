module Js = Js_of_ocaml.Js

type init_env = { viewport : int * int }

let dummy_env = { viewport = (0, 0) }

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
  debug : 'a -> string;
}

module JsExport = struct
  (* Side effect to JS Obj *)
  let render_side_effect eff =
    object%js
      val renderable = eff.renderable
      val audio = Js.null
    end

  let export opts =
    let model = ref (opts.init dummy_env) in
    let init_func = fun iopt -> model := opts.init iopt in
    let update_func =
     fun event ->
      let new_model, side_effect = opts.update event !model in
      model := new_model;
      render_side_effect side_effect
    in
    let debug_func = fun () -> Js.string (opts.debug !model) in
    Js.export "MessengerUI"
      (object%js
         val init = init_func
         val update = update_func
         val debug = debug_func
      end)
end
