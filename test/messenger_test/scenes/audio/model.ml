open Ml_regl_core
open Messenger

type data = unit

let scene_con : (_, _, _, _, _, _, _) Scene.concrete_scene =
  {
    init = (fun _ _ _ -> ());
    update =
      (fun _runtime env evnt () ->
        let soms =
          match evnt with
          | Regl_proto.KeyDown "Backspace" ->
              [ Scene.SOMChangeScene (None, "Home") ]
          | KeyDown ("Space" | "Enter") ->
              [ Scene.SOMPlayAudio (0, "test", Audio_base.A_once None) ]
          | KeyDown "S" -> [ Scene.SOMStopAudio Audio_base.All_audio ]
          | _ -> []
        in
        ((), soms, env));
    view =
      (fun _runtime _env () ->
        Regl_common.group []
          [
            Regl_builtin_programs.clear Color.white;
            Regl_builtin_programs.textbox (20., 20.) 28.
              "Audio: Space/Enter play, S stop, Backspace home" "firacode"
              Color.black;
          ]);
  }

let scene _msg runtime env = Scene.abstract scene_con None runtime env
