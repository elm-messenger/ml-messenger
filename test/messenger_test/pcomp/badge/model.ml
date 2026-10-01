open Ml_regl_core
open Messenger

(* An ordinary component that knows nothing about its parent, so any parent can
   use it through a port. *)
type msg = Set_text of string | Flash
type init = { id : string; text : string }
type data = { id : string; text : string; color : Color.t }

let init _runtime _env (init : init) =
  { id = init.id; text = init.text; color = Color.rgb 0.9 0.95 1. }

let update _runtime env _evnt data = (data, [], (env, false))

let updaterec _runtime env msg data =
  match msg with
  | Set_text text ->
      ({ data with text; color = Color.rgb 0.75 1. 0.82 }, [], env)
  | Flash -> ({ data with color = Color.rgb 1. 0.88 0.5 }, [], env)

let view _runtime _env data =
  ( Regl_common.group []
      [
        Regl_builtin_programs.rect_centered (560., 220.) (360., 96.) 0.
          data.color;
        Regl_builtin_programs.textbox_centered (560., 220.) 26. data.text
          "firacode" Color.black;
      ],
    1 )

let component =
  {
    Component.init;
    update;
    updaterec;
    view;
    targets = (fun data -> [ data.id ]);
  }
