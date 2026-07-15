open Messenger
open Messenger_extra
open Ml_regl_core
open Ml_regl_core.Regl_proto

type user_data = unit
type model = { checked : bool }

module Counter_msg = struct
  type msg = Init of int | Add of int | Report
  type t = msg
end

module Panel_msg = struct
  type msg = Reset
end

module Counter = struct
  type msg = Counter_msg.t
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

  let view _runtime _env data = (Regl_builtin_programs.empty, data.value)

  let component : (_, _, _, _, _) Portable_component.concrete_portable_component
      =
    { init; update; updaterec; view }
end

[%%messenger_components
portable Counter = Counter;
msg Panel = Panel_msg.msg;
]

let check_portable_component () =
  let (_ : component_msg) = PanelMsg Panel_msg.Reset in
  let runtime = Internal.empty_runtime () in
  let env : (unit, user_data) Base.env =
    {
      global_data = { user_data = (); camera = Camera.origin };
      common_data = ();
    }
  in
  let comp =
    Counter_component.component ~target:"counter" ~map_target:Fun.id
      (Counter_msg.Init 1) runtime env
  in
  let comps, msgs, env =
    Component.update_components_with_target runtime env
      [ ("counter", CounterMsg Counter_msg.Report) ]
      [ comp ]
  in
  assert (msgs = []);
  let comps, msgs, (_env, block) =
    Component.update_components runtime env (UpdateTick 0.) comps
  in
  assert (not block);
  assert (msgs = []);
  let values =
    comps |> Component.gen_components_render_list runtime env |> List.map snd
  in
  assert (values = [ 2 ])

let init () =
  ( { checked = false },
    [
      start_regl
        {
          virt_width = 64.;
          virt_height = 64.;
          fbo_num = 1;
          builtin_programs = Some [];
          window = default_window_config;
          app_name = Some "portable-component-test";
        };
      config_regl (ConfigTimeInterval (Millisecond 1.));
    ] )

let update model = function
  | Event (UpdateTick _) when not model.checked ->
      check_portable_component ();
      ({ checked = true }, Regl_audio.silence, [ quit_regl () ])
  | _ -> (model, Regl_audio.silence, [])

let view _model = Regl_common.group [] []
let () = Regl_desktop.create_app init update view
