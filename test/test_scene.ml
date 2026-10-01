(* Scene registration and scene changes by name and by typed key. *)

open Ml_regl_core
open Messenger

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i =
    i + m <= n && (String.equal (String.sub s i m) sub || go (i + 1))
  in
  go 0

(* A scene that only draws the label its [init] computed from its param. *)
let labelled (label : 'param option -> string) msg runtime env =
  let scene : (_, _, _, _, _, 'param, unit) Scene.concrete_scene =
    {
      init = (fun _ _ param -> label param);
      update = (fun _ env _ data -> (data, [], env));
      view =
        (fun _ _ data ->
          Regl_builtin_programs.textbox (0., 0.) 10. data "font" Color.black);
    }
  in
  Scene.abstract scene msg runtime env

let level_key : int Scene.key = Scene.key "Level"

let level =
  labelled (function
    | Some n -> "level " ^ string_of_int n
    | None -> "level without params")

let home = labelled (fun (_ : unit option) -> "home")

let scenes =
  Scene.table [ Scene.named "Home" home; Scene.entry level_key level ]

let runtime = Internal.empty_runtime ()

let start : unit Model.t =
  {
    runtime;
    env =
      {
        global_data = { user_data = (); camera = Camera.origin };
        common_data = Scene.empty_scene ();
      };
    global_components = [];
  }

let draws (model : unit Model.t) text =
  let scene = Scene.unroll model.env.common_data in
  let frame = scene.view runtime (Base.remove_common_data model.env) in
  contains (Bytes.to_string (Regl_common.encode_frame_pb frame)) text

let go target model = Loader.load_target target scenes model

let () =
  prerr_endline "test_scene: the next three errors are expected";
  let model = go (By_name "Home") start in
  assert (Base.get_current_scene runtime = "Home" && draws model "home");
  let model = go (By_key (level_key, 3)) model in
  assert (Base.get_current_scene runtime = "Level" && draws model "level 3");
  let model = go (By_name "Level") model in
  assert (draws model "level without params");
  (* Another key with the same name has its own identity, so its parameters are
     rejected and the current scene stays. *)
  let model = go (By_name "Home") model in
  let other_key : int Scene.key = Scene.key "Level" in
  let model = go (By_key (other_key, 5)) model in
  assert (Base.get_current_scene runtime = "Home" && draws model "home");
  let model = go (By_name "Nope") model in
  assert (Base.get_current_scene runtime = "Home" && draws model "home")

let () =
  let tbl = Scene.table [ Scene.named "A" home; Scene.named "A" home ] in
  assert (Hashtbl.length tbl = 1)
