open Ml_regl_core
open Messenger

type init_option = unit
type data = { elapsed : float; prev_ts : float option }

let init () _runtime _env _msg =
  ( { elapsed = 0.; prev_ts = None },
    { Scene.dead = false; post_processor = Fun.id } )

let update runtime env evnt data bdata =
  let loaded, total = Base.get_loading_progress runtime in
  let data =
    match evnt with
    | Regl_proto.UpdateTick ts ->
        let delta = match data.prev_ts with None -> 0. | Some p -> ts -. p in
        { elapsed = data.elapsed +. delta; prev_ts = Some ts }
    | _ -> data
  in
  ((data, { bdata with Scene.dead = loaded >= total }), [], (env, false))

let updaterec _runtime env _msg data bdata = ((data, bdata), [], env)

let view _runtime env data _bdata =
  let virtual_height =
    env.Base.global_data.camera.Ml_regl_core.Regl_common.y *. 2.
  in
  let spinner =
    List.init 8 (fun i ->
        let fi = float_of_int i in
        let x = 15. *. cos (Float.pi /. 4. *. fi) in
        let y = 15. *. sin (Float.pi /. 4. *. fi) in
        let radius =
          2.
          +. sin
               ((data.elapsed *. 0.005) +. (2. *. Float.pi *. fi /. 8.))
        in
        Regl_builtin_programs.circle
          (30. +. x, virtual_height -. 30. +. y)
          radius Color.white)
  in
  Regl_common.group [] (Regl_builtin_programs.clear Color.black :: spinner)

let gc_con () : (_, _, _) Scene.concrete_global_component =
  { init = init (); update; updaterec; view; id = "assetloading" }

let gen_gc target = Global_component.gen_global_component (gc_con ()) "" target
