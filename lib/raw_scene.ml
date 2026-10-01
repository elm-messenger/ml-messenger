type ('data, 'userdata, 'param) raw_scene_init =
  Internal.runtime -> (unit, 'userdata) Base.env -> 'param option -> 'data

type ('data, 'userdata) raw_scene_update =
  Internal.runtime ->
  (unit, 'userdata) Base.env ->
  Ml_regl_core.Regl_proto.regl_event ->
  'data ->
  'data * 'userdata Scene.scene_output_msg list * (unit, 'userdata) Base.env

type ('userdata, 'data) raw_scene_view =
  Internal.runtime ->
  (unit, 'userdata) Base.env ->
  'data ->
  Ml_regl_core.Regl_common.renderable

let gen_raw_scene = Scene.abstract
