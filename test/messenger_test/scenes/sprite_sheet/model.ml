open Ml_regl_core
open Messenger

type data = unit

let scene_con : (_, _, _, _, _, _, _) Scene.concrete_scene =
  {
    init = (fun _ _ _ -> ());
    update = (fun _ env evnt () -> match evnt with Regl_proto.KeyDown "Backspace" -> ((), [ Scene.SOMChangeScene (None, "Home") ], env) | _ -> ((), [], env));
    view =
      (fun runtime _env () ->
        let frame = Base.get_scene_start_frame runtime / 8 in
        let row_sizes = [| 13; 8; 10; 10; 10; 6; 4; 7 |] in
        let row = frame mod Array.length row_sizes in
        let col = frame mod row_sizes.(row) in
        let name = Printf.sprintf "char%d%d" row col in
        Regl_common.group []
          [ Regl_builtin_programs.clear Color.white;
            Regl_builtin_programs.textbox (20., 20.) 28. ("SpriteSheet: " ^ name ^ " (Backspace home)") "firacode" Color.black;
            Regl_builtin_programs.centered_texture (500., 400.) (256., 256.) 0. name ]);
  }

let scene _msg runtime env = Scene.abstract scene_con None runtime env
