(* Drives [Ui.init] and [Ui.update] directly. This links the desktop backend but
   never calls [Ui.gen_main], so no window opens. *)

open Ml_regl_core
open Messenger
module T = Messenger_extra.Transition_model
module TB = Messenger_extra.Transition_base

(* How many times scene "A" was updated, to spot duplicate updates. *)
let a_updates = ref 0

(* A global component that records the messages it is called with. *)
type probe_msg = Ping of string

let probe_key : probe_msg Global_component.key = Global_component.key "probe"

(* Same name, different identity and message type. *)
let impostor_key : int Global_component.key = Global_component.key "probe"
let nobody_key : unit Global_component.key = Global_component.key "nobody"

let probe : (int, probe_msg, unit) Scene.concrete_global_component =
  {
    init = (fun _ _ -> (0, { Scene.dead = false; post_processor = Fun.id }));
    update = (fun _ env _ n bdata -> ((n, bdata), [], (env, false)));
    updaterec =
      (fun _ env (Ping text) n bdata ->
        ( (n + 1, bdata),
          [ Scene.SOMSaveValue ("probe", text ^ string_of_int (n + 1)) ],
          env ));
    view = (fun _ _ _ _ -> Regl_builtin_programs.empty);
    key = probe_key;
  }

let scene name msg runtime env =
  let con : (_, _, _, _, _, _, _) Scene.concrete_scene =
    {
      init = (fun _ _ _ -> ());
      update =
        (fun _ env evnt () ->
          if String.equal name "A" then incr a_updates;
          let soms =
            match evnt with
            | Regl_proto.KeyDown "T" ->
                [
                  T.gen_sequential_transition_som
                    (TB.null_transition, 1000.)
                    (TB.null_transition, 1000.)
                    (By_name "B");
                ]
            | KeyDown "C" -> [ Scene.SOMChangeScene (By_name "C") ]
            | KeyDown "L" -> [ Scene.SOMLoadGC (Global_component.make probe) ]
            | KeyDown "P" ->
                [
                  Scene.SOMCallGC (probe_key, Ping "ping");
                  SOMCallGC (impostor_key, 7);
                  SOMCallGC (nobody_key, ());
                ]
            | KeyDown "U" -> [ Scene.SOMUnloadGC probe_key ]
            | KeyDown "R" -> [ Scene.SOMReadValue "best"; SOMReadValue "none" ]
            | ValueRead { key; value } ->
                [
                  Scene.SOMSaveValue
                    ("seen:" ^ key, Option.value value ~default:"<missing>");
                ]
            | _ -> []
          in
          ((), soms, env));
      view = (fun _ _ () -> Regl_builtin_programs.empty);
    }
  in
  Scene.abstract con msg runtime env

let input : unit Ui.input =
  {
    config =
      {
        init_scene = By_name "A";
        virtual_size = { Ui.width = 800.; height = 600. };
        fbo_num = 5;
        max_assets_per_frame = 4;
        enabled_program = Ui.AllBuiltinProgram;
        time_interval = Regl_proto.AnimationFrame;
        default_global_data =
          { Base.user_data = (); camera = Camera.origin; volume = 1. };
        app_name = None;
        init_window = Regl_proto.default_window_config;
      };
    resources =
      [
        ("a", Resources.Audio_res "x.ogg");
        ("b", Audio_res "x.ogg");
        ("d1", Data_res "f.json");
        ("d2", Data_res "f.json");
        ("e", Data_res "g.json");
      ];
    scenes =
      Scene.table
        [
          Scene.named "A" (scene "A");
          Scene.named "B" (scene "B");
          Scene.named "C" (scene "C");
        ];
    global_components = [];
  }

let count cmd outputs = List.length (List.filter (( = ) cmd) outputs)
let step m input_msg = Ui.update input m input_msg

let event m evnt =
  let m, _, _ = step m (Regl_proto.Event evnt) in
  m

let recv m msg =
  let m, _, _ = step m (Regl_proto.REGLRecvMsg msg) in
  m

let progress m = Base.get_loading_progress m.Model.runtime
let scene_name m = Base.get_current_scene m.Model.runtime
let gcs m = List.length m.Model.global_components

(* Keys sharing an audio URL or a data path: one request, every key registered,
   a duplicate reply ignored, a failed path loadable again. *)
