open Ml_regl_core
open Messenger
open Transition_base

type ('scenemsg, 'userdata) init_option = {
  transition : transition;
  scene : string * 'scenemsg option;
  filter_som : bool;
}

type phase = BeforeChange | AfterChange | Finished

type ('userdata, 'scenemsg) data = {
  transition : transition;
  target_scene : string;
  target_msg : 'scenemsg option;
  filter_som : bool;
  phase : phase;
  old_vsr : ('userdata, 'scenemsg) Vsr.t option;
  prev_ts : float option;
}

let clamp01 x = max 0. (min 1. x)
let empty_pp r = r

let init (opt : ('scenemsg, 'userdata) init_option) runtime env _msg =
  let old_vsr =
    Some
      {
        Vsr.env = Base.remove_common_data env;
        runtime;
        scene = env.common_data;
      }
  in
  ( {
      transition = opt.transition;
      target_scene = fst opt.scene;
      target_msg = snd opt.scene;
      filter_som = opt.filter_som;
      phase = BeforeChange;
      old_vsr;
      prev_ts = None;
    },
    { Scene.dead = false; post_processor = empty_pp } )

let suppress_scene_change_soms data msgs =
  if not data.filter_som then msgs
  else
    List.filter
      (function
        | General_model.Parent (SOMMsg (Scene.SOMChangeScene _ | SOMLoadGC _))
          ->
            false
        | _ -> true)
      msgs

let update_m_transition _runtime env (mt : mix_transition) data bdata dt =
  let current = mt.current_transition +. dt in
  let ratio = if mt.t <= 0. then 1. else clamp01 (current /. mt.t) in
  let was_before_change = data.phase = BeforeChange in
  let old_view =
    match data.old_vsr with
    | None -> Regl_builtin_programs.empty
    | Some vsr -> Vsr.view_vsr vsr
  in
  let bdata =
    {
      bdata with
      Scene.post_processor = (fun new_view -> mt.trans old_view new_view ratio);
      dead = current >= mt.t;
    }
  in
  let transition = MTransition { mt with current_transition = current } in
  let data = { data with transition; phase = AfterChange } in
  let msgs =
    if was_before_change then
      [
        General_model.Parent
          (SOMMsg (Scene.SOMChangeScene (data.target_msg, data.target_scene)));
      ]
    else []
  in
  ((data, bdata), msgs, (env, false))

let update_nm_transition _runtime env (nt : no_mix_transition) data bdata dt =
  let current = nt.current_transition +. dt in
  match data.phase with
  | BeforeChange ->
      let ratio =
        if nt.out_t <= 0. then 1. else clamp01 (current /. nt.out_t)
      in
      let bdata =
        {
          bdata with
          Scene.post_processor = (fun view -> nt.out_trans view ratio);
        }
      in
      if current >= nt.out_t then
        let transition = NMTransition { nt with current_transition = 0. } in
        let data = { data with transition; phase = AfterChange } in
        ( (data, bdata),
          [
            General_model.Parent
              (SOMMsg
                 (Scene.SOMChangeScene (data.target_msg, data.target_scene)));
          ],
          (env, false) )
      else
        let transition =
          NMTransition { nt with current_transition = current }
        in
        (({ data with transition }, bdata), [], (env, false))
  | AfterChange ->
      let ratio = if nt.in_t <= 0. then 1. else clamp01 (current /. nt.in_t) in
      let bdata =
        {
          bdata with
          Scene.post_processor = (fun view -> nt.in_trans view ratio);
          dead = current >= nt.in_t;
        }
      in
      let transition = NMTransition { nt with current_transition = current } in
      let phase = if current >= nt.in_t then Finished else AfterChange in
      (({ data with transition; phase }, bdata), [], (env, false))
  | Finished ->
      ( (data, { bdata with Scene.dead = true; post_processor = empty_pp }),
        [],
        (env, false) )

let update runtime env evnt data bdata =
  let data =
    match data.old_vsr with
    | None -> data
    | Some vsr ->
        let new_vsr, _msgs = Vsr.update_vsr vsr evnt in
        { data with old_vsr = Some new_vsr }
  in
  match evnt with
  | Regl_proto.UpdateTick ts ->
      let dt = match data.prev_ts with None -> 0. | Some p -> ts -. p in
      let data = { data with prev_ts = Some ts } in
      (match data.transition with
       | MTransition mt -> update_m_transition runtime env mt data bdata dt
       | NMTransition nt -> update_nm_transition runtime env nt data bdata dt)
  | _ -> ((data, bdata), [], (env, false))

let updaterec _runtime env _msg data bdata = ((data, bdata), [], env)
let view _runtime _env _data _bdata = Regl_builtin_programs.empty

let gc_con opt () : (_, _, _) Scene.concrete_global_component =
  { init = init opt; update; updaterec; view; id = "transition" }

let gen_gc opt target =
  Global_component.gen_global_component (gc_con opt ()) "" target

let gen_transition_som transition scene =
  Scene.SOMLoadGC (gen_gc { transition; scene; filter_som = true } None)

let gen_sequential_transition_som out_t in_t scene =
  gen_transition_som (gen_no_mix_transition out_t in_t) scene

let gen_mixed_transition_som transition scene =
  gen_transition_som (gen_mix_transition transition) scene
