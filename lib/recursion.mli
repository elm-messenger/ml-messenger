open Generalmodel

val update_objects :
  'env ->
  'event ->
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model list ->
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model list
  * ('msg, 'sommsg) msg_base list
  * ('env * bool)
(** Recursively update all the objects in the List *)

val update_objects_with_target :
  'env ->
  ('tar * 'msg) list ->
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model list ->
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model list
  * ('msg, 'sommsg) msg_base list
  * 'env
(** Recursively update all the objects in the List, but also uses target *)

val remove_objects :
  'tar ->
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model list ->
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model list
(** Remove all objects by target *)
