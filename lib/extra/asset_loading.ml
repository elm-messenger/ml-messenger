open Ml_regl_core
open Messenger

type init_option = unit

type data = {
  elapsed : float;
  prev_ts : float option;
  configured : bool;
  restore_max_assets : int;
}

(* This global component takes no messages. *)
type msg = |

let key : msg Global_component.key = Global_component.key "assetloading"

let init () runtime _env =
  ( {
      elapsed = 0.;
      prev_ts = None;
      configured = false;
      restore_max_assets = Base.get_max_assets_per_frame runtime;
    },
    { Scene.dead = false; post_processor = Fun.id } )

let update runtime env evnt data bdata =
  let loaded, total = Base.get_loading_progress runtime in
  let data =
    match evnt with
    | Regl_proto.UpdateTick ts ->
        (* Ignore a clock that jumps back (the MCP server's controlled
           clock). *)
        let delta =
          match data.prev_ts with None -> 0. | Some p -> Float.max 0. (ts -. p)
        in
        { data with elapsed = data.elapsed +. delta; prev_ts = Some ts }
    | _ -> data
  in
  let done_loading = loaded >= total in
  let first_update = not data.configured in
  let data = { data with configured = true } in
  let msgs =
    (if first_update then [ Scene.SOMChangeMaxAssetsPerFrame 0 ] else [])
    @
    if done_loading then
      [ Scene.SOMChangeMaxAssetsPerFrame data.restore_max_assets ]
    else []
  in
  ((data, { bdata with Scene.dead = done_loading }), msgs, (env, false))

let updaterec _runtime _env (msg : msg) _data _bdata = match msg with _ -> .

let view runtime _env data _bdata =
  let _, virtual_height = Base.get_virtual_size runtime in
  let spinner =
    List.init 8 (fun i ->
        let fi = float_of_int i in
        let x = 15. *. cos (Float.pi /. 4. *. fi) in
        let y = 15. *. sin (Float.pi /. 4. *. fi) in
        let radius =
          2. +. sin ((data.elapsed *. 0.005) +. (2. *. Float.pi *. fi /. 8.))
        in
        Regl_builtin_programs.circle
          (30. +. x, virtual_height -. 30. +. y)
          radius Color.white)
  in
  Regl_common.group [] (Regl_builtin_programs.clear Color.black :: spinner)

let gc_con () : (_, _, _) Scene.concrete_global_component =
  { init = init (); update; updaterec; view; key }

let gen_gc ?key () = Global_component.make ?key (gc_con ())
