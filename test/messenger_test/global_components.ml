let all_global_components : (Lib.User_data.user_data, Lib.Base.scene_msg) Messenger.Scene.global_component_storage list =
  [ Messenger_extra.Fps.gen_gc { font_size = 20.; font = "firacode" } None;
    Messenger_extra.Asset_loading.gen_gc None ]
