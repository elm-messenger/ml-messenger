open Ml_regl_core
open Messenger

type msg = Layer of Layer.Model.msg

let layer = Component.port (fun msg -> Layer msg) (fun (Layer msg) -> Some msg)

type data = {
  layers : (unit, Lib.User_data.user_data, string, msg, unit) Component.t list;
  last_clicked : int option;
}

let rect left top width height id color =
  { Layer.Rect.Model.left; top; width; height; id; color }

let init runtime env _msg =
  let make target z_index rects =
    Component.make layer Layer.Model.component
      { Layer.Model.target; z_index; rects }
      runtime env
  in
  {
    layers =
      [
        make "A" 0
          [
            rect 150. 150. 200. 200. 0 Color.blue;
            rect 200. 200. 200. 200. 1 Color.red;
          ];
        make "B" 1
          [
            rect 250. 250. 200. 200. 2 (Color.rgb 1. 1. 0.);
            rect 300. 300. 200. 200. 3 (Color.rgb 0.6 0.3 0.1);
          ];
      ];
    last_clicked = None;
  }

let handle data (Layer (Rect_clicked id)) = { data with last_clicked = Some id }

let update runtime env evnt data =
  let layers, msgs, soms, (env, _block) =
    Component.update_children runtime env evnt data.layers
  in
  let data = List.fold_left handle { data with layers } msgs in
  match evnt with
  | Regl_proto.KeyDown "Backspace" ->
      (data, [ Scene.SOMChangeScene (By_name "Home") ], env)
  | _ -> (data, soms, env)

let view runtime env data =
  Regl_common.group []
    [
      Regl_builtin_programs.clear Color.white;
      Regl_builtin_programs.textbox (0., 20.) 24.
        "Components: click rectangles; Backspace home" "firacode" Color.black;
      Regl_builtin_programs.textbox (0., 55.) 20.
        ("Last clicked rect: "
        ^
        match data.last_clicked with
        | None -> "none"
        | Some id -> string_of_int id)
        "firacode" Color.black;
      Component.view_components runtime env data.layers;
    ]

let scenecon : (_, _, _, _, _, _, _) Scene.concrete_scene =
  { init; update; view }

let scene msg runtime env = Scene.abstract scenecon msg runtime env
