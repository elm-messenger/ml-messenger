type ('userdata, 'scenemsg) t = {
  runtime : Internal.runtime;
  env : (('userdata, 'scenemsg) Scene.m_abstract_scene, 'userdata) Base.env;
  global_components :
    ('userdata, 'scenemsg) Scene.abstract_global_component list;
}
