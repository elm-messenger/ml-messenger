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
          | Regl_proto.KeyDown "Space" ->
              [ Scene.SOMSaveValue ("ml-messenger-demo", "space") ]
          | _ -> []
        in
        ((), soms, env));
    view =
      (fun runtime _ () ->
        let mouse = Base.get_mouse_pos runtime in
        let inside =
          Camera.judge_mouse_rect ~mouse ~pos:(260., 220.) ~size:(280., 160.)
        in
        let color =
          if inside then Color.rgb 0.2 0.8 0.35 else Color.rgb 0.25 0.45 0.9
        in
        Regl_common.group []
          [
            Regl_builtin_programs.clear Color.white;
            Regl_builtin_programs.rect (260., 220.) (280., 160.) color;
            Regl_builtin_programs.circle (400., 300.) 48. Color.red;
          ]);
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
        fbo_num = 5;
        max_assets_per_frame = 4;
        enabled_program = Ui.AllBuiltinProgram;
        time_interval = Regl_proto.AnimationFrame;
        default_global_data =
          {
            Base.user_data = ();
            camera = Camera.default ~width:800. ~height:600.;
            volume = 1.;
          };
        app_name = None;
      };
    resources = [];
    scenes;
    global_components = [];
  }

let () = Ui.gen_main input
