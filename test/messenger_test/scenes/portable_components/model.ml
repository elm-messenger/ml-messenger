open Ml_regl_core
open Messenger
module Component_base = Mgl.Base.Components.Portable_components.Component_base
open Component_base

type scene_common_data = unit

type component =
  ( scene_common_data,
    Lib.User_data.user_data,
    string,
    component_msg,
    unit,
    Mgl.Base.scene_msg )
  Component.abstract_component

type data = { components : component list; last_panel_count : int }

let init runtime env _msg =
  let env = Base.add_common_data () env in
  {
    components =
      [
        Components.Panel.Model.component (PanelMsg Panel_msg.Init) runtime env;
        Badge_component.component ~matcher:(String.equal "badge")
          ~map_target:Fun.id (Pcomp.Badge.Model.Init "portable badge") runtime
          env;
      ];
    last_panel_count = 0;
  }

let handle_component_msg data env = function
  | General_model.SOMMsg som -> (data, [ som ], env)
  | OtherMsg (PanelMsg (Panel_msg.PortableUpdated count)) ->
      ({ data with last_panel_count = count }, [], env)
  | _ -> (data, [], env)

let handle_component_msgs data env msgs =
  List.fold_left
    (fun (data, soms, env) msg ->
      let data, new_soms, env = handle_component_msg data env msg in
      (data, soms @ new_soms, env))
    (data, [], env) msgs

let update runtime env evnt data =
  match evnt with
  | Regl_proto.KeyDown "Backspace" ->
      (data, [ Scene.SOMChangeScene (None, "Home") ], env)
  | KeyDown "Enter" ->
      let env = Base.add_common_data () env in
      let components, msgs, env =
        Component.update_components_with_target runtime env
          [ ("panel", PanelMsg Panel_msg.PingPortable) ]
          data.components
      in
      let data, soms, env =
        handle_component_msgs { data with components } env msgs
      in
      (data, soms, Base.remove_common_data env)
  | _ ->
      let env = Base.add_common_data () env in
      let components, msgs, (env, _block) =
        Component.update_components runtime env evnt data.components
      in
      let data, soms, env =
        handle_component_msgs { data with components } env msgs
      in
      (data, soms, Base.remove_common_data env)

let view runtime env data =
  let env = Base.add_common_data () env in
  Regl_common.group []
    [
      Regl_builtin_programs.clear Color.white;
      Regl_builtin_programs.textbox (0., 30.) 24.
        "Portable components: Space/Enter updates badge, F flashes, Backspace \
         home"
        "firacode" Color.black;
      Regl_builtin_programs.textbox (0., 65.) 20.
        ("Last panel count: " ^ string_of_int data.last_panel_count)
        "firacode" Color.black;
      Component.view_components runtime env data.components;
    ]

let scenecon : (_, _, _, _, _, _, _) Scene.concrete_scene =
  { init; update; view }

let scene _msg runtime env = Scene.abstract scenecon None runtime env
