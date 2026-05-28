open Ml_regl_core
open Messenger

type data = unit

let comment =
  "Mode:\n\
   1: Fading, mixed\n\
   2: Fade out black + Fade in black, sequential\n\
   3: null + Fade in with Renderable, sequential\n\
   4: Clock, mixed\n\
   5: Clock x 2, sequential\n\
   Backspace: Home"

let view runtime _env () =
  Regl_common.group []
    [
      Regl_builtin_programs.clear (Color.rgb 0.55 0.9 0.55);
      Regl_builtin_programs.textbox (0., 30.) 40. comment "firacode" Color.black;
      Regl_builtin_programs.textbox (0., 900.) 30.
        (string_of_int (Base.get_scene_start_frame runtime))
        "firacode" Color.black;
    ]

let update runtime env evnt () =
  let open Messenger_extra in
  let to_home = ("Home", None) in
  let soms =
    match evnt with
    | Regl_proto.KeyDown "Backspace" | KeyDown ("Digit1" | "1") ->
        [
          Transition_model.gen_mixed_transition_som
            (Transition_transitions.fade_mix, 1000.)
            to_home;
        ]
    | KeyDown ("Digit2" | "2") ->
        [
          Transition_model.gen_sequential_transition_som
            (Transition_transitions.fade_out, 1000.)
            (Transition_transitions.fade_in, 1000.)
            to_home;
        ]
    | KeyDown ("Digit3" | "3") ->
        let current_view = view runtime env () in
        [
          Transition_model.gen_sequential_transition_som
            (Transition_base.null_transition, 0.)
            (Transition_transitions.fade_in_with_renderable current_view, 1000.)
            to_home;
        ]
    | KeyDown ("Digit4" | "4") ->
        [
          Transition_model.gen_mixed_transition_som
            (Transition_transitions.fade_img_mix "mask" false, 1000.)
            to_home;
        ]
    | KeyDown ("Digit5" | "5") ->
        [
          Transition_model.gen_sequential_transition_som
            (Transition_transitions.fade_out_img "mask" false, 1000.)
            (Transition_transitions.fade_in_img "mask" true, 1000.)
            to_home;
        ]
    | _ -> []
  in
  ((), soms, env)

let init _runtime _env _msg = ()

let scenecon : (_, _, _, _, _, _, _) Scene.concrete_scene =
  { init; update; view }

let scene _msg runtime env = Scene.abstract scenecon None runtime env
