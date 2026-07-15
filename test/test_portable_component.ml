open Messenger
open Messenger_extra

type user_data = unit

module Counter_msg = struct
  type t = Init of int | Add of int | Report
end

type component_msg = CounterMsg of Counter_msg.t

module Counter = struct
  type data = { id : string; value : int }

  let init _runtime _env = function
    | Counter_msg.Init value -> { id = "counter"; value }
    | _ -> { id = "counter"; value = 0 }

  let update _runtime env _evt data = (data, [], (env, false))

  let updaterec _runtime env msg data =
    match msg with
    | Counter_msg.Add n -> ({ data with value = data.value + n }, [], env)
    | Report -> (data, [ General_model.Other (data.id, Counter_msg.Add 1) ], env)
    | Init _ -> (data, [], env)

  let view _runtime _env data =
    (Ml_regl_core.Regl_builtin_programs.empty, data.value)

  let component : (_, _, _, _, _) Portable_component.concrete_portable_component
      =
    { init; update; updaterec; view }
end

module Generated_counter = struct
  let wrap_msg msg = CounterMsg msg
  let unwrap_msg = function CounterMsg msg -> Some msg

  let component ~target ~map_target init_msg runtime env =
    Portable_component.adapt ~target ~map_target ~wrap_msg ~unwrap_msg
      Counter.component init_msg runtime env
end

let () =
  let runtime = Internal.empty_runtime () in
  let env : (unit, user_data) Base.env =
    {
      global_data = { user_data = (); camera = Camera.origin };
      common_data = ();
    }
  in
  let comp =
    Generated_counter.component ~target:"counter" ~map_target:Fun.id
      (Counter_msg.Init 1) runtime env
  in
  let comps, msgs, env =
    Component.update_components_with_target runtime env
      [ ("counter", CounterMsg Counter_msg.Report) ]
      [ comp ]
  in
  assert (msgs = []);
  let comps, msgs, (_env, block) =
    Component.update_components runtime env
      (Ml_regl_core.Regl_proto.UpdateTick 0.) comps
  in
  assert (not block);
  assert (msgs = []);
  let values =
    comps |> Component.gen_components_render_list runtime env |> List.map snd
  in
  assert (values = [ 2 ])
