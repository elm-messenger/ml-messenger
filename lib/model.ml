type 'userdata t = {
  runtime : Internal.runtime;
  env : ('userdata Scene.m_abstract_scene, 'userdata) Base.env;
  global_components : 'userdata Scene.abstract_global_component list;
}
