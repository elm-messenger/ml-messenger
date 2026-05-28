type ('data, 'userdata, 'scenemsg) raw_scene_init = Internal.runtime -> (unit, 'userdata) Base.env -> 'scenemsg option -> 'data
type ('data, 'userdata, 'scenemsg) raw_scene_update = Internal.runtime -> (unit, 'userdata) Base.env -> Ml_regl_core.Regl_proto.regl_event -> 'data -> 'data * ('scenemsg, 'userdata) Scene.scene_output_msg list * (unit, 'userdata) Base.env
type ('userdata, 'data) raw_scene_view = Internal.runtime -> (unit, 'userdata) Base.env -> 'data -> Ml_regl_core.Regl_common.renderable

type ('userdata, 'scenemsg, 'idata) raw_scene_proto_level_init = Internal.runtime -> (unit, 'userdata) Base.env -> 'scenemsg option -> 'idata option
type ('data, 'userdata, 'idata) raw_scene_proto_init = Internal.runtime -> (unit, 'userdata) Base.env -> 'idata option -> 'data

let gen_raw_scene = Scene.abstract
let init_compose pinit linit runtime env msg = pinit runtime env (linit runtime env msg)