let () =
  let m, outputs = Ui.init input () in
  assert (count (Regl_proto.load_audio "x.ogg") outputs = 1);
  assert (count (Regl_proto.load_file "f.json") outputs = 1);
  assert (count (Regl_proto.load_file "g.json") outputs = 1);
  let m, outputs =
    Ui.handle_som input (SOMLoadResource ("d3", Data_res "f.json")) m
  in
  assert (outputs = []);
  let audio = { Regl_audio.buffer_id = 0; duration = 1. } in
  let m, _, _ =
    step m
      (Regl_proto.AudioMsg
         (AudioLoadSuccess { audio_url = "x.ogg"; source = audio }))
  in
  assert (Hashtbl.mem m.runtime.audio_repo.audio "a");
  assert (Hashtbl.mem m.runtime.audio_repo.audio "b");
  assert (progress m = (2, 6));
  let m = recv m (REGLFileLoaded { path = "f.json"; data = "F" }) in
  assert (
    List.for_all
      (fun key -> Base.get_config_data key m.runtime = Some "F")
      [ "d1"; "d2"; "d3" ]);
  assert (progress m = (5, 6));
  let m = recv m (REGLFileLoaded { path = "f.json"; data = "again" }) in
  assert (progress m = (5, 6));
  assert (Base.get_config_data "f.json" m.runtime = None);
  let m = recv m (REGLFileLoadFailed { path = "g.json"; reason = "404" }) in
  assert (progress m = (5, 6));
  let _, outputs =
    Ui.handle_som input (SOMLoadResource ("e", Data_res "g.json")) m
  in
  assert (count (Regl_proto.load_file "g.json") outputs = 1)

(* A program resource is created in the shader language it names. *)
let () =
  let m, _ = Ui.init input () in
  let program : Regl_program.regl_program =
    {
      frag = "";
      vert = "";
      attributes = None;
      uniforms = None;
      elements = None;
      primitive = None;
      count = None;
    }
  in
  List.iter
    (fun shader_language ->
      let _, outputs =
        Ui.handle_som input
          (SOMLoadResource ("p", Program_res (program, shader_language)))
          m
      in
      assert (
        outputs
        = [ Regl_proto.create_regl_program ~shader_language "p" program ]))
    [ Regl_proto.Glsl; GlslEs100 ];
  assert (
    Regl_proto.create_regl_program ~shader_language:Glsl "p" program
    <> Regl_proto.create_regl_program ~shader_language:GlslEs100 "p" program)

(* The current scene is recorded only once a scene is actually loaded. *)
let () =
  prerr_endline "test_ui: the next error is expected";
  let config = { input.config with init_scene = By_name "Nope" } in
  let m, _ = Ui.init { input with config } () in
  assert (scene_name m = "")

(* Transitions and global components through [Ui]. *)
let () =
  prerr_endline "test_ui: the next two errors are expected";
  let m, _ = Ui.init input () in
  assert (scene_name m = "A");
  let m = event m (KeyDown "T") in
  assert (gcs m = 1);
  (* A sequential transition does not keep (and update) a copy of the old scene,
     so the old scene is updated once per event. *)
  let before = !a_updates in
  let m = event m (KeyDown "x") in
  assert (!a_updates - before = 1);
  (* [filter_som]: the old scene cannot start another scene change. *)
  let m = event m (KeyDown "C") in
  assert (scene_name m = "A");
  let m = event m (UpdateTick 0.) in
  let m = event m (UpdateTick 1500.) in
  assert (scene_name m = "B");
  let m = event m (UpdateTick 3000.) in
  assert (gcs m = 0);
  let m = event m (KeyDown "C") in
  assert (scene_name m = "C");
  let m = event m (KeyDown "L") in
  assert (gcs m = 1);
  let m = event m (KeyDown "P") in
  assert (Base.get_local_value "probe" m.runtime = Some "ping1");
  let m = event m (KeyDown "P") in
  assert (Base.get_local_value "probe" m.runtime = Some "ping2");
  let m = event m (KeyDown "U") in
  assert (gcs m = 0)

(* The clock can jump backwards (the MCP server's controlled clock starts at 0);
   a transition ignores the jump instead of stalling until time catches up. *)
let () =
  let m, _ = Ui.init input () in
  let m = event m (KeyDown "T") in
  let m = event m (UpdateTick 70000.) in
  let m = event m (UpdateTick 0.) in
  let m = event m (UpdateTick 1500.) in
  assert (scene_name m = "B")

(* A storage read goes out as a command; the reply reaches the scene as a
   [ValueRead] event, and [Base.get_local_value] caches it. *)
let () =
  let m, _ = Ui.init input () in
  let m, _, outputs = step m (Regl_proto.Event (KeyDown "R")) in
  assert (count (Regl_proto.read_value "best") outputs = 1);
  let m = event m (ValueRead { key = "best"; value = Some "42" }) in
  assert (Base.get_local_value "best" m.runtime = Some "42");
  assert (Base.get_local_value "seen:best" m.runtime = Some "42");
  let m = event m (ValueRead { key = "none"; value = None }) in
  assert (Base.get_local_value "none" m.runtime = None);
  assert (Base.get_local_value "seen:none" m.runtime = Some "<missing>")
