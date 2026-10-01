open Ml_regl_core

type 'param key = { name : string; id : 'param Type.Id.t }
(** Names a scene and the type of the parameters it can be started with. Put a
    key that other scenes use in a plain module (e.g. [game_params.ml]) so that
    scenes can refer to each other without a dependency cycle. *)

let key name = { name; id = Type.Id.make () }

(** Where a scene change goes: a scene by name (its [init] gets [None]), or a
    scene by key with typed parameters (its [init] gets [Some param]). *)
type target = By_name of string | By_key : 'param key * 'param -> target

let target_name = function By_name name -> name | By_key (key, _) -> key.name

type ('data, 'envro, 'env, 'event, 'ren, 'param, 'userdata) concrete_scene = {
  init : 'envro -> 'env -> 'param option -> 'data;
  update :
    'envro ->
    'env ->
    'event ->
    'data ->
    'data * 'userdata scene_output_msg list * 'env;
  view : 'envro -> 'env -> 'data -> 'ren;
}

and ('envro, 'env, 'event, 'ren, 'userdata) abstract_scene =
  | Roll of ('envro, 'env, 'event, 'ren, 'userdata) unrolled_abstract_scene

and ('envro, 'env, 'event, 'ren, 'userdata) unrolled_abstract_scene = {
  update :
    'envro ->
    'env ->
    'event ->
    ('envro, 'env, 'event, 'ren, 'userdata) abstract_scene
    * 'userdata scene_output_msg list
    * 'env;
  view : 'envro -> 'env -> 'ren;
}

and 'userdata scene_output_msg =
  | SOMChangeScene of target
  | SOMPlayAudio of int * string * Audio_base.audio_option
  | SOMStopAudio of Audio_base.audio_target
  | SOMTransformAudio of
      Audio_base.audio_target * (Regl_audio.audio -> Regl_audio.audio)
  | SOMSetVolume of float
  | SOMLoadGC of 'userdata global_component_storage
  | SOMUnloadGC of gc_target
  | SOMCallGC of gc_target * gc_msg
  | SOMChangeFPS of Regl_proto.time_interval
  | SOMChangeMaxAssetsPerFrame of int
  | SOMLoadResource of string * Resources.resource_def
  | SOMSaveValue of string * string
  | SOMReadValue of string

and ('userdata, 'param) scene_storage =
  'param option ->
  Internal.runtime ->
  (unit, 'userdata) Base.env ->
  'userdata m_abstract_scene

and ('tar, 'msg, 'userdata) m_msg =
  ('tar, 'msg, 'userdata scene_output_msg) General_model.msg

and ('msg, 'userdata) m_msg_base =
  ('msg, 'userdata scene_output_msg) General_model.msg_base

and ('data, 'common, 'userdata, 'tar, 'msg, 'bdata) m_concrete_general_model =
  ( 'data,
    Internal.runtime,
    ('common, 'userdata) Base.env,
    Regl_proto.regl_event,
    'tar,
    'msg,
    Regl_common.renderable,
    'bdata,
    'userdata scene_output_msg )
  General_model.concrete_general_model

and ('common, 'userdata, 'tar, 'msg, 'bdata) m_abstract_general_model =
  ( Internal.runtime,
    ('common, 'userdata) Base.env,
    Regl_proto.regl_event,
    'tar,
    'msg,
    Regl_common.renderable,
    'bdata,
    'userdata scene_output_msg )
  General_model.abstract_general_model

and 'userdata m_abstract_scene =
  ( Internal.runtime,
    (unit, 'userdata) Base.env,
    Regl_proto.regl_event,
    Regl_common.renderable,
    'userdata )
  abstract_scene

and gc_common_data = unit

and gc_base_data = {
  dead : bool;
  post_processor : Regl_common.renderable -> Regl_common.renderable;
}

and gc_msg = string
and gc_target = string

and 'userdata abstract_global_component =
  ( 'userdata m_abstract_scene,
    'userdata,
    gc_target,
    gc_msg,
    gc_base_data )
  m_abstract_general_model

and 'userdata global_component_storage =
  Internal.runtime ->
  ('userdata m_abstract_scene, 'userdata) Base.env ->
  'userdata abstract_global_component

and ('data, 'userdata) concrete_global_component = {
  init :
    Internal.runtime ->
    ('userdata m_abstract_scene, 'userdata) Base.env ->
    gc_msg ->
    'data * gc_base_data;
  update :
    Internal.runtime ->
    ('userdata m_abstract_scene, 'userdata) Base.env ->
    Regl_proto.regl_event ->
    'data ->
    gc_base_data ->
    ('data * gc_base_data)
    * (gc_target, gc_msg, 'userdata) m_msg list
    * (('userdata m_abstract_scene, 'userdata) Base.env * bool);
  updaterec :
    Internal.runtime ->
    ('userdata m_abstract_scene, 'userdata) Base.env ->
    gc_msg ->
    'data ->
    gc_base_data ->
    ('data * gc_base_data)
    * (gc_target, gc_msg, 'userdata) m_msg list
    * ('userdata m_abstract_scene, 'userdata) Base.env;
  view :
    Internal.runtime ->
    ('userdata m_abstract_scene, 'userdata) Base.env ->
    'data ->
    gc_base_data ->
    Regl_common.renderable;
  id : gc_target;
}

(** A registered scene: its key and how to start it. *)
type 'userdata entry =
  | Entry : 'param key * ('userdata, 'param) scene_storage -> 'userdata entry

type 'userdata all_scenes = (string, 'userdata entry) Hashtbl.t

(** Register a scene that other scenes start with [By_key key param]. *)
let entry key storage = Entry (key, storage)

(** Register a scene that takes no parameters; start it with [By_name name]. *)
let named name (storage : ('userdata, unit) scene_storage) =
  Entry (key name, storage)

(** Build the scene table. A name registered twice keeps the last entry and
    reports an error. *)
let table entries : 'userdata all_scenes =
  let tbl = Hashtbl.create 16 in
  List.iter
    (fun (Entry (key, _) as entry) ->
      if Hashtbl.mem tbl key.name then
        Printf.eprintf "ml-messenger: scene %S is registered twice\n%!" key.name;
      Hashtbl.replace tbl key.name entry)
    entries;
  tbl

let unroll (Roll un) = un

let abstract (type data envro env event ren param userdata)
    (conmodel : (data, envro, env, event, ren, param, userdata) concrete_scene)
    init_msg init_envro init_env =
  let rec abstract_rec data =
    let update envro env event =
      let new_d, new_m, new_e = conmodel.update envro env event data in
      (abstract_rec new_d, new_m, new_e)
    in
    Roll { update; view = (fun envro env -> conmodel.view envro env data) }
  in
  abstract_rec (conmodel.init init_envro init_env init_msg)

let update_result_remap f model =
  let rec change m =
    let um = unroll m in
    let update envro env evnt =
      let oldr, oldmsg, oldres = um.update envro env evnt in
      let newmsg, newres = f (oldmsg, oldres) in
      (change oldr, newmsg, newres)
    in
    Roll { um with update }
  in
  change model

let empty_scene () : 'userdata m_abstract_scene =
  let rec scene =
    Roll
      {
        update = (fun _ env _ -> (scene, [], env));
        view = (fun _ _ -> Ml_regl_core.Regl_common.group [] []);
      }
  in
  scene
