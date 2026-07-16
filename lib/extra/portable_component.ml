open Ml_regl_core
open Messenger

type target = string

type ('common, 'userdata, 'msg, 'scenemsg, 'data) concrete_portable_component = {
  init : Internal.runtime -> ('common, 'userdata) Base.env -> 'msg -> 'data;
  update :
    Internal.runtime ->
    ('common, 'userdata) Base.env ->
    Regl_proto.regl_event ->
    'data ->
    'data
    * (target, 'msg, 'scenemsg, 'userdata) Scene.m_msg list
    * (('common, 'userdata) Base.env * bool);
  updaterec :
    Internal.runtime ->
    ('common, 'userdata) Base.env ->
    'msg ->
    'data ->
    'data
    * (target, 'msg, 'scenemsg, 'userdata) Scene.m_msg list
    * ('common, 'userdata) Base.env;
  view :
    Internal.runtime ->
    ('common, 'userdata) Base.env ->
    'data ->
    Regl_common.renderable * int;
}

let map_msg ~wrap_msg ~map_target = function
  | General_model.Parent (OtherMsg msg) ->
      General_model.Parent (OtherMsg (wrap_msg msg))
  | Parent (SOMMsg som) -> Parent (SOMMsg som)
  | Other (target, msg) -> Other (map_target target, wrap_msg msg)

let adapt ~matcher ~map_target ~wrap_msg ~unwrap_msg pcomp init_msg runtime env
    =
  let init runtime env _msg = (pcomp.init runtime env init_msg, ()) in
  let update runtime env evt data () =
    let data, msgs, res = pcomp.update runtime env evt data in
    ((data, ()), List.map (map_msg ~wrap_msg ~map_target) msgs, res)
  in
  let updaterec runtime env msg data () =
    match unwrap_msg msg with
    | None -> ((data, ()), [], env)
    | Some msg ->
        let data, msgs, env = pcomp.updaterec runtime env msg data in
        ((data, ()), List.map (map_msg ~wrap_msg ~map_target) msgs, env)
  in
  let view runtime env data () = pcomp.view runtime env data in
  let matcher _data () tar = matcher tar in
  Component.gen_component
    { init; update; updaterec; view; matcher }
    (wrap_msg init_msg) runtime env
