open Ml_regl_core
open Messenger

type data = unit

let scene_con : (_, _, _, _, _, _, _) Scene.concrete_scene =
  {
    init = (fun _ _ _ -> ());
    update =
      (fun _ env evnt () ->
        match evnt with
        | Regl_proto.KeyDown "Backspace" ->
            ((), [ Scene.SOMChangeScene (None, "Home") ], env)
        | _ -> ((), [], env));
    view =
      (fun runtime _env () ->
        let text =
          Option.value
            (Base.get_config_data "texts" runtime)
            ~default:"<missing config data>"
        in
        Regl_common.group []
          [
            Regl_builtin_programs.clear Color.white;
            Regl_builtin_programs.textbox (20., 20.) 28.
              "ConfigData (Backspace home)" "firacode" Color.black;
            Regl_builtin_programs.textbox (20., 80.) 24. text "firacode"
              (Color.rgb 0.1 0.2 0.6);
          ]);
  }

let scene _msg runtime env = Scene.abstract scene_con None runtime env
