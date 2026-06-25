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
      (fun _runtime _env data ->
        let frame = float_of_int data.frame in
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
