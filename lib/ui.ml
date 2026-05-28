open Ml_regl_core

type enabled_builtin_program =
  | NoBuiltinProgram
  | CustomBuiltinProgramList of string list
  | TextOnlyBuiltinProgram
  | BasicShapesBuiltinProgram
  | AllBuiltinProgram

type size = { width : float; height : float }

type ('userdata, 'scenemsg) user_config = {
  init_scene : string;
  init_scene_msg : 'scenemsg option;
  virtual_size : size;
  fbo_num : int;
  enabled_program : enabled_builtin_program;
  time_interval : Regl_proto.time_interval;
  default_global_data : 'userdata Base.global_data_init;
  debug : bool;
}

type ('userdata, 'scenemsg) input = {
  config : ('userdata, 'scenemsg) user_config;
  resources : Resources.resource_defs;
  scenes : ('userdata, 'scenemsg) Scene.all_scenes;
  global_components : ('userdata, 'scenemsg) Scene.global_component_storage list;
}

let builtin_programs = function
  | CustomBuiltinProgramList xs -> Some xs
  | NoBuiltinProgram -> Some []
  | TextOnlyBuiltinProgram -> Some [ "textbox" ]
  | BasicShapesBuiltinProgram ->
      Some [ "textbox"; "triangle"; "circle"; "quad"; "poly" ]
  | AllBuiltinProgram -> None

let add_pending_data (runtime : Internal.runtime) path key =
  let old =
    Option.value
      (Hashtbl.find_opt runtime.Internal.pending_data_paths path)
      ~default:[]
  in
  Hashtbl.replace runtime.pending_data_paths path (key :: old)

let load_resource_command (runtime : Internal.runtime) key = function
  | Resources.Texture_res (url, opts) ->
      Some (Regl_proto.load_texture key url opts)
  | Audio_res url ->
      Hashtbl.replace runtime.pending_audio_urls url key;
      Some (Regl_proto.load_audio url)
  | Font_res (image, json) -> Some (Regl_proto.load_font key image json)
  | Program_res program -> Some (Regl_proto.create_regl_program key program)
  | Data_res path ->
      add_pending_data runtime path key;
      Some (Regl_proto.load_file path)

let make_initial_model input runtime =
  let global_data = Base.global_data_of_init input.config.default_global_data in
  {
    Model.runtime;
    env = { Base.global_data; common_data = Scene.empty_scene () };
    global_components = [];
    started = false;
  }

let maybe_start input model =
  if
    model.Model.started
    || model.runtime.loaded_res_num < model.runtime.tot_res_num
    || model.runtime.startup_failed <> []
  then model
  else
    let model =
      Loader.load_scene_by_name input.config.init_scene input.scenes
        input.config.init_scene_msg model
    in
    let env_for_gc = model.env in
    let gcs =
      List.map (fun gc -> gc model.runtime env_for_gc) input.global_components
    in
    { model with global_components = gcs; started = true }

let init input () =
  let runtime = Internal.empty_runtime () in
  runtime.volume <- input.config.default_global_data.volume;
  runtime.tot_res_num <- Resources.resource_num input.resources;
  runtime.current_scene <- input.config.init_scene;
  let model = make_initial_model input runtime in
  let start_config : Regl_proto.regl_start_config =
    {
      virt_width = input.config.virtual_size.width;
      virt_height = input.config.virtual_size.height;
      fbo_num = input.config.fbo_num;
      builtin_programs = builtin_programs input.config.enabled_program;
      window = Regl_proto.default_window_config;
    }
  in
  let resource_cmds =
    List.filter_map
      (fun (key, res) -> load_resource_command runtime key res)
      input.resources
  in
  let outputs =
    Regl_proto.start_regl start_config
    :: Regl_proto.config_regl (ConfigTimeInterval input.config.time_interval)
    :: resource_cmds
  in
  (maybe_start input model, outputs)

let post_process x xs = List.fold_left (fun acc f -> f acc) x xs

let view input model =
  ignore input;
  if not model.Model.started then Regl_common.group [] []
  else
    let scene_view =
      (Scene.unroll model.env.common_data).view model.runtime
        (Base.remove_common_data model.env)
    in
    let gc_view =
      General_model.view_model_list model.runtime model.env
        model.global_components
    in
    let scene_with_camera =
      Camera.apply model.env.global_data.camera
        (post_process scene_view
           (Global_component.combine_pp model.global_components))
    in
    Regl_common.group [] (scene_with_camera :: gc_view)

let handle_resource_loaded input model = maybe_start input model

let handle_regl_recv input model msg =
  let r = model.Model.runtime in
  (match msg with
  | Regl_proto.REGLTextureLoaded t ->
      Resources.save_sprite r.sprites t.name t;
      r.loaded_res_num <- r.loaded_res_num + 1
  | REGLTextureLoadFail name ->
      r.startup_failed <- ("texture:" ^ name) :: r.startup_failed
  | REGLFontLoaded name ->
      r.fonts <- Internal.StringSet.add name r.fonts;
      r.loaded_res_num <- r.loaded_res_num + 1
  | REGLFontLoadFail name ->
      r.startup_failed <- ("font:" ^ name) :: r.startup_failed
  | REGLProgramCreated name ->
      r.programs <- Internal.StringSet.add name r.programs;
      r.loaded_res_num <- r.loaded_res_num + 1
  | REGLProgramCreateFail name ->
      r.startup_failed <- ("program:" ^ name) :: r.startup_failed
  | REGLFileLoaded { path; data } ->
      let keys =
        Option.value
          (Hashtbl.find_opt r.pending_data_paths path)
          ~default:[ path ]
      in
      List.iter
        (fun key ->
          Hashtbl.replace r.config_data key data;
          r.loaded_res_num <- r.loaded_res_num + 1)
        keys;
      Hashtbl.remove r.pending_data_paths path
  | REGLFileLoadFailed { path; reason } ->
      r.startup_failed <- ("file:" ^ path ^ ":" ^ reason) :: r.startup_failed
  | REGLValueRead { key; value } -> Hashtbl.replace r.local_values key value
  | REGLValueReadMissing key -> Hashtbl.remove r.local_values key);
  (handle_resource_loaded input model, [])

