open Ml_regl_core
open Messenger

type data = unit

let scene_con : (_, _, _, _, _, _, _) Scene.concrete_scene =
  {
    init = (fun _ _ _ -> ());
    update =
      (fun _runtime env evnt () ->
        match evnt with
        | Regl_proto.KeyDown "Backspace" -> ((), [ Scene.SOMChangeScene (None, "Home") ], env)
        | KeyDown "ArrowLeft" ->
            let cam = env.Base.global_data.camera in
            let env = { env with global_data = { env.global_data with camera = { cam with x = cam.x -. 30. } } } in
            ((), [], env)
        | KeyDown "ArrowRight" ->
            let cam = env.global_data.camera in
            let env = { env with global_data = { env.global_data with camera = { cam with x = cam.x +. 30. } } } in
            ((), [], env)
        | KeyDown "ArrowUp" ->
            let cam = env.global_data.camera in
            let env = { env with global_data = { env.global_data with camera = { cam with y = cam.y -. 30. } } } in
            ((), [], env)
        | KeyDown "ArrowDown" ->
            let cam = env.global_data.camera in
            let env = { env with global_data = { env.global_data with camera = { cam with y = cam.y +. 30. } } } in
            ((), [], env)
        | KeyDown "Equal" ->
            let cam = env.global_data.camera in
            let env = { env with global_data = { env.global_data with camera = { cam with zoom = cam.zoom *. 1.1 } } } in
            ((), [], env)
        | KeyDown "Minus" ->
            let cam = env.global_data.camera in
            let env = { env with global_data = { env.global_data with camera = { cam with zoom = cam.zoom /. 1.1 } } } in
            ((), [], env)
        | _ -> ((), [], env));
    view =
      (fun _runtime _env () ->
        Regl_common.group []
          [ Regl_builtin_programs.clear Color.white;
            Regl_builtin_programs.textbox (0., 0.) 24. "Camera: arrows move, +/- zoom, Backspace home" "firacode" Color.black;
            Regl_builtin_programs.rect (200., 200.) (200., 120.) (Color.rgb 0.2 0.6 1.);
            Regl_builtin_programs.circle (700., 500.) 80. Color.red ]);
  }

let scene _msg runtime env = Scene.abstract scene_con None runtime env

