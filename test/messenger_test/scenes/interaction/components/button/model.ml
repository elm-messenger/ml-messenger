open Ml_regl_core
open Messenger
open Component_base

type button_state = Normal | Hovered | Pressed

type data = { initdata : button_init_data; pos : float * float; cur_state : button_state }

let fallback_init = { button_center = (0., 0.); button_size = (0., 0.); button_color = Color.black; button_content = "" }

let init _runtime _env = function
  | ButtonInitMsg msg ->
      let x, y = msg.button_center in
      let w, h = msg.button_size in
      ({ initdata = msg; pos = (x -. (w /. 2.), y -. (h /. 2.)); cur_state = Normal }, ())
  | _ -> ({ initdata = fallback_init; pos = (0., 0.); cur_state = Normal }, ())

let update runtime env evnt data basedata =
  let is_hovered = Camera.judge_mouse_rect ~mouse:(Base.get_mouse_pos runtime) ~pos:data.pos ~size:data.initdata.button_size in
  let next_state =
    match (is_hovered, data.cur_state) with
    | true, Normal -> Hovered
    | false, Hovered -> Normal
    | _ -> data.cur_state
  in
  match evnt with
  | Regl_proto.MouseUp _ -> (({ data with cur_state = Normal }, basedata), [ General_model.Parent (OtherMsg (ButtonUpdateMsg ButtonReleased)) ], (env, false))
  | MouseDown _ ->
      if is_hovered then
        (({ data with cur_state = Pressed }, basedata), [ General_model.Parent (OtherMsg (ButtonUpdateMsg ButtonPressed)) ], (env, true))
      else ((data, basedata), [], (env, false))
  | _ -> (({ data with cur_state = next_state }, basedata), [], (env, false))

let updaterec _runtime env _msg data basedata = ((data, basedata), [], env)

let view _runtime _env data _basedata =
  let w, h = data.initdata.button_size in
  let rsize =
    match data.cur_state with
    | Normal -> data.initdata.button_size
    | Hovered -> (w +. 10., h +. 10.)
    | Pressed -> (max 0. (w -. 10.), max 0. (h -. 10.))
  in
  ( Regl_common.group []
      [ Regl_builtin_programs.rect_centered data.initdata.button_center rsize 0. data.initdata.button_color;
        Regl_builtin_programs.textbox_centered data.initdata.button_center 30. data.initdata.button_content "firacode" Color.black ],
    0 )

let matcher _data _basedata target = target = "Button"

let componentcon : (_, _, _, _, _, _, _) Component.concrete_user_component = { init; update; updaterec; view; matcher }
let component msg runtime env = Component.gen_component componentcon msg runtime env
