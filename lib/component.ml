open Ml_regl_core

type ('data, 'cdata, 'userdata, 'tar, 'msg, 'bdata, 'scenemsg) concrete_user_component =
  ( 'data,
    Internal.runtime,
    ('cdata, 'userdata) Base.env,
    Regl_proto.regl_event,
    'tar,
    'msg,
    Regl_common.renderable * int,
    'bdata,
    ('scenemsg, 'userdata) Scene.scene_output_msg )
  General_model.concrete_general_model

type ('cdata, 'userdata, 'tar, 'msg, 'bdata, 'scenemsg) abstract_component =
  ( Internal.runtime,
    ('cdata, 'userdata) Base.env,
    Regl_proto.regl_event,
    'tar,
    'msg,
    Regl_common.renderable * int,
    'bdata,
    ('scenemsg, 'userdata) Scene.scene_output_msg )
  General_model.abstract_general_model

type ('cdata, 'userdata, 'msg, 'data, 'bdata) component_init = Internal.runtime -> ('cdata, 'userdata) Base.env -> 'msg -> 'data * 'bdata
type ('cdata, 'data, 'userdata, 'scenemsg, 'tar, 'msg, 'bdata) component_update = Internal.runtime -> ('cdata, 'userdata) Base.env -> Regl_proto.regl_event -> 'data -> 'bdata -> ('data * 'bdata) * ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * (('cdata, 'userdata) Base.env * bool)
type ('cdata, 'data, 'userdata, 'scenemsg, 'tar, 'msg, 'bdata) component_updaterec = Internal.runtime -> ('cdata, 'userdata) Base.env -> 'msg -> 'data -> 'bdata -> ('data * 'bdata) * ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * ('cdata, 'userdata) Base.env
type ('cdata, 'userdata, 'data, 'bdata) component_view = Internal.runtime -> ('cdata, 'userdata) Base.env -> 'data -> 'bdata -> Regl_common.renderable * int
type ('data, 'bdata, 'tar) component_matcher = 'data -> 'bdata -> 'tar -> bool
type ('cdata, 'userdata, 'tar, 'msg, 'bdata, 'scenemsg) level_component_storage = Internal.runtime -> ('cdata, 'userdata) Base.env -> ('cdata, 'userdata, 'tar, 'msg, 'bdata, 'scenemsg) abstract_component
type ('cdata, 'userdata, 'tar, 'msg, 'bdata, 'scenemsg) component_storage = 'msg -> ('cdata, 'userdata, 'tar, 'msg, 'bdata, 'scenemsg) level_component_storage

let gen_component concomp = General_model.abstract concomp

let update_components runtime env evt comps = Recursion.update_objects runtime env evt comps

let update_components_with_block runtime env evt block comps =
  if block then (comps, [], (env, true)) else update_components runtime env evt comps

let update_components_with_target runtime env msgs comps = Recursion.update_objects_with_target runtime env msgs comps

let gen_components_render_list runtime env compls = List.map (fun comp -> (General_model.unroll comp).view runtime env) compls

let view_components_render_list previews =
  previews |> List.sort (fun (_, a) (_, b) -> compare a b) |> List.map fst |> Regl_common.group []

let view_components runtime env compls = view_components_render_list (gen_components_render_list runtime env compls)

type ('cdata, 'data, 'userdata, 'scenemsg, 'tar, 'msg, 'bdata) update_middle_step =
  ('data * 'bdata) * ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * (('cdata, 'userdata) Base.env * bool) ->
  ('data * 'bdata) * ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * (('cdata, 'userdata) Base.env * bool)

type ('cdata, 'data, 'userdata, 'scenemsg, 'tar, 'msg, 'bdata) update_rec_middle_step =
  ('data * 'bdata) * ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * ('cdata, 'userdata) Base.env ->
  ('data * 'bdata) * ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * ('cdata, 'userdata) Base.env
