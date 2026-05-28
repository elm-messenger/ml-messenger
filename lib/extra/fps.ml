open Ml_regl_core
open Messenger

type init_option = { font_size : float; font : string }

type data = {
  last_times : float list;
  fps : float;
  size : float;
  font : string;
}

let trim_to_last_ten xs =
  if List.length xs >= 10 then match xs with _ :: tl -> tl | [] -> [] else xs

let init opt _runtime _env _msg =
  ( { last_times = []; fps = 0.; size = opt.font_size; font = opt.font },
    { Scene.dead = false; post_processor = Fun.id } )

let update _runtime env evnt data bdata =
  match evnt with
  | Regl_proto.UpdateTick _ ->
      let delta = Base.get_delta_time _runtime in
      let last_times = trim_to_last_ten data.last_times @ [ delta ] in
      let sum = List.fold_left ( +. ) 0. last_times in
      let fps =
        if sum <= 0. then 0.
        else float_of_int (List.length last_times) /. sum *. 1000.
      in
      (({ data with last_times; fps }, bdata), [], (env, false))
  | _ -> ((data, bdata), [], (env, false))

let updaterec _runtime env _msg data bdata = ((data, bdata), [], env)

let view _runtime _env data _bdata =
  Regl_builtin_programs.textbox (0., 0.) data.size
    ("FPS: " ^ string_of_int (int_of_float data.fps))
    data.font (Color.rgba 0. 0. 0. 0.5)

let gc_con opt () : (_, _, _) Scene.concrete_global_component =
  { init = init opt; update; updaterec; view; id = "fps" }

let gen_gc opt target =
  Global_component.gen_global_component (gc_con opt ()) "" target
