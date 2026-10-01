open Ml_regl_core
open Messenger

(* Two child kinds with their own message types; neither knows the parent. *)

module B = struct
  type msg = Set of int | Hit
  type init = { id : string; value : int }
  type data = init

  let init _runtime _env (init : init) : data = init

  let update _runtime env evt (data : data) =
    match evt with
    | Regl_proto.KeyDown "z" -> (data, [], (env, true))
    | _ -> (data, [], (env, false))

  let updaterec _runtime env msg (data : data) =
    match msg with
    | Set value ->
        ( { data with value },
          [ Component.Som (Scene.SOMSaveValue (data.id, string_of_int value)) ],
          env )
    | Hit -> ({ data with value = -1 }, [], env)

  let view _runtime _env _data = (Regl_builtin_programs.empty, 0)

  let component =
    {
      Component.init;
      update;
      updaterec;
      view;
      targets = (fun (data : data) -> [ data.id ]);
    }
end

module A = struct
  type msg = Ping | Pong of int

  (* [to_b] is a capability from the parent: it turns a [B.msg] into the
     parent's union without A naming that union. *)
  type 'p init = { id : string; key : string; to_b : B.msg -> 'p }
  type 'p data = { init : 'p init; count : int }

  let init _runtime _env init = { init; count = 0 }

  let update _runtime env evt data =
    match evt with
    | Regl_proto.KeyDown key when String.equal key data.init.key ->
        ( data,
          [
            Component.Parent (Pong data.count);
            Component.Other ("a2", Ping);
            Component.Other ("b", Ping);
            Component.Sibling ("b", data.init.to_b (B.Set 7));
            Component.Som (Scene.SOMSaveValue ("key", key));
          ],
          (env, false) )
    | _ -> (data, [], (env, false))

  let updaterec _runtime env msg data =
    match msg with
    | Ping ->
        let count = data.count + 1 in
        ({ data with count }, [ Component.Parent (Pong count) ], env)
    | Pong _ -> (data, [], env)

  let view _runtime _env _data = (Regl_builtin_programs.empty, 0)

  let component =
    {
      Component.init;
      update;
      updaterec;
      view;
      targets = (fun data -> [ data.init.id ]);
    }
end

(* The parent owns the union of its children and one port per kind. *)

type msg = A of A.msg | B of B.msg | Broadcast
type view = Count of int | Value of int

let a =
  Component.port_with
    ~inspect:(fun (data : _ A.data) -> Count data.count)
    (fun msg -> A msg)
    (function A msg -> Some msg | _ -> None)

let b =
  Component.port_with
    ~inspect:(fun (data : B.data) -> Value data.value)
    (fun msg -> B msg)
    (function B msg -> Some msg | Broadcast -> Some B.Hit | _ -> None)

let runtime = Internal.empty_runtime ()

let env : (unit, unit) Base.env =
  { global_data = { user_data = (); camera = Camera.origin }; common_data = () }

let make_a id key =
  Component.make a A.component { A.id; key; to_b = b.wrap } runtime env

let make_b id = Component.make b B.component { B.id; value = 0 } runtime env

let saved soms =
  List.filter_map
    (function
      | Scene.SOMSaveValue (key, value) -> Some (key, value) | _ -> None)
    soms

let () =
  let children = [ make_a "a1" "x"; make_a "a2" "y"; make_b "b" ] in
  assert (List.map Component.inspect children = [ Count 0; Count 0; Value 0 ]);
  (* a1 reports to the parent, pings a2 (same kind), sends B a message through
     its capability, and its [Other] to b is ignored because b is another
     kind. *)
  let children, up, soms, (_env, block) =
    Component.update_children runtime env (Regl_proto.KeyDown "x") children
  in
  assert (not block);
  assert (up = [ A (Pong 0); A (Pong 1) ]);
  assert (saved soms = [ ("key", "x"); ("b", "7") ]);
  assert (List.map Component.inspect children = [ Count 0; Count 1; Value 7 ]);
  (* The parent sends in its own union; b's port translates [Broadcast], a1's
     port drops it. *)
  let children, up, soms, _env =
    Component.send runtime env [ ("b", Broadcast); ("a1", Broadcast) ] children
  in
  assert (up = [] && soms = []);
  assert (List.map Component.inspect children = [ Count 0; Count 1; Value (-1) ])

let () =
  (* b is updated first (end of the list) and blocks the event, so the [a]
     child, which would react to "z", never sees it. *)
  let _, up, _, (_env, block) =
    Component.update_children runtime env (Regl_proto.KeyDown "z")
      [ make_a "a" "z"; make_b "b" ]
  in
  assert block;
  assert (up = []);
  let _, up, _, _ =
    Component.update_children runtime env (Regl_proto.KeyDown "z")
      [ make_a "a" "z" ]
  in
  assert (up = [ A (Pong 0) ])

(* [Init_update_component]: the first update runs [init_update], later ones run
   [update]. *)
module Starter = struct
  type msg = Started | Ticked

  let report msg _runtime env _evt data =
    (data, [ Component.Parent msg ], (env, false))

  let component =
    {
      Messenger_extra.Init_update_component.init = (fun _ _ () -> ());
      init_update = report Started;
      update = report Ticked;
      updaterec = (fun _ env _ data -> (data, [], env));
      view = (fun _ _ _ -> (Regl_builtin_programs.empty, 0));
      targets = (fun _ -> []);
    }
end

let () =
  let port = Component.port (fun msg -> msg) Option.some in
  let child =
    Messenger_extra.Init_update_component.make port Starter.component () runtime
      env
  in
  let tick = Regl_proto.UpdateTick 0. in
  let children, up, _, _ =
    Component.update_children runtime env tick [ child ]
  in
  assert (up = [ Starter.Started ]);
  let _, up, _, _ = Component.update_children runtime env tick children in
  assert (up = [ Starter.Ticked ])
