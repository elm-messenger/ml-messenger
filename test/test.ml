open Ml_regl_core
open Messenger

type user_data = unit
type scene_msg = unit

let scene_con : (_, _, _, _, _, _, _) Scene.concrete_scene =
  {
    init = (fun _ _ _ -> ());
    update =
      (fun _ env evnt () ->
        let soms =
          match evnt with
          | Regl_proto.KeyDown "Space" -> [ Scene.SOMSaveValue ("ml-messenger-demo", "space") ]
          | _ -> []
        in
        ((), soms, env));
    view = (fun _ _ () -> Regl_common.group [] []);
  }

let scene_storage _ runtime env = Scene.abstract scene_con None runtime env

let scenes : (user_data, scene_msg) Scene.all_scenes =
  let tbl = Hashtbl.create 1 in
  Hashtbl.add tbl "main" scene_storage;
  tbl

let input : (user_data, scene_msg) Ui.input =
  {
    config =
      {
        init_scene = "main";
        init_scene_msg = None;
        virtual_size = { Ui.width = 800.; height = 600. };
        fbo_num = 1;
        enabled_program = Ui.NoBuiltinProgram;
        time_interval = Regl_proto.AnimationFrame;
        default_global_data = { Base.user_data = (); camera = Camera.default; volume = 1. };
        debug = false;
      };
    resources = [];
    scenes;
    global_components = [];
  }

let () = Ui.gen_main input
