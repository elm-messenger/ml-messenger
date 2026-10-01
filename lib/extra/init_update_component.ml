open Ml_regl_core
open Messenger

(* A component whose first update runs [init_update] instead of [update]. *)

type ('data, 'msg, 'pmsg, 'cdata, 'userdata, 'tar) update =
  Internal.runtime ->
  ('cdata, 'userdata) Base.env ->
  Regl_proto.regl_event ->
  'data ->
  'data
  * ('msg, 'pmsg, 'tar, 'userdata) Component.cmd list
  * (('cdata, 'userdata) Base.env * bool)

type ('init, 'data, 'msg, 'pmsg, 'cdata, 'userdata, 'tar) spec = {
  init : Internal.runtime -> ('cdata, 'userdata) Base.env -> 'init -> 'data;
  init_update : ('data, 'msg, 'pmsg, 'cdata, 'userdata, 'tar) update;
  update : ('data, 'msg, 'pmsg, 'cdata, 'userdata, 'tar) update;
  updaterec :
    Internal.runtime ->
    ('cdata, 'userdata) Base.env ->
    'msg ->
    'data ->
    'data
    * ('msg, 'pmsg, 'tar, 'userdata) Component.cmd list
    * ('cdata, 'userdata) Base.env;
  view :
    Internal.runtime ->
    ('cdata, 'userdata) Base.env ->
    'data ->
    Regl_common.renderable * int;
  targets : 'data -> 'tar list;
}
(** Write it as a record literal, like [Component.spec]. *)

let to_component_spec
    (spec : ('init, 'data, 'msg, 'pmsg, 'cdata, 'userdata, 'tar) spec) :
    ('init, 'data * bool, 'msg, 'pmsg, 'cdata, 'userdata, 'tar) Component.spec =
  {
    init = (fun runtime env init -> (spec.init runtime env init, false));
    update =
      (fun runtime env evnt (data, started) ->
        let update = if started then spec.update else spec.init_update in
        let data, cmds, res = update runtime env evnt data in
        ((data, true), cmds, res));
    updaterec =
      (fun runtime env msg (data, started) ->
        let data, cmds, env = spec.updaterec runtime env msg data in
        ((data, started), cmds, env));
    view = (fun runtime env (data, _) -> spec.view runtime env data);
    targets = (fun (data, _) -> spec.targets data);
  }

(** Like [Component.make]; the port sees the component's own data. *)
let make (port : ('data, 'msg, 'pmsg, 'view) Component.port) spec init runtime
    env =
  let port : ('data * bool, 'msg, 'pmsg, 'view) Component.port =
    {
      wrap = port.wrap;
      unwrap = port.unwrap;
      inspect = (fun (data, _) -> port.inspect data);
    }
  in
  Component.make port (to_component_spec spec) init runtime env
