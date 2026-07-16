let all_global_components () =
  [
    Messenger_extra.Fps.gen_gc { font_size = 20.; font = "firacode" } None;
    Messenger_extra.Asset_loading.gen_gc None;
  ]
