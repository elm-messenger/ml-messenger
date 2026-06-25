open Ml_regl_core
open Messenger

let init_scene = "Home"
let init_scene_msg = None
let virtual_size : Ui.size = { width = 1920.; height = 1080. }
let time_interval = Regl_proto.AnimationFrame
let fbo_num = 5
let enabled_builtin_programs = Ui.AllBuiltinProgram
let app_name = Some "Messenger Test"

let default_global_data : Lib.User_data.user_data Base.global_data_init =
  {
    user_data = Lib.User_data.default;
    camera =
      Camera.default ~width:virtual_size.width ~height:virtual_size.height;
    volume = 0.5;
  }
