open Ml_regl_core
open Messenger
module Panel = Components.Panel.Model
module Badge = Pcomp.Badge.Model

(* The union of this scene's children. The badge comes from another directory
   and is used exactly like the local panel. *)
type msg = Panel of Panel.msg | Badge of Badge.msg

let panel =
  Component.port
    (fun msg -> Panel msg)
    (function Panel msg -> Some msg | _ -> None)

let badge =
  Component.port
    (fun msg -> Badge msg)
    (function Badge msg -> Some msg | _ -> None)

type component = (unit, Lib.User_data.user_data, string, msg, unit) Component.t
type data = { components : component list; last_panel_count : int }

let init runtime env _msg =
  {
    components =
      [
        Component.make panel Panel.component
          { Panel.to_badge = badge.wrap }
          runtime env;
        Component.make badge Badge.component
          { Badge.id = "badge"; text = "portable badge" }
          runtime env;
      ];
    last_panel_count = 0;
  }

let handle data = function
  | Panel (Updated count) -> { data with last_panel_count = count }
  | Panel Ping | Badge _ -> data

let update runtime env evnt data =
  match evnt with
  | Regl_proto.KeyDown "Backspace" ->
      (data, [ Scene.SOMChangeScene (By_name "Home") ], env)
  | KeyDown "Return" ->
      let components, msgs, soms, env =
        Component.send runtime env [ ("panel", Panel Ping) ] data.components
      in
      (List.fold_left handle { data with components } msgs, soms, env)
  | _ ->
      let components, msgs, soms, (env, _block) =
        Component.update_children runtime env evnt data.components
      in
      (List.fold_left handle { data with components } msgs, soms, env)

let view runtime env data =
  Regl_common.group []
    [
      Regl_builtin_programs.clear Color.white;
      Regl_builtin_programs.textbox (0., 30.) 24.
        "Portable components: Space/Return updates badge, F flashes, Backspace \
         home"
        "firacode" Color.black;
      Regl_builtin_programs.textbox (0., 65.) 20.
        ("Last panel count: " ^ string_of_int data.last_panel_count)
        "firacode" Color.black;
      Component.view_components runtime env data.components;
    ]

let scenecon : (_, _, _, _, _, _, _) Scene.concrete_scene =
  { init; update; view }

let scene msg runtime env = Scene.abstract scenecon msg runtime env
