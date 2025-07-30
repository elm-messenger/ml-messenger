
type init_env = { viewport : int * int }
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


module JsExport : sig
  val export : 'a ui -> unit
end
