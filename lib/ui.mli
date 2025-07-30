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

val export : 'a ui -> unit
