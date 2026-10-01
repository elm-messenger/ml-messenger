open Ml_regl_core
open Messenger

type msg = Changed of float
type init = { value : float; center : float * float; width : float }
type data = { init : init; selected : bool; pos : float * float }

let init _runtime _env (init : init) =
  let x, y = init.center in
  {
    init;
    selected = false;
    pos = (x -. (init.width /. 2.) +. (init.value *. init.width), y);
  }

let update runtime env evnt data =
  match evnt with
  | Regl_proto.MouseUp _ -> ({ data with selected = false }, [], (env, false))
  | MouseDown _ ->
      if
        Camera.judge_mouse_circle
          ~mouse:(Base.get_mouse_pos runtime)
          ~center:data.pos ~radius:15.
      then ({ data with selected = true }, [], (env, true))
      else (data, [], (env, false))
  | _ when data.selected ->
      let posx, _ = Base.get_mouse_pos runtime in
      let cx, cy = data.init.center in
      let left = cx -. (data.init.width /. 2.) in
      let right = cx +. (data.init.width /. 2.) in
      let x = max left (min right posx) in
      let progress =
        if data.init.width = 0. then 0. else (x -. left) /. data.init.width
      in
      ( { data with pos = (x, cy) },
        [ Component.Parent (Changed progress) ],
        (env, false) )
  | _ -> (data, [], (env, false))

let updaterec _runtime env _msg data = (data, [], env)

let view _runtime _env data =
  ( Regl_common.group []
      [
        Regl_builtin_programs.rect_centered data.init.center
          (data.init.width, 15.) 0. (Color.rgb 0.5 0.5 0.5);
        Regl_builtin_programs.circle data.pos 15. Color.black;
      ],
    0 )

let component =
  {
    Component.init;
    update;
    updaterec;
    view;
    matcher = (fun _data target -> String.equal target "Slider");
  }
