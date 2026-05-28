open Ml_regl_core

type ('userdata, 'scenemsg) t = {
  env : (unit, 'userdata) Base.env;
  runtime : Internal.runtime;
  scene : ('userdata, 'scenemsg) Scene.m_abstract_scene;
}

let update_vsr vsr evnt =
  (match evnt with
  | Regl_proto.UpdateTick ts -> vsr.runtime.current_timestamp <- ts
  | _ -> ());
  let new_scene, new_msg, new_env =
    (Scene.unroll vsr.scene).update vsr.runtime vsr.env evnt
  in
  ({ vsr with env = new_env; scene = new_scene }, new_msg)

let view_vsr vsr = (Scene.unroll vsr.scene).view vsr.runtime vsr.env
