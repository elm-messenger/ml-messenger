open Ml_regl_core
open Messenger

type layer_target = string
type layer_msg = NullLayerMsg | LayerRectReport of int
type scene_common_data = unit

type rect_data = {
  left : float;
  top : float;
  width : float;
  height : float;
  id : int;
  color : Color.t;
}

type rect_msg =
  | RectInit of rect_data
  | RectMsg of Color.t
  | RectReportMsg of int
  | NullRectMsg

type rect_target = int
type rect_base_data = unit

module Rect = struct
  let fallback =
    {
      left = 0.;
      top = 0.;
      width = 0.;
      height = 0.;
      id = 0;
      color = Color.black;
    }

  let init _runtime _env = function
    | RectInit init_data -> (init_data, ())
    | _ -> (fallback, ())

  let update _runtime env evnt data basedata =
    match evnt with
    | Regl_proto.MouseDown { button = 1; x; y } ->
        if
          Camera.judge_mouse_rect_with_camera ~view_size:(1920., 1080.)
            ~camera:env.Base.global_data.camera ~mouse:(x, y)
            ~pos:(data.left, data.top) ~size:(data.width, data.height)
        then
          ( ({ data with color = Color.black }, basedata),
            [
              General_model.Other (data.id + 1, RectMsg Color.green);
              General_model.Parent (OtherMsg (RectReportMsg data.id));
            ],
            (env, true) )
        else ((data, basedata), [], (env, false))
    | _ -> ((data, basedata), [], (env, false))

  let updaterec _runtime env msg data basedata =
    match msg with
    | RectMsg c -> (({ data with color = c }, basedata), [], env)
    | _ -> ((data, basedata), [], env)

  let view _runtime _env data _basedata =
    ( Regl_builtin_programs.rect (data.left, data.top) (data.width, data.height)
        data.color,
      0 )

  let matcher data _basedata target = target = data.id

  let componentcon : (_, _, _, _, _, _, _) Component.concrete_user_component =
    { init; update; updaterec; view; matcher }

  let component msg runtime env =
    Component.gen_component componentcon msg runtime env
end

type child_component =
  ( scene_common_data,
    Lib.User_data.user_data,
    rect_target,
    rect_msg,
    rect_base_data,
    Lib.Base.scene_msg )
  Component.abstract_component

type layer_data = {
  children : child_component list;
  z_index : int;
  target : layer_target;
}

let rect left top width height id color =
  { left; top; width; height; id; color }

let handle_child_msg data env = function
  | General_model.SOMMsg som ->
      (data, [ General_model.Parent (SOMMsg som) ], env)
  | OtherMsg (RectReportMsg id) ->
      (data, [ General_model.Parent (OtherMsg (LayerRectReport id)) ], env)
  | _ -> (data, [], env)

let handle_child_msgs data env msgs =
  List.fold_left
    (fun (data, layer_msgs, env) msg ->
      let data, new_msgs, env = handle_child_msg data env msg in
      (data, layer_msgs @ new_msgs, env))
    (data, [], env) msgs

let make_layer_component ~target ~z_index initial_rects =
  let init runtime env _msg =
    ( {
        children =
          List.map
            (fun r -> Rect.component (RectInit r) runtime env)
            initial_rects;
        z_index;
        target;
      },
      () )
  in
  let update runtime env evt data basedata =
    let children, msgs, (env1, block) =
      Component.update_components runtime env evt data.children
    in
    let data1, msgs2, env2 =
      handle_child_msgs { data with children } env1 msgs
    in
    ((data1, basedata), msgs2, (env2, block))
  in
  let updaterec _runtime env _msg data basedata = ((data, basedata), [], env) in
  let view runtime env data _basedata =
    (Component.view_components runtime env data.children, data.z_index)
  in
  let matcher data _basedata tar = tar = data.target in
  let componentcon : (_, _, _, _, _, _, _) Component.concrete_user_component =
    { init; update; updaterec; view; matcher }
  in
  fun msg runtime env -> Component.gen_component componentcon msg runtime env

type layer_component =
  ( scene_common_data,
    Lib.User_data.user_data,
    layer_target,
    layer_msg,
    unit,
    Lib.Base.scene_msg )
  Component.abstract_component

type data = { layers : layer_component list; last_clicked : int option }

let layer_a =
  make_layer_component ~target:"A" ~z_index:0
    [
      rect 150. 150. 200. 200. 0 Color.blue;
      rect 200. 200. 200. 200. 1 Color.red;
    ]

let layer_b =
  make_layer_component ~target:"B" ~z_index:1
    [
      rect 250. 250. 200. 200. 2 (Color.rgb 1. 1. 0.);
      rect 300. 300. 200. 200. 3 (Color.rgb 0.6 0.3 0.1);
    ]

let init runtime env _msg =
  let envcd = Base.add_common_data () env in
  {
    layers =
      [ layer_a NullLayerMsg runtime envcd; layer_b NullLayerMsg runtime envcd ];
    last_clicked = None;
  }

let handle_layer_msg data env = function
  | General_model.SOMMsg som -> (data, [ som ], env)
  | OtherMsg (LayerRectReport id) ->
      ({ data with last_clicked = Some id }, [], env)
  | _ -> (data, [], env)

let handle_layer_msgs data env msgs =
  List.fold_left
    (fun (data, soms, env) msg ->
      let data, new_soms, env = handle_layer_msg data env msg in
      (data, soms @ new_soms, env))
    (data, [], env) msgs

let update runtime env evnt data =
  let envcd = Base.add_common_data () env in
  let layers1, msgs1, (env1, _block) =
    Component.update_components runtime envcd evnt data.layers
  in
  let data1, sommsgs, env2 =
    handle_layer_msgs { data with layers = layers1 } env1 msgs1
  in
  let env2 = Base.remove_common_data env2 in
  match evnt with
  | Regl_proto.KeyDown "Backspace" ->
      (data1, [ Scene.SOMChangeScene (None, "Home") ], env2)
  | _ -> (data1, sommsgs, env2)

let view runtime env data =
  let envcd = Base.add_common_data () env in
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
      Component.view_components runtime envcd data.layers;
    ]

let scenecon : (_, _, _, _, _, _, _) Scene.concrete_scene =
  { init; update; view }

let scene _msg runtime env = Scene.abstract scenecon None runtime env
