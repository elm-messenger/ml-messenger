type ('othermsg, 'sommsg) msg_base = SOMMsg of 'sommsg | OtherMsg of 'othermsg

type ('tar, 'msg, 'sommsg) msg =
  | Parent of ('msg, 'sommsg) msg_base
  | Other of 'tar * 'msg

let filter_som xs =
  List.filter_map (function SOMMsg som -> Some som | OtherMsg _ -> None) xs

type ('data,
       'envro,
       'env,
       'event,
       'tar,
       'msg,
       'ren,
       'bdata,
       'sommsg)
     concrete_general_model = {
  init : 'envro -> 'env -> 'msg -> 'data * 'bdata;
  update :
    'envro ->
    'env ->
    'event ->
    'data ->
    'bdata ->
    ('data * 'bdata) * ('tar, 'msg, 'sommsg) msg list * ('env * bool);
  updaterec :
    'envro ->
    'env ->
    'msg ->
    'data ->
    'bdata ->
    ('data * 'bdata) * ('tar, 'msg, 'sommsg) msg list * 'env;
  view : 'envro -> 'env -> 'data -> 'bdata -> 'ren;
  matcher : 'data -> 'bdata -> 'tar -> bool;
}

type ('envro,
       'env,
       'event,
       'tar,
       'msg,
       'ren,
       'bdata,
       'sommsg)
     abstract_general_model =
  | Roll of
      ( 'envro,
        'env,
        'event,
        'tar,
        'msg,
        'ren,
        'bdata,
        'sommsg )
      unrolled_abstract_general_model

and ('envro,
      'env,
      'event,
      'tar,
      'msg,
      'ren,
      'bdata,
      'sommsg)
    unrolled_abstract_general_model = {
  update :
    'envro ->
    'env ->
    'event ->
    ( 'envro,
      'env,
      'event,
      'tar,
      'msg,
      'ren,
      'bdata,
      'sommsg )
    abstract_general_model
    * ('tar, 'msg, 'sommsg) msg list
    * ('env * bool);
  updaterec :
    'envro ->
    'env ->
    'msg ->
    ( 'envro,
      'env,
      'event,
      'tar,
      'msg,
      'ren,
      'bdata,
      'sommsg )
    abstract_general_model
    * ('tar, 'msg, 'sommsg) msg list
    * 'env;
  view : 'envro -> 'env -> 'ren;
  matcher : 'tar -> bool;
  base_data : 'bdata;
  update_base_data :
    'bdata ->
    ( 'envro,
      'env,
      'event,
      'tar,
      'msg,
      'ren,
      'bdata,
      'sommsg )
    abstract_general_model;
}

let unroll (Roll un) = un

let abstract (type data envro env event tar msg ren bdata sommsg)
    (conmodel :
      ( data,
        envro,
        env,
        event,
        tar,
        msg,
        ren,
        bdata,
        sommsg )
      concrete_general_model) init_msg init_envro init_env =
  let rec abstract_rec data base =
    let update envro env event =
      let (new_d, new_bd), new_m, new_e =
        conmodel.update envro env event data base
      in
      (abstract_rec new_d new_bd, new_m, new_e)
    in
    let updaterec envro env msg =
      let (new_d, new_bd), new_m, new_e =
        conmodel.updaterec envro env msg data base
      in
      (abstract_rec new_d new_bd, new_m, new_e)
    in
    let update_base_data bd = abstract_rec data bd in
    Roll
      {
        update;
        updaterec;
        view = (fun envro env -> conmodel.view envro env data base);
        matcher = conmodel.matcher data base;
        base_data = base;
        update_base_data;
      }
  in
  let data, base = conmodel.init init_envro init_env init_msg in
  abstract_rec data base

let view_model_list envro env models =
  List.map (fun model -> (unroll model).view envro env) models

type ('data, 'tar) matcher = 'data -> 'tar -> bool

let update_result_remap f model =
  let rec change m =
    let um = unroll m in
    let update envro env evnt =
      let oldr, oldmsg, oldres = um.update envro env evnt in
      let newmsg, newres = f (oldmsg, oldres) in
      (change oldr, newmsg, newres)
    in
    Roll { um with update }
  in
  change model

let updaterec_result_remap f model =
  let rec change m =
    let um = unroll m in
    let updaterec envro env msg =
      let oldr, oldmsg, oldres = um.updaterec envro env msg in
      let newmsg, newres = f (oldmsg, oldres) in
      (change oldr, newmsg, newres)
    in
    Roll { um with updaterec }
  in
  change model
