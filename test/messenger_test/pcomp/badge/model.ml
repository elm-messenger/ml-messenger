open Ml_regl_core
open Messenger_extra

type msg = Init of string | SetText of string | Flash
type data = { target : string; text : string; color : Color.t }

let init _runtime _env = function
  | Init text -> { target = "badge"; text; color = Color.rgb 0.9 0.95 1. }
  | _ -> { target = "badge"; text = "portable"; color = Color.rgb 0.9 0.95 1. }

let update _runtime env _evt data = (data, [], (env, false))

let updaterec _runtime env msg data =
  match msg with
  | Init text -> ({ data with text }, [], env)
  | SetText text -> ({ data with text; color = Color.rgb 0.75 1. 0.82 }, [], env)
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

let component : (_, _, _, _, _) Portable_component.concrete_portable_component =
  { init; update; updaterec; view }
