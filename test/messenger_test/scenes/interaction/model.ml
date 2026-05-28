open Ml_regl_core
open Messenger
module CB = Components.Component_base

type component =
  ( Scene_base.scene_common_data,
    Lib.User_data.user_data,
    CB.component_target,
    CB.component_msg,
    CB.base_data,
    Lib.Base.scene_msg )
  Component.abstract_component

type data = {
  components : component list;
  button_status : string;
  slider_value : float;
}

let init runtime env _msg =
  let button_init =
    {
      CB.button_center = (200., 200.);
      button_size = (100., 50.);
      button_color = Color.green;
      button_content = "NICE";
    }
  in
  let slider_init =
    {
      CB.slider_init_value = 0.5;
      slider_center = (200., 300.);
      slider_width = 300.;
    }
  in
  {
    components =
      [
        Components.Button.Model.component (CB.ButtonInitMsg button_init) runtime
          env;
        Components.Slider.Model.component (CB.SliderInitMsg slider_init) runtime
          env;
      ];
    button_status = "IDLE";
    slider_value = 0.5;
  }

let handle_component_msg data env = function
  | General_model.SOMMsg som -> (data, [ som ], env)
  | OtherMsg (CB.ButtonUpdateMsg CB.ButtonPressed) ->
      ({ data with button_status = "PRESSED" }, [], env)
  | OtherMsg (CB.ButtonUpdateMsg CB.ButtonReleased) ->
      ({ data with button_status = "IDLE" }, [], env)
  | OtherMsg (CB.SliderUpdateMsg value) ->
      ({ data with slider_value = value }, [], env)
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
      ( data,
        [
          Messenger_extra.Transition_model.gen_mixed_transition_som
            (Messenger_extra.Transition_transitions.fade_mix, 1000.)
            ("Home", None);
        ],
        env )
  | _ ->
      let comps1, msgs1, (env1, _block) =
        Component.update_components runtime env evnt data.components
      in
      let data1, sommsgs, env2 =
        handle_component_msgs { data with components = comps1 } env1 msgs1
      in
      (data1, sommsgs, env2)

let view runtime env data =
  Regl_common.group []
    [
      Regl_builtin_programs.clear Color.white;
      Component.view_components runtime env data.components;
      Regl_builtin_programs.textbox (0., 50.) 20.
        ("Button Status: " ^ data.button_status)
        "firacode" Color.black;
      Regl_builtin_programs.textbox (0., 80.) 20.
        (Printf.sprintf "Slider Value: %.3f" data.slider_value)
        "firacode" Color.black;
    ]

let scenecon : (_, _, _, _, _, _, _) Scene.concrete_scene =
  { init; update; view }

let scene _msg runtime env = Scene.abstract scenecon None runtime env
