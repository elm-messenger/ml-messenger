open Ml_regl_core
open Messenger

type ('userdata, 'msg, 'data) portable_component_init = Internal.runtime -> (unit, 'userdata) Base.env -> 'msg -> 'data

type ('data, 'userdata, 'tar, 'msg, 'scenemsg) portable_component_update =
  Internal.runtime ->
  (unit, 'userdata) Base.env ->
  Regl_proto.regl_event ->
  'data ->
  'data * ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * ((unit, 'userdata) Base.env * bool)

type ('data, 'userdata, 'tar, 'msg, 'scenemsg) portable_component_updaterec =
  Internal.runtime ->
  (unit, 'userdata) Base.env ->
  'msg ->
  'data ->
  'data * ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * (unit, 'userdata) Base.env

type ('userdata, 'data) portable_component_view = Internal.runtime -> (unit, 'userdata) Base.env -> 'data -> Regl_common.renderable

type ('data, 'userdata, 'tar, 'msg, 'scenemsg) concrete_portable_component = {
  init : ('userdata, 'msg, 'data) portable_component_init;
  update : ('data, 'userdata, 'tar, 'msg, 'scenemsg) portable_component_update;
  updaterec : ('data, 'userdata, 'tar, 'msg, 'scenemsg) portable_component_updaterec;
  view : ('userdata, 'data) portable_component_view;
  matcher : 'data -> 'tar -> bool;
}

type ('specificmsg, 'generalmsg) portable_msg_codec = {
  encode : 'generalmsg -> 'specificmsg;
  decode : 'specificmsg -> 'generalmsg;
}

type ('specifictar, 'generaltar) portable_tar_codec = {
  encode : 'generaltar -> 'specifictar;
  decode : 'specifictar -> 'generaltar;
}

type ('cdata, 'userdata, 'gtar, 'gmsg, 'bdata, 'scenemsg) portable_component_storage =
  'gmsg -> Internal.runtime -> ('cdata, 'userdata) Base.env -> ('cdata, 'userdata, 'gtar, 'gmsg, 'bdata, 'scenemsg) Component.abstract_component

let decode_msg msgcodec tarcodec = function
  | General_model.Parent (OtherMsg othermsg) -> General_model.Parent (OtherMsg (msgcodec.decode othermsg))
  | Parent (SOMMsg som) -> Parent (SOMMsg som)
  | Other (target, msg) -> Other (tarcodec.decode target, msgcodec.decode msg)

let translate_portable_component pcomp tarcodec msgcodec empty_base_data zindex =
  let init runtime env gmsg = (pcomp.init runtime (Base.remove_common_data env) (msgcodec.encode gmsg), empty_base_data) in
  let update runtime env evt data base_data =
    let res_data, res_msg, (res_env, res_block) = pcomp.update runtime (Base.remove_common_data env) evt data in
    ((res_data, base_data), List.map (decode_msg msgcodec tarcodec) res_msg, (Base.add_common_data env.common_data res_env, res_block))
  in
  let updaterec runtime env gmsg data base_data =
    let res_data, res_msg, res_env = pcomp.updaterec runtime (Base.remove_common_data env) (msgcodec.encode gmsg) data in
    ((res_data, base_data), List.map (decode_msg msgcodec tarcodec) res_msg, Base.add_common_data env.common_data res_env)
  in
  let view runtime env data _ = (pcomp.view runtime (Base.remove_common_data env) data, zindex) in
  let matcher data _ target = pcomp.matcher data (tarcodec.encode target) in
  { General_model.init; update; updaterec; view; matcher }

let gen_portable_component conpcomp tcodec mcodec empty_base_data zindex =
  Component.gen_component (translate_portable_component conpcomp tcodec mcodec empty_base_data zindex)

