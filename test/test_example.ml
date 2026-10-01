(* Drives scenes of the example application without [Ui] (which would link the
   backend) and checks what they draw. *)

open Ml_regl_core
open Messenger
module App = Messenger_test

let runtime = Internal.empty_runtime ()
let () = runtime.virtual_size <- (1920., 1080.)

let env : (unit, App.Lib.User_data.user_data) Base.env =
  {
    global_data =
      {
        user_data = App.Lib.User_data.default;
        camera = Camera.default ~width:1920. ~height:1080.;
      };
    common_data = ();
  }

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i =
    i + m <= n && (String.equal (String.sub s i m) sub || go (i + 1))
  in
  go 0

(* Text in a textbox is carried verbatim in the encoded frame. *)
let draws scene text =
  let frame = (Scene.unroll scene).view runtime env in
  contains (Bytes.to_string (Regl_common.encode_frame_pb frame)) text

(* Records the mouse position the way [Ui.update_input_state] does. *)
let step scene evnt =
  (match evnt with
  | Regl_proto.MouseMove { x; y } | MouseDown { x; y; _ } | MouseUp { x; y; _ }
    ->
      runtime.mouse_pos <- (x, y)
  | _ -> ());
  let scene, _soms, _env = (Scene.unroll scene).update runtime env evnt in
  scene

let steps scene evnts = List.fold_left step scene evnts

let () =
  let scene = App.Scenes.Interaction.Model.scene None runtime env in
  assert (draws scene "Button Status: IDLE");
  assert (not (draws scene "Button Status: PRESSED"));
  let scene =
    steps scene
      [
        MouseMove { x = 200.; y = 200. };
        MouseDown { button = 1; x = 200.; y = 200. };
      ]
  in
  assert (draws scene "Button Status: PRESSED");
  let scene = steps scene [ MouseUp { button = 1; x = 200.; y = 200. } ] in
  assert (draws scene "Button Status: IDLE");
  let scene =
    steps scene
      [
        MouseMove { x = 200.; y = 300. };
        MouseDown { button = 1; x = 200.; y = 300. };
        MouseMove { x = 275.; y = 300. };
      ]
  in
  assert (draws scene "Slider Value: 0.750")

let () =
  let scene = App.Scenes.Components.Model.scene None runtime env in
  assert (draws scene "Last clicked rect: none");
  let scene = steps scene [ MouseDown { button = 1; x = 160.; y = 160. } ] in
  assert (draws scene "Last clicked rect: 0");
  (* Four rects overlap here; layer B and its last rect are updated first. *)
  let scene = steps scene [ MouseDown { button = 1; x = 390.; y = 390. } ] in
  assert (draws scene "Last clicked rect: 3")

let () =
  let scene = App.Scenes.Portable_components.Model.scene None runtime env in
  assert (draws scene "portable badge");
  let scene = steps scene [ KeyDown "Space" ] in
  assert (draws scene "panel ping 1");
  assert (not (draws scene "portable badge"));
  assert (draws scene "Last panel count: 1");
  let scene = steps scene [ KeyDown "Return" ] in
  assert (draws scene "scene ping 2")
