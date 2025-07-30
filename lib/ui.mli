
type init_env = { viewport : int * int }
type side_effect = { renderable : bool }


type 'a ui = {
  init : init_env -> 'a;
  update : Base.world_event -> 'a -> 'a * side_effect;
  debug : 'a -> string;
}


module JsExport : sig
  val export : 'a ui -> unit
end
