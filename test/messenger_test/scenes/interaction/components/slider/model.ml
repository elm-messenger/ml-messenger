open Ml_regl_core
open Messenger
open Component_base

type data = {
  init_data : slider_init_data;
  selected : bool;
  pos : float * float;
}

let fallback_init =
  { slider_init_value = 0.; slider_center = (0., 0.); slider_width = 0. }

let init _runtime _env = function
  | SliderInitMsg msg ->
      let x, y = msg.slider_center in
      ( {
          init_data = msg;
          selected = false;
          pos =
            ( x -. (msg.slider_width /. 2.)
              +. (msg.slider_init_value *. msg.slider_width),
              y );
        },
        () )
  | _ -> ({ init_data = fallback_init; selected = false; pos = (0., 0.) }, ())

let update runtime env evnt data basedata =
  match evnt with
  | Regl_proto.MouseUp _ ->
      (({ data with selected = false }, basedata), [], (env, false))
  | MouseDown _ ->
      if
        Camera.judge_mouse_circle
          ~mouse:(Base.get_mouse_pos runtime)
          ~center:data.pos ~radius:15.
      then (({ data with selected = true }, basedata), [], (env, true))
      else ((data, basedata), [], (env, false))
  | _ ->
      if data.selected then
        let posx, _ = Base.get_mouse_pos runtime in
        let cx, cy = data.init_data.slider_center in
        let left = cx -. (data.init_data.slider_width /. 2.) in
        let right = cx +. (data.init_data.slider_width /. 2.) in
        let newposx = max left (min right posx) in
        let progress =
          if data.init_data.slider_width = 0. then 0.
          else (newposx -. left) /. data.init_data.slider_width
        in
        ( ({ data with pos = (newposx, cy) }, basedata),
          [ General_model.Parent (OtherMsg (SliderUpdateMsg progress)) ],
          (env, false) )
      else ((data, basedata), [], (env, false))

let updaterec _runtime env _msg data basedata = ((data, basedata), [], env)

let view _runtime _env data _basedata =
  ( Regl_common.group []
      [
        Regl_builtin_programs.rect_centered data.init_data.slider_center
          (data.init_data.slider_width, 15.)
          0. (Color.rgb 0.5 0.5 0.5);
        Regl_builtin_programs.circle data.pos 15. Color.black;
      ],
    0 )

let matcher _data _basedata target = target = "Slider"

let componentcon : (_, _, _, _, _, _, _) Component.concrete_user_component =
  { init; update; updaterec; view; matcher }

let component msg runtime env =
  Component.gen_component componentcon msg runtime env
