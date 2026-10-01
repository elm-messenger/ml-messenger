let all_global_components () =
  [
    Messenger_extra.Fps.gen_gc { font_size = 20.; font = "firacode" };
    Messenger_extra.Asset_loading.gen_gc ();
  ]
