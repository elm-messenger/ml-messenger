open Base

(* Message base type for sending messages to parent objects *)
type ('othermsg, 'sommsg) msg_base = SOMMsg of 'sommsg | OtherMsg of 'othermsg

(* Filter SOMMsg from list of msg_base *)
let filter_som (msgs : ('othermsg, 'sommsg) msg_base list) : 'sommsg list =
  List.filter_map (function SOMMsg som -> Some som | OtherMsg _ -> None) msgs

(* Basic message type *)
type ('othertar, 'msg, 'sommsg) msg =
  | Parent of ('msg, 'sommsg) msg_base
  | Other of ('othertar * 'msg)

(* Concrete general model type *)
type ('data,
       'env,
       'event,
       'tar,
       'msg,
       'ren,
       'bdata,
       'sommsg)
     concrete_general_model = {
  init : 'env -> 'msg -> 'data * 'bdata;
  update :
    'env ->
    'event ->
    'data ->
    'bdata ->
    ('data * 'bdata) * ('tar, 'msg, 'sommsg) msg list * ('env * bool);
  updaterec :
    'env ->
    'msg ->
    'data ->
    'bdata ->
    ('data * 'bdata) * ('tar, 'msg, 'sommsg) msg list * 'env;
  view : 'env -> 'data -> 'bdata -> 'ren;
  matcher : 'data -> 'bdata -> 'tar -> bool;
}

(* Unrolled abstract general model type *)
type ('env,
       'event,
       'tar,
       'msg,
       'ren,
       'bdata,
       'sommsg)
     unrolled_abstract_general_model = {
  update :
    'env ->
    'event ->
    ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model
    * ('tar, 'msg, 'sommsg) msg list
    * ('env * bool);
  updaterec :
    'env ->
    'msg ->
    ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model
    * ('tar, 'msg, 'sommsg) msg list
    * 'env;
  view : 'env -> 'ren;
  matcher : 'tar -> bool;
  base_data : 'bdata;
  update_base_data :
    'bdata ->
    ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model;
}

(* Rolled abstract general model type *)
and ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model =
  | Roll of
      ( 'env,
        'event,
        'tar,
        'msg,
        'ren,
        'bdata,
        'sommsg )
      unrolled_abstract_general_model

(* Unroll a rolled abstract model *)
let unroll = function Roll un -> un

(* Abstract a concrete model to an abstract model *)
let abstract
    (conmodel :
      ( 'data,
        'env,
        'event,
        'tar,
        'msg,
        'ren,
        'bdata,
        'sommsg )
      concrete_general_model) (init_msg : 'msg) (init_env : 'env) :
    ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model =
  let rec abstract_rec (data : 'data) (base : 'bdata) :
      ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model =
    let updates env event =
      let (new_d, new_bd), new_m, new_e = conmodel.update env event data base in
      (abstract_rec new_d new_bd, new_m, new_e)
    in

    let updaterecs env msg =
      let (new_d, new_bd), new_m, new_e =
        conmodel.updaterec env msg data base
      in
      (abstract_rec new_d new_bd, new_m, new_e)
    in

    Roll
      {
        update = updates;
        updaterec = updaterecs;
        view = (fun env -> conmodel.view env data base);
        matcher = conmodel.matcher data base;
        base_data = base;
        update_base_data = abstract_rec data;
      }
  in

  let init_d, init_bd = conmodel.init init_env init_msg in
  abstract_rec init_d init_bd

(* View model list *)
let view_model_list (env : ('common, 'userdata) env)
    (models :
      ( ('common, 'userdata) env,
        user_event,
        'tar,
        'msg,
        'ren,
        'bdata,
        'sommsg )
      abstract_general_model
      list) : 'ren list =
  List.map (fun model -> (unroll model).view env) models

(* General matcher type *)
type ('data, 'tar) matcher = 'data -> 'tar -> bool

(* Update result remap function *)
let update_result_remap
    (f :
      ('tar, 'msg, 'sommsg) msg list * ('env * bool) ->
      ('tar, 'msg, 'sommsg) msg list * ('env * bool))
    (model :
      ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model)
    : ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model =
  let rec change m =
    let um = unroll m in
    let new_update env evnt =
      let oldr, oldmsg, oldres = um.update env evnt in
      let newmsg, newres = f (oldmsg, oldres) in
      (change oldr, newmsg, newres)
    in
    Roll { um with update = new_update }
  in
  change model

(* Updaterec result remap function *)
let updaterec_result_remap
    (f :
      ('tar, 'msg, 'sommsg) msg list * 'env ->
      ('tar, 'msg, 'sommsg) msg list * 'env)
    (model :
      ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model)
    : ('env, 'event, 'tar, 'msg, 'ren, 'bdata, 'sommsg) abstract_general_model =
  let rec change m =
    let um = unroll m in
    let new_updaterec env msg =
      let oldr, oldmsg, oldres = um.updaterec env msg in
      let newmsg, newres = f (oldmsg, oldres) in
      (change oldr, newmsg, newres)
    in
    Roll { um with updaterec = new_updaterec }
  in
  change model
