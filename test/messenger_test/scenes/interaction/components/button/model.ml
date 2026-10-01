open Ml_regl_core
open Messenger

type msg = Pressed | Released

type init = {
  center : float * float;
  size : float * float;
  color : Color.t;
  content : string;
}

type state = Normal | Hovered | Down
type data = { init : init; pos : float * float; state : state }

let init _runtime _env (init : init) =
  let x, y = init.center in
  let w, h = init.size in
  { init; pos = (x -. (w /. 2.), y -. (h /. 2.)); state = Normal }

let update runtime env evnt data =
  let hovered =
    Camera.judge_mouse_rect
      ~mouse:(Base.get_mouse_pos runtime)
      ~pos:data.pos ~size:data.init.size
  in
  match evnt with
  | Regl_proto.MouseUp _ ->
      ({ data with state = Normal }, [ Component.Parent Released ], (env, false))
  | MouseDown _ when hovered ->
      ({ data with state = Down }, [ Component.Parent Pressed ], (env, true))
  | MouseDown _ -> (data, [], (env, false))
  | _ ->
      let state =
        match (hovered, data.state) with
        | true, Normal -> Hovered
        | false, Hovered -> Normal
        | _, state -> state
      in
      ({ data with state }, [], (env, false))

let updaterec _runtime env _msg data = (data, [], env)

let view _runtime _env data =
  let w, h = data.init.size in
  let size =
    match data.state with
    | Normal -> data.init.size
    | Hovered -> (w +. 10., h +. 10.)
    | Down -> (max 0. (w -. 10.), max 0. (h -. 10.))
  in
  ( Regl_common.group []
      [
        Regl_builtin_programs.rect_centered data.init.center size 0.
          data.init.color;
        Regl_builtin_programs.textbox_centered data.init.center 30.
          data.init.content "firacode" Color.black;
      ],
    0 )

let component =
  {
    Component.init;
    update;
    updaterec;
    view;
    targets = (fun _data -> [ "Button" ]);
  }
