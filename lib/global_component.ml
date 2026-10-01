type 'msg key = 'msg Scene.gc_key
(** Keys name global component instances and the messages they accept. *)

let key = Scene.gc_key

(** A global component instance. [?key] gives it its own key (default: the
    component's), e.g. to load two instances of the same component. Calls whose
    key has the instance's name but another identity are reported and ignored.
*)
let make (type data msg userdata) ?key
    (concomp : (data, msg, userdata) Scene.concrete_global_component) :
    userdata Scene.global_component_storage =
 fun runtime env ->
  let key : msg key = Option.value key ~default:concomp.key in
  let lift soms =
    List.map (fun som -> General_model.Parent (SOMMsg som)) soms
  in
  let concrete :
      (_, _, _, _, _, _, _, _, _) General_model.concrete_general_model =
    {
      init = (fun runtime env _ -> concomp.init runtime env);
      update =
        (fun runtime env evt data bdata ->
          let res, soms, env_block =
            concomp.update runtime env evt data bdata
          in
          (res, lift soms, env_block));
      updaterec =
        (fun runtime env call data bdata ->
          match call with
          | Scene.Gc_call (call_key, msg) -> (
              match Type.Id.provably_equal call_key.gc_id key.gc_id with
              | Some Equal ->
                  let res, soms, env =
                    concomp.updaterec runtime env msg data bdata
                  in
                  (res, lift soms, env)
              | None ->
                  Printf.eprintf
                    "ml-messenger: global component %S was called with a key \
                     of another type; the call is ignored\n\
                     %!"
                    key.gc_name;
                  ((data, bdata), [], env)));
      view = (fun runtime env data bdata -> concomp.view runtime env data bdata);
      targets = (fun _ _ -> [ key.gc_name ]);
    }
  in
  let data, bdata = concomp.init runtime env in
  General_model.of_data concrete data bdata

let filter_alive_gc xs =
  List.filter (fun x -> not (General_model.unroll x).base_data.Scene.dead) xs

let combine_pp xs =
  List.map
    (fun gc -> (General_model.unroll gc).base_data.Scene.post_processor)
    xs
