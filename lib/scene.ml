open Ml_regl_core

type ('data, 'envro, 'env, 'event, 'ren, 'scenemsg, 'userdata) concrete_scene = {
  init : 'envro -> 'env -> 'scenemsg option -> 'data;
  update :
    'envro ->
    'env ->
    'event ->
    'data ->
    'data * ('scenemsg, 'userdata) scene_output_msg list * 'env;
  view : 'envro -> 'env -> 'data -> 'ren;
}

and ('envro, 'env, 'event, 'ren, 'scenemsg, 'userdata) abstract_scene =
  | Roll of
      ('envro, 'env, 'event, 'ren, 'scenemsg, 'userdata) unrolled_abstract_scene

and ('envro, 'env, 'event, 'ren, 'scenemsg, 'userdata) unrolled_abstract_scene = {
  update :
    'envro ->
    'env ->
    'event ->
    ('envro, 'env, 'event, 'ren, 'scenemsg, 'userdata) abstract_scene
    * ('scenemsg, 'userdata) scene_output_msg list
    * 'env;
  view : 'envro -> 'env -> 'ren;
}

and ('scenemsg, 'userdata) scene_output_msg =
  | SOMChangeScene of 'scenemsg option * string
  | SOMPlayAudio of int * string * Audio_base.audio_option
  | SOMStopAudio of Audio_base.audio_target
  | SOMTransformAudio of
      Audio_base.audio_target * (Regl_audio.audio -> Regl_audio.audio)
  | SOMSetVolume of float
  | SOMLoadGC of ('userdata, 'scenemsg) global_component_storage
  | SOMUnloadGC of gc_target
  | SOMCallGC of gc_target * gc_msg
  | SOMChangeFPS of Regl_proto.time_interval
  | SOMChangeMaxAssetsPerFrame of int
  | SOMLoadResource of string * Resources.resource_def
  | SOMSaveValue of string * string
  | SOMReadValue of string

and ('userdata, 'scenemsg) scene_storage =
  'scenemsg option ->
  Internal.runtime ->
  (unit, 'userdata) Base.env ->
  ('userdata, 'scenemsg) m_abstract_scene

and ('userdata, 'scenemsg) all_scenes =
  (string, ('userdata, 'scenemsg) scene_storage) Hashtbl.t

and ('tar, 'msg, 'scenemsg, 'userdata) m_msg =
  ('tar, 'msg, ('scenemsg, 'userdata) scene_output_msg) General_model.msg

and ('msg, 'scenemsg, 'userdata) m_msg_base =
  ('msg, ('scenemsg, 'userdata) scene_output_msg) General_model.msg_base

and ('data,
      'common,
      'userdata,
      'tar,
      'msg,
      'bdata,
      'scenemsg)
    m_concrete_general_model =
  ( 'data,
    Internal.runtime,
    ('common, 'userdata) Base.env,
    Regl_proto.regl_event,
    'tar,
    'msg,
    Regl_common.renderable,
    'bdata,
    ('scenemsg, 'userdata) scene_output_msg )
  General_model.concrete_general_model

and ('common, 'userdata, 'tar, 'msg, 'bdata, 'scenemsg) m_abstract_general_model =
  ( Internal.runtime,
    ('common, 'userdata) Base.env,
    Regl_proto.regl_event,
    'tar,
    'msg,
    Regl_common.renderable,
    'bdata,
    ('scenemsg, 'userdata) scene_output_msg )
  General_model.abstract_general_model

and ('userdata, 'scenemsg) m_concrete_scene_data = unit

and ('userdata, 'scenemsg) m_abstract_scene =
  ( Internal.runtime,
    (unit, 'userdata) Base.env,
    Regl_proto.regl_event,
    Regl_common.renderable,
    'scenemsg,
    'userdata )
  abstract_scene

and gc_common_data = unit

and gc_base_data = {
  dead : bool;
  post_processor : Regl_common.renderable -> Regl_common.renderable;
}

and gc_msg = string
and gc_target = string

and ('userdata, 'scenemsg) abstract_global_component =
  ( ('userdata, 'scenemsg) m_abstract_scene,
    'userdata,
    gc_target,
    gc_msg,
    gc_base_data,
    'scenemsg )
  m_abstract_general_model

and ('userdata, 'scenemsg) global_component_storage =
  Internal.runtime ->
  (('userdata, 'scenemsg) m_abstract_scene, 'userdata) Base.env ->
  ('userdata, 'scenemsg) abstract_global_component

and ('data, 'userdata, 'scenemsg) concrete_global_component = {
  init :
    Internal.runtime ->
    (('userdata, 'scenemsg) m_abstract_scene, 'userdata) Base.env ->
    gc_msg ->
    'data * gc_base_data;
  update :
    Internal.runtime ->
    (('userdata, 'scenemsg) m_abstract_scene, 'userdata) Base.env ->
    Regl_proto.regl_event ->
    'data ->
    gc_base_data ->
    ('data * gc_base_data)
    * (gc_target, gc_msg, 'scenemsg, 'userdata) m_msg list
    * ((('userdata, 'scenemsg) m_abstract_scene, 'userdata) Base.env * bool);
  updaterec :
    Internal.runtime ->
    (('userdata, 'scenemsg) m_abstract_scene, 'userdata) Base.env ->
    gc_msg ->
    'data ->
    gc_base_data ->
    ('data * gc_base_data)
    * (gc_target, gc_msg, 'scenemsg, 'userdata) m_msg list
    * (('userdata, 'scenemsg) m_abstract_scene, 'userdata) Base.env;
  view :
    Internal.runtime ->
    (('userdata, 'scenemsg) m_abstract_scene, 'userdata) Base.env ->
    'data ->
    gc_base_data ->
    Regl_common.renderable;
  id : gc_target;
}

let unroll (Roll un) = un

let abstract (type data envro env event ren scenemsg userdata)
    (conmodel :
      (data, envro, env, event, ren, scenemsg, userdata) concrete_scene)
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

let empty_scene () : ('userdata, 'scenemsg) m_abstract_scene =
  let rec scene =
    Roll
      {
        update = (fun _ env _ -> (scene, [], env));
        view = (fun _ _ -> Ml_regl_core.Regl_common.group [] []);
      }
  in
  scene
