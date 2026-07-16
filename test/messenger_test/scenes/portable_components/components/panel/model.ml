open Ml_regl_core
open Messenger
module Component_base = Mgl.Base.Components.Portable_components.Component_base
open Component_base
module Msg = Panel_msg

type data = { count : int }

let init _runtime _env = function
  | PanelMsg Msg.Init -> ({ count = 0 }, ())
  | _ -> ({ count = 0 }, ())

let update _runtime env evnt data basedata =
  match evnt with
  | Regl_proto.KeyDown "Space" ->
      let count = data.count + 1 in
      ( ({ count }, basedata),
        [
          General_model.Other
            ( "badge",
              BadgeMsg
                (Pcomp.Badge.Model.SetText ("panel ping " ^ string_of_int count))
            );
          General_model.Parent (OtherMsg (PanelMsg (Msg.PortableUpdated count)));
        ],
        (env, false) )
  | KeyDown "F" ->
      ( (data, basedata),
        [ General_model.Other ("badge", BadgeMsg Pcomp.Badge.Model.Flash) ],
        (env, false) )
  | _ -> ((data, basedata), [], (env, false))

let updaterec _runtime env msg data basedata =
  match msg with
  | PanelMsg Msg.PingPortable ->
      let count = data.count + 1 in
      ( ({ count }, basedata),
        [
          General_model.Other
            ( "badge",
              BadgeMsg
                (Pcomp.Badge.Model.SetText ("scene ping " ^ string_of_int count))
            );
        ],
        env )
  | _ -> ((data, basedata), [], env)

let view _runtime _env data _basedata =
  ( Regl_common.group []
      [
        Regl_builtin_programs.rect_centered (240., 220.) (320., 180.) 0.
          (Color.rgb 0.85 0.9 1.);
        Regl_builtin_programs.textbox_centered (240., 190.) 24.
          "local panel component" "firacode" Color.black;
        Regl_builtin_programs.textbox_centered (240., 235.) 22.
          ("sent: " ^ string_of_int data.count)
          "firacode" Color.black;
      ],
    0 )

let matcher _data _basedata target = target = "panel"

let componentcon : (_, _, _, _, _, _, _) Component.concrete_user_component =
  { init; update; updaterec; view; matcher }

let component msg runtime env =
  Component.gen_component componentcon msg runtime env
