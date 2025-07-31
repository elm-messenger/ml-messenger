open Base

(** Message base type for sending messages to parent objects *)
type ('othermsg, 'sommsg) msg_base =
  | SOMMsg of 'sommsg
  | OtherMsg of 'othermsg

(** Filter SOMMsg from list of msg_base *)
val filter_som : ('othermsg, 'sommsg) msg_base list -> 'sommsg list

(** Basic message type *)
type ('othertar, 'msg, 'sommsg) msg =
  | Parent of ('msg, 'sommsg) msg_base
  | Other of ('othertar * 'msg)

(** Concrete general model type *)
type ('data, 'env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) concrete_general_model = {
  init : 'env -> 'msg -> ('data * 'bdata);
  update : 'env -> 'event -> 'data -> 'bdata -> 
    (('data * 'bdata) * ('tar, 'msg, 'sommsg) msg list * ('env * bool));
  updaterec : 'env -> 'msg -> 'data -> 'bdata -> 
    (('data * 'bdata) * ('tar, 'msg, 'sommsg) msg list * 'env);
  view : 'env -> 'data -> 'bdata -> 'ren;
  matcher : 'data -> 'bdata -> 'tar -> bool;
}

(** Unrolled abstract general model type *)
type ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) unrolled_abstract_general_model = {
  update : 'env -> 'event -> 
    (('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model * 
     ('tar, 'msg, 'sommsg) msg list * ('env * bool));
  updaterec : 'env -> 'msg -> 
    (('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model * 
     ('tar, 'msg, 'sommsg) msg list * 'env);
  view : 'env -> 'ren;
  matcher : 'tar -> bool;
  base_data : 'bdata;
}

(** Rolled abstract general model type *)
and ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model =
  | Roll of ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) unrolled_abstract_general_model

(** Unroll a rolled abstract model *)
val unroll : ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model ->
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) unrolled_abstract_general_model

(** Abstract a concrete model to an abstract model *)
val abstract : 
  ('data, 'env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) concrete_general_model ->
  'msg -> 
  'env -> 
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model

(** View model list *)
val view_model_list : 
  ('common, 'userdata) env -> 
  (('common, 'userdata) env, user_event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model list -> 
  'ren list

(** General matcher type *)
type ('data, 'tar) matcher = 'data -> 'tar -> bool

(** Update result remap function *)
val update_result_remap : 
  ((('tar, 'msg, 'sommsg) msg list * ('env * bool)) -> (('tar, 'msg, 'sommsg) msg list * ('env * bool))) ->
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model -> 
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model

(** Updaterec result remap function *)
val updaterec_result_remap : 
  ((('tar, 'msg, 'sommsg) msg list * 'env) -> (('tar, 'msg, 'sommsg) msg list * 'env)) ->
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model -> 
  ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model