type ('userdata, 'scenemsg) t = {
  runtime : Internal.runtime;
  env : (('userdata, 'scenemsg) Scene.m_abstract_scene, 'userdata) Base.env;
  global_components : ('userdata, 'scenemsg) Scene.abstract_global_component list;
  started : bool;
}

let update_scene_time m delta =
  m.runtime.scene_start_time <- m.runtime.scene_start_time +. delta;
  m.runtime.scene_start_frame <- m.runtime.scene_start_frame + 1;
  m

let reset_scene_start_time m =
  m.runtime.scene_start_time <- 0.;
  m.runtime.scene_start_frame <- 0;
  m
