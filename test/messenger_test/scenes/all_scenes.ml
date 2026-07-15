type user_data = Lib.User_data.user_data
type scene_msg = Lib.Base.scene_msg

let all_scenes : (user_data, scene_msg) Messenger.Scene.all_scenes =
  let tbl = Hashtbl.create 16 in
  List.iter
    (fun (name, scene) -> Hashtbl.add tbl name scene)
    [
      ("Home", Home.Model.scene);
      ("Camera", Camera.Model.scene);
      ("Stress", Stress.Model.scene);
      ("SpriteSheet", Sprite_sheet.Model.scene);
      ("ConfigData", Config_data.Model.scene);
      ("Audio", Audio.Model.scene);
      ("Interaction", Interaction.Model.scene);
      ("Transition", Transition.Model.scene);
      ("Components", Components.Model.scene);
      ("PortableComponents", Portable_components.Model.scene);
    ];
  tbl
