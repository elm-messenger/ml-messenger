open Ml_regl_core
open Messenger

type data = unit

let change name = [ Scene.SOMChangeScene (None, name) ]

let scene_con : (_, _, _, _, _, _, _) Scene.concrete_scene =
  {
    init = (fun _ _ _ -> ());
    update =
      (fun _runtime env evnt () ->
        let soms =
          match evnt with
          | Regl_proto.KeyDown ("Digit1" | "1") -> change "Camera"
          | KeyDown ("Digit2" | "2") -> change "Stress"
          | KeyDown ("Digit3" | "3") -> change "SpriteSheet"
          | KeyDown ("Digit4" | "4") -> change "ConfigData"
          | KeyDown ("Digit5" | "5") -> change "Audio"
          | KeyDown ("Digit6" | "6") -> change "Interaction"
          | KeyDown ("Digit7" | "7") -> change "Transition"
          | KeyDown ("Digit8" | "8") -> change "Components"
          | _ -> []
        in
        ((), soms, env));
    view =
      (fun _runtime _env () ->
        let prompt =
          "ml-messenger migration test\n\n1. Camera\n2. Stress\n3. SpriteSheet\n4. ConfigData\n5. Audio\n6. Interaction\n7. Transition\n8. Components\n\nBackspace returns home."
        in
        Regl_common.group []
          [ Regl_builtin_programs.clear (Color.rgb 1. 0.98 0.75);
            Regl_builtin_programs.textbox (0., 30.) 30. prompt "firacode" Color.black;
            Regl_builtin_programs.rect_texture (1200., 0.) (200., 200.) "ship" ]);
  }

let scene _msg runtime env = Scene.abstract scene_con None runtime env
