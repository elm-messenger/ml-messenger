open Ml_regl_core

(* Components with their own message types.

   A component defines its own [msg], [init] and [data] types and never names
   its parent's message type. The parent owns the union of its children's
   messages and creates each child through a [port], which says how that child's
   messages enter and leave the union. *)

(** What a component emits. *)
type ('msg, 'pmsg, 'tar, 'userdata) cmd =
  | Parent of 'msg  (** To the parent, wrapped into its union by the port. *)
  | Other of 'tar * 'msg  (** To matching siblings of the same kind. *)
  | Sibling of 'tar * 'pmsg
      (** To any matching sibling, using a value of the parent's union that the
          parent handed to this component (for example a port's [wrap]). *)
  | Som of 'userdata Scene.scene_output_msg

type ('init, 'data, 'msg, 'pmsg, 'cdata, 'userdata, 'tar) spec = {
  init : Internal.runtime -> ('cdata, 'userdata) Base.env -> 'init -> 'data;
  update :
    Internal.runtime ->
    ('cdata, 'userdata) Base.env ->
    Regl_proto.regl_event ->
    'data ->
    'data
    * ('msg, 'pmsg, 'tar, 'userdata) cmd list
    * (('cdata, 'userdata) Base.env * bool);
  updaterec :
    Internal.runtime ->
    ('cdata, 'userdata) Base.env ->
    'msg ->
    'data ->
    'data
    * ('msg, 'pmsg, 'tar, 'userdata) cmd list
    * ('cdata, 'userdata) Base.env;
  view :
    Internal.runtime ->
    ('cdata, 'userdata) Base.env ->
    'data ->
    Regl_common.renderable * int;
  targets : 'data -> 'tar list;
      (** Targets this component answers to ([Other], [Sibling], and [send]
          address them). They are compared structurally, so they must not
          contain functions. *)
}
(** A component definition. Write it as a record literal so it stays polymorphic
    in the parent's types. *)

type ('data, 'msg, 'pmsg, 'view) port = {
  wrap : 'msg -> 'pmsg;
  unwrap : 'pmsg -> 'msg option;
  inspect : 'data -> 'view;
}
(** How a parent sees one kind of child: how the child's messages enter ([wrap])
    and leave ([unwrap]) the parent's union, and what the parent can read from
    it ([inspect]). [unwrap] may translate a shared parent message into the
    child's own message. *)

let port wrap unwrap = { wrap; unwrap; inspect = (fun _ -> ()) }
let port_with ~inspect wrap unwrap = { wrap; unwrap; inspect }

type ('cdata, 'userdata, 'tar, 'pmsg, 'view) t =
  ( Internal.runtime,
    ('cdata, 'userdata) Base.env,
    Regl_proto.regl_event,
    'tar,
    'pmsg,
    Regl_common.renderable * int,
    'view,
    'userdata Scene.scene_output_msg )
  General_model.abstract_general_model
(** A child component, typed by its parent: the parent's common data, user data,
    target, message union, and inspect view. *)

let inspect (child : (_, _, _, _, 'view) t) : 'view =
  (General_model.unroll child).base_data

let make (port : ('data, 'msg, 'pmsg, 'view) port)
    (spec : ('init, 'data, 'msg, 'pmsg, 'cdata, 'userdata, 'tar) spec)
    (init : 'init) runtime (env : ('cdata, 'userdata) Base.env) :
    ('cdata, 'userdata, 'tar, 'pmsg, 'view) t =
  let lift = function
    | Parent msg -> General_model.Parent (OtherMsg (port.wrap msg))
    | Other (tar, msg) -> General_model.Other (tar, port.wrap msg)
    | Sibling (tar, pmsg) -> General_model.Other (tar, pmsg)
    | Som som -> General_model.Parent (SOMMsg som)
  in
  let concrete :
      (_, _, _, _, _, _, _, _, _) General_model.concrete_general_model =
    {
      init =
        (fun runtime env _ ->
          let data = spec.init runtime env init in
          (data, port.inspect data));
      update =
        (fun runtime env evt data _ ->
          let data, cmds, res = spec.update runtime env evt data in
          ((data, port.inspect data), List.map lift cmds, res));
      updaterec =
        (fun runtime env pmsg data view ->
          match port.unwrap pmsg with
          | None -> ((data, view), [], env)
          | Some msg ->
              let data, cmds, env = spec.updaterec runtime env msg data in
              ((data, port.inspect data), List.map lift cmds, env));
      view = (fun runtime env data _ -> spec.view runtime env data);
      targets = (fun data _ -> spec.targets data);
    }
  in
  let data = spec.init runtime env init in
  General_model.of_data concrete data (port.inspect data)

(** Split children's outputs into messages for the parent and scene output
    messages. *)
let split_outputs outputs =
  List.partition_map
    (function
      | General_model.OtherMsg msg -> Either.Left msg | SOMMsg som -> Right som)
    outputs

(** Update children with an event. Returns the children, the messages they sent
    to the parent (in its union), their scene output messages, and the
    environment with the block flag. *)
let update_children runtime (env : ('cdata, 'userdata) Base.env) evt
    (children : ('cdata, 'userdata, 'tar, 'pmsg, 'view) t list) :
    ('cdata, 'userdata, 'tar, 'pmsg, 'view) t list
    * 'pmsg list
    * 'userdata Scene.scene_output_msg list
    * (('cdata, 'userdata) Base.env * bool) =
  let children, outputs, res =
    Recursion.update_objects runtime env evt children
  in
  let up, soms = split_outputs outputs in
  (children, up, soms, res)

(** Send messages in the parent's union to matching children. Returns the same
    shape as [update_children], without the block flag. *)
let send runtime (env : ('cdata, 'userdata) Base.env)
    (msgs : ('tar * 'pmsg) list)
    (children : ('cdata, 'userdata, 'tar, 'pmsg, 'view) t list) :
    ('cdata, 'userdata, 'tar, 'pmsg, 'view) t list
    * 'pmsg list
    * 'userdata Scene.scene_output_msg list
    * ('cdata, 'userdata) Base.env =
  let children, outputs, env =
    Recursion.update_objects_with_target runtime env msgs children
  in
  let up, soms = split_outputs outputs in
  (children, up, soms, env)

(* Draw children ordered by the z-index each view returns. *)
let gen_components_render_list runtime env compls =
  List.map (fun comp -> (General_model.unroll comp).view runtime env) compls

let view_components_render_list previews =
  previews
  |> List.sort (fun (_, a) (_, b) -> compare a b)
  |> List.map fst |> Regl_common.group []

let view_components runtime env compls =
  view_components_render_list (gen_components_render_list runtime env compls)
