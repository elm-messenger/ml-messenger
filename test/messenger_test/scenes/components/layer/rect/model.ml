open Ml_regl_core
open Messenger

type msg = Paint of Color.t | Clicked of int

type init = {
  left : float;
  top : float;
  width : float;
  height : float;
  id : int;
  color : Color.t;
}

type data = init

let init _runtime _env (init : init) : data = init

let update runtime env evnt (data : data) =
  match evnt with
  | Regl_proto.MouseDown { button = 1; x; y }
    when Camera.judge_mouse_rect_with_camera
           ~view_size:(Base.get_virtual_size runtime)
           ~camera:env.Base.global_data.camera ~mouse:(x, y)
           ~pos:(data.left, data.top) ~size:(data.width, data.height) ->
      ( { data with color = Color.black },
        [
          (* the next rect is the same kind, so it gets the rect's own msg *)
          Component.Other (data.id + 1, Paint Color.green);
          Component.Parent (Clicked data.id);
        ],
        (env, true) )
  | _ -> (data, [], (env, false))

let updaterec _runtime env msg (data : data) =
  match msg with
  | Paint color -> ({ data with color }, [], env)
  | Clicked _ -> (data, [], env)

let view _runtime _env (data : data) =
  ( Regl_builtin_programs.rect (data.left, data.top) (data.width, data.height)
      data.color,
    0 )

let component =
  {
    Component.init;
    update;
    updaterec;
    view;
    targets = (fun (data : data) -> [ data.id ]);
  }
