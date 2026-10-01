open Ml_regl_core
open Messenger
module Button = Components.Button.Model
module Slider = Components.Slider.Model

(* The union of this scene's children, owned by the scene. *)
type msg = Button of Button.msg | Slider of Slider.msg

let button =
  Component.port
    (fun msg -> Button msg)
    (function Button msg -> Some msg | _ -> None)

let slider =
  Component.port
    (fun msg -> Slider msg)
    (function Slider msg -> Some msg | _ -> None)

type component = (unit, Lib.User_data.user_data, string, msg, unit) Component.t

type data = {
  components : component list;
  button_status : string;
  slider_value : float;
}

let init runtime env _msg =
  {
    components =
      [
        Component.make button Button.component
          {
            Button.center = (200., 200.);
            size = (100., 50.);
            color = Color.green;
            content = "NICE";
          }
          runtime env;
        Component.make slider Slider.component
          { Slider.value = 0.5; center = (200., 300.); width = 300. }
          runtime env;
      ];
    button_status = "IDLE";
    slider_value = 0.5;
  }

let handle data = function
  | Button Pressed -> { data with button_status = "PRESSED" }
  | Button Released -> { data with button_status = "IDLE" }
  | Slider (Changed value) -> { data with slider_value = value }

let update runtime env evnt data =
  match evnt with
  | Regl_proto.KeyDown "Backspace" ->
      ( data,
        [
          Messenger_extra.Transition_model.gen_mixed_transition_som
            (Messenger_extra.Transition_transitions.fade_mix, 1000.)
            (Scene.By_name "Home");
        ],
        env )
  | _ ->
      let components, msgs, soms, (env, _block) =
        Component.update_children runtime env evnt data.components
      in
      (List.fold_left handle { data with components } msgs, soms, env)

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

let scene msg runtime env = Scene.abstract scenecon msg runtime env
