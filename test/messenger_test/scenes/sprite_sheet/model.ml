open Ml_regl_core
open Messenger

type data = { frame : int }

let scene_con : (_, _, _, _, _, _, _) Scene.concrete_scene =
  {
    init = (fun _ _ _ -> { frame = 0 });
    update =
      (fun _ env evnt data ->
        match evnt with
        | Regl_proto.KeyDown "Backspace" ->
            (data, [ Scene.SOMChangeScene (None, "Home") ], env)
        | Regl_proto.UpdateTick _ -> ({ frame = data.frame + 1 }, [], env)
        | _ -> (data, [], env));
    view =
      (fun runtime _env data ->
        let frame = data.frame / 8 in
        let row_sizes = [| 13; 8; 10; 10; 10; 6; 4; 7 |] in
        let sprites =
          row_sizes |> Array.to_list
          |> List.mapi (fun row row_size ->
              let y = 90. +. (float_of_int row *. 115.) in
              let col = (frame + (row * 2)) mod row_size in
              let name = Printf.sprintf "char%d%d" row col in
              Regl_common.group []
                [
                  Regl_builtin_programs.textbox
                    (20., y +. 22.)
                    18.
                    (Printf.sprintf "row %d: %s" row name)
                    "firacode" Color.black;
                  Messenger.Render_texture.render_sprite runtime (150., y)
                    (64., 64.) name;
                ])
        in
        Regl_common.group []
          (Regl_builtin_programs.clear Color.white
          :: Regl_builtin_programs.textbox (20., 20.) 28.
               "SpriteSheet: one animated sprite per row (Backspace home)"
               "firacode" Color.black
          :: sprites));
  }

let scene _msg runtime env = Scene.abstract scene_con None runtime env
