open Messenger

let input : (Lib.User_data.user_data, Lib.Base.scene_msg) Ui.input =
  {
    config =
      {
        init_scene = Main_config.init_scene;
        init_scene_msg = Main_config.init_scene_msg;
        virtual_size = Main_config.virtual_size;
        fbo_num = Main_config.fbo_num;
        enabled_program = Main_config.enabled_builtin_programs;
        time_interval = Main_config.time_interval;
        default_global_data = Main_config.default_global_data;
        debug = Main_config.debug;
      };
    resources = Lib.Resources.resources;
    scenes = Scenes.All_scenes.all_scenes;
    global_components = Global_components.all_global_components;
  }

let () = Ui.gen_main input

