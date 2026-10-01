(* The whole application, registered in plain OCaml. *)

open Messenger

type user_data = Lib.User_data.user_data

let virtual_size : Ui.size = { width = 1920.; height = 1080. }

let config : user_data Ui.user_config =
  {
    init_scene = By_name "Home";
    virtual_size;
    fbo_num = 5;
    max_assets_per_frame = 4;
    enabled_program = Ui.AllBuiltinProgram;
    time_interval = Ml_regl_core.Regl_proto.AnimationFrame;
    default_global_data =
      {
        user_data = Lib.User_data.default;
        camera =
          Camera.default ~width:virtual_size.width ~height:virtual_size.height;
        volume = 0.5;
      };
    app_name = Some "Messenger Test";
    init_window =
      {
        Ml_regl_core.Regl_proto.default_window_config with
        title = Some "Messenger Test";
      };
  }

(* None of these scenes takes parameters, so each is registered by name. A scene
   started with typed parameters is registered with [Scene.entry key]. *)
let scenes : user_data Scene.all_scenes =
  Scene.table
    [
      Scene.named "Audio" Scenes.Audio.Model.scene;
      Scene.named "Camera" Scenes.Camera.Model.scene;
      Scene.named "Components" Scenes.Components.Model.scene;
      Scene.named "ConfigData" Scenes.Config_data.Model.scene;
      Scene.named "Home" Scenes.Home.Model.scene;
      Scene.named "Interaction" Scenes.Interaction.Model.scene;
      Scene.named "PortableComponents" Scenes.Portable_components.Model.scene;
      Scene.named "SpriteSheet" Scenes.Sprite_sheet.Model.scene;
      Scene.named "Stress" Scenes.Stress.Model.scene;
      Scene.named "Transition" Scenes.Transition.Model.scene;
    ]

let input : user_data Ui.input =
  {
    config;
    resources = Lib.Resources.resources;
    scenes;
    global_components = Global_components.all_global_components ();
  }
