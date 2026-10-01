open Ml_regl_core
open Messenger
module Badge = Pcomp.Badge.Model

type msg = Ping | Updated of int

(* The scene hands the panel a way to address the badge in the scene's own
   message type; the panel never names that type. *)
type 'p init = { to_badge : Badge.msg -> 'p }
type 'p data = { count : int; to_badge : Badge.msg -> 'p }

let init _runtime _env (init : _ init) = { count = 0; to_badge = init.to_badge }
let to_badge data msg = Component.Sibling ("badge", data.to_badge msg)

let update _runtime env evnt data =
  match evnt with
  | Regl_proto.KeyDown "Space" ->
      let count = data.count + 1 in
      ( { data with count },
        [
          to_badge data (Badge.Set_text ("panel ping " ^ string_of_int count));
          Component.Parent (Updated count);
        ],
        (env, false) )
  | KeyDown "F" -> (data, [ to_badge data Badge.Flash ], (env, false))
  | _ -> (data, [], (env, false))

let updaterec _runtime env msg data =
  match msg with
  | Ping ->
      let count = data.count + 1 in
      ( { data with count },
        [ to_badge data (Badge.Set_text ("scene ping " ^ string_of_int count)) ],
        env )
  | Updated _ -> (data, [], env)

let view _runtime _env data =
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

let component =
  {
    Component.init;
    update;
    updaterec;
    view;
    matcher = (fun _data target -> String.equal target "panel");
  }
