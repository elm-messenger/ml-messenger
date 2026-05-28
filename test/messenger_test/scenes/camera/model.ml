open Ml_regl_core
open Messenger

type data = unit

let move_camera env dx dy =
  let cam = env.Base.global_data.camera in
  {
    env with
    global_data =
      {
        env.global_data with
        camera = { cam with x = cam.x +. dx; y = cam.y +. dy };
      };
  }

let zoom_camera env k =
  let cam = env.Base.global_data.camera in
  {
    env with
    global_data =
      { env.global_data with camera = { cam with zoom = cam.zoom *. k } };
  }

let scene_con : (_, _, _, _, _, _, _) Scene.concrete_scene =
  {
    init = (fun _ _ _ -> ());
    update =
      (fun _runtime env evnt () ->
        match evnt with
        | Regl_proto.KeyDown "Backspace" ->
            ((), [ Scene.SOMChangeScene (None, "Home") ], env)
        | KeyDown ("Left" | "A") -> ((), [], move_camera env (-100.) 0.)
        | KeyDown ("Right" | "D") -> ((), [], move_camera env 100. 0.)
        | KeyDown ("Up" | "W") -> ((), [], move_camera env 0. (-100.))
        | KeyDown ("Down" | "S") -> ((), [], move_camera env 0. 100.)
        | KeyDown "=" -> ((), [], zoom_camera env 1.25)
        | KeyDown "-" -> ((), [], zoom_camera env 0.8)
        | KeyDown "R" ->
            ( (),
              [],
              {
                env with
                global_data =
                  {
                    env.global_data with
                    camera = Messenger.Camera.default ~width:1920. ~height:1080.;
                  };
              } )
        | _ -> ((), [], env));
    view =
      (fun _runtime env () ->
        let cam = env.Base.global_data.camera in
        Regl_common.group []
          [
            Regl_builtin_programs.clear Color.white;
            Regl_builtin_programs.textbox (20., 20.) 24.
              (Printf.sprintf
                 "Camera: arrows/WASD move, +/- zoom, R reset, Backspace home\n\
                  cam=(%.0f, %.0f), zoom=%.2f"
                 cam.x cam.y cam.zoom)
              "firacode" Color.black;
            Regl_builtin_programs.lines
              [ ((0., 540.), (1920., 540.)); ((960., 0.), (960., 1080.)) ]
              (Color.rgb 0.7 0.7 0.7);
            Regl_builtin_programs.rect (200., 200.) (200., 120.)
              (Color.rgb 0.2 0.6 1.);
            Regl_builtin_programs.rect (1000., 500.) (260., 180.)
              (Color.rgb 0.2 0.8 0.3);
            Regl_builtin_programs.circle (700., 500.) 80. Color.red;
            Messenger.Render_texture.render_sprite _runtime (1300., 300.)
              (0., 180.) "ship";
          ]);
  }

let scene _msg runtime env = Scene.abstract scene_con None runtime env