let handle_audio_msg input model msg =
  let r = model.Model.runtime in
  (match msg with
  | Regl_proto.AudioLoadSuccess { audio_url; source } ->
      let key =
        Option.value
          (Hashtbl.find_opt r.pending_audio_urls audio_url)
          ~default:audio_url
      in
      Hashtbl.replace r.audio_repo.audio key source;
      r.loaded_res_num <- r.loaded_res_num + 1
  | AudioLoadFailed { audio_url; _ } ->
      r.startup_failed <- ("audio:" ^ audio_url) :: r.startup_failed
  | AudioContextReady _ -> ());
  (handle_resource_loaded input model, [])

let rec handle_som input som model =
  let r = model.Model.runtime in
  match som with
  | Scene.SOMChangeScene (msg, name) ->
      ( Loader.load_scene_by_name name input.scenes msg model
        |> Model.reset_scene_start_time,
        [] )
  | SOMPlayAudio (channel, name, opt) ->
      Audio.play_audio r.audio_repo channel name opt r.current_timestamp;
      (model, [])
  | SOMStopAudio target ->
      Audio.stop_audio r.audio_repo r.current_timestamp target;
      (model, [])
  | SOMTransformAudio (target, f) ->
      Audio.update_audio r.audio_repo target f;
      (model, [])
  | SOMSetVolume v ->
      r.volume <- v;
      (model, [])
  | SOMLoadGC gc ->
      ( {
          model with
          global_components = model.global_components @ [ gc r model.env ];
        },
        [] )
  | SOMUnloadGC target ->
      ( {
          model with
          global_components =
            Recursion.remove_objects target model.global_components;
        },
        [] )
  | SOMCallGC (tar, msg) ->
      let call = (tar, msg) in
      let gc1, som1, env1 =
        Recursion.update_objects_with_target r model.env [ call ]
          model.global_components
      in
      let model1 = { model with global_components = gc1; env = env1 } in
      handle_soms input (General_model.filter_som som1) model1
  | SOMChangeFPS fps ->
      (model, [ Regl_proto.config_regl (ConfigTimeInterval fps) ])
  | SOMLoadResource (key, res) ->
      r.tot_res_num <- r.tot_res_num + 1;
      let cmd = load_resource_command r key res in
      (model, Option.to_list cmd)
  | SOMSaveValue (key, value) ->
      Hashtbl.replace r.local_values key value;
      (model, [ Regl_proto.save_value key value ])
  | SOMReadValue key -> (model, [ Regl_proto.read_value key ])

and handle_soms input soms model =
  List.fold_left
    (fun (m, outs) som ->
      let nm, nouts = handle_som input som m in
      (nm, outs @ nouts))
    (model, []) soms

let game_update input evnt model =
  if not model.Model.started then (model, [])
  else
    let gc1 = Global_component.filter_alive_gc model.global_components in
    let gc2, gcsompre, (env2, block) =
      Recursion.update_objects model.runtime model.env evnt gc1
    in
    let gcsom = General_model.filter_som gcsompre in
    let model1 = { model with env = env2; global_components = gc2 } in
    let scenesom, model2 =
      if block then ([], model1)
      else
        let scene, psom, env =
          (Scene.unroll env2.common_data).update model.runtime
            (Base.remove_common_data env2)
            evnt
        in
        (psom, { model1 with env = Base.add_common_data scene env })
    in
    let model3 =
      match evnt with
      | Regl_proto.UpdateTick _ ->
          Model.update_scene_time model2 model.runtime.last_frame_delta
      | _ -> model2
    in
    handle_soms input (gcsom @ scenesom) model3

let update_input_state (r : Internal.runtime) = function
  | Regl_proto.UpdateTick ts ->
      let delta = ts -. r.current_timestamp in
      r.current_timestamp <- ts;
      r.last_frame_delta <- delta;
      r.global_start_frame <- r.global_start_frame + 1;
      r.global_start_time <- r.global_start_time +. delta
  | MouseDown { button; x; y } ->
      r.pressed_mouse_buttons <-
        Internal.IntSet.add button r.pressed_mouse_buttons;
      r.mouse_pos <- (x, y)
  | MouseUp { button; x; y } ->
      r.pressed_mouse_buttons <-
        Internal.IntSet.remove button r.pressed_mouse_buttons;
      r.mouse_pos <- (x, y)
  | MouseMove { x; y } -> r.mouse_pos <- (x, y)
  | KeyDown key -> r.pressed_keys <- Internal.StringSet.add key r.pressed_keys
  | KeyUp key -> r.pressed_keys <- Internal.StringSet.remove key r.pressed_keys

let update input model regl_input =
  let model, outputs =
    match regl_input with
    | Regl_proto.Event evnt ->
        update_input_state model.Model.runtime evnt;
        game_update input evnt model
    | REGLRecvMsg msg -> handle_regl_recv input model msg
    | AudioMsg msg -> handle_audio_msg input model msg
  in
  (model, Audio.audio_tree model.Model.runtime, outputs)

let gen_main input =
  Regl_backend.create_app (fun () -> init input ()) (update input) (view input)
