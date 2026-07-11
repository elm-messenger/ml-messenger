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
  max_assets_per_frame : int;
  enabled_program : enabled_builtin_program;
  time_interval : Regl_proto.time_interval;
  default_global_data : 'userdata Base.global_data_init;
  app_name : string option;
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
  }

let load_initial_scene_and_gcs input model =
  let model =
    Loader.load_scene_by_name input.config.init_scene input.scenes
      input.config.init_scene_msg model
  in
  let env_for_gc = model.env in
  let gcs =
    List.map (fun gc -> gc model.runtime env_for_gc) input.global_components
  in
  { model with global_components = gcs }

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
      app_name = input.config.app_name;
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
    :: Regl_proto.config_regl
         (ConfigMaxAssetsPerFrame input.config.max_assets_per_frame)
    :: resource_cmds
  in
  (load_initial_scene_and_gcs input model, outputs)

let post_process x xs = List.fold_left (fun acc f -> f acc) x xs

let view input model =
  ignore input;
  let env = model.Model.env in
  let runtime = model.Model.runtime in
  let global_components = model.Model.global_components in
  let scene_view =
    (Scene.unroll env.common_data).view runtime (Base.remove_common_data env)
  in
  let gc_view = General_model.view_model_list runtime env global_components in
  let scene_with_camera =
    Camera.apply env.global_data.camera
      (post_process scene_view (Global_component.combine_pp global_components))
  in
  Regl_common.group [] (scene_with_camera :: gc_view)

let handle_regl_recv input model msg =
  let r = model.Model.runtime in
  (match msg with
  | Regl_proto.REGLTextureLoaded t ->
      Resources.save_sprite r.sprites t.name t;
      r.loaded_res_num <- r.loaded_res_num + 1
  | REGLTextureLoadFail _ -> ()
  | REGLFontLoaded name ->
      r.fonts <- Internal.StringSet.add name r.fonts;
      r.loaded_res_num <- r.loaded_res_num + 1
  | REGLFontLoadFail _ -> ()
  | REGLProgramCreated name ->
      r.programs <- Internal.StringSet.add name r.programs;
      r.loaded_res_num <- r.loaded_res_num + 1
  | REGLProgramCreateFail _ -> ()
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
  | REGLFileLoadFailed _ -> ()
  | REGLValueRead { key; value } -> Hashtbl.replace r.local_values key value
  | REGLValueReadMissing key -> Hashtbl.remove r.local_values key);
  ignore input;
  (model, [])

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
  | AudioLoadFailed _ -> ()
  | AudioContextReady _ -> ());
  ignore input;
  (model, [])

let rec handle_som input som model =
  let r = model.Model.runtime in
  match som with
  | Scene.SOMChangeScene (msg, name) ->
      (Loader.load_scene_by_name name input.scenes msg model, [])
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
  | SOMChangeMaxAssetsPerFrame max_items ->
      ( model,
        [ Regl_proto.config_regl (ConfigMaxAssetsPerFrame max_items) ] )
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
  let runtime = model.Model.runtime in
  let env = model.Model.env in
  let global_components = model.Model.global_components in
  let gc1 = Global_component.filter_alive_gc global_components in
  let gc2, gcsompre, (env2, block) =
    Recursion.update_objects runtime env evnt gc1
  in
  let gcsom = General_model.filter_som gcsompre in
  let model1 = { model with env = env2; global_components = gc2 } in
  let scenesom, model2 =
    if block then ([], model1)
    else
      let scene, psom, env =
        (Scene.unroll env2.common_data).update runtime
          (Base.remove_common_data env2)
          evnt
      in
      (psom, { model1 with env = Base.add_common_data scene env })
  in
  let model3 = model2 in
  handle_soms input (gcsom @ scenesom) model3

let update_input_state (r : Internal.runtime) = function
  | Regl_proto.UpdateTick ts -> r.current_timestamp <- ts
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
