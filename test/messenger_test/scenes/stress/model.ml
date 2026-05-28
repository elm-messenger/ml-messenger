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
        let frame = float_of_int (Base.get_scene_start_frame runtime) in
        let sprites =
          List.init 50 (fun i ->
              List.init 25 (fun j ->
                  let x =
                    (float_of_int i *. 40.)
                    +. (sin ((frame *. 0.03) +. float_of_int j) *. 10.)
                  in
                  let y = float_of_int j *. 40. in
                  Regl_builtin_programs.centered_texture (x, y) (24., 24.) 0.
                    "ship"))
          |> List.flatten
        in
        Regl_common.group [] (Regl_builtin_programs.clear Color.white :: sprites));
  }

let scene _msg runtime env = Scene.abstract scene_con None runtime env
