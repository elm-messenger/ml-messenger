open Messenger

type ('data, 'cdata, 'userdata, 'tar, 'msg, 'scenemsg) basic_updater =
  Internal.runtime ->
  ('cdata, 'userdata) Base.env ->
  Ml_regl_core.Regl_proto.regl_event ->
  'data ->
  'data * ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * (('cdata, 'userdata) Base.env * bool)

type ('data, 'cdata, 'userdata, 'tar, 'msg, 'scenemsg, 'cmsgpacker) distributor =
  Internal.runtime ->
  ('cdata, 'userdata) Base.env ->
  'data ->
  ('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list ->
  'data * (('tar, 'msg, 'scenemsg, 'userdata) Scene.m_msg list * 'cmsgpacker) * ('cdata, 'userdata) Base.env

