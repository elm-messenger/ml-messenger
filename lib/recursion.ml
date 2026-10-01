open General_model

(* Cost, for n models: an event costs O(n + M) for the M messages it produces;
   each round of targeted messages costs O(n + m + d) for its m messages and d
   deliveries. Messages are accumulated in reverse and reversed once, and a
   round with many messages indexes them by target. *)

(* Add [msgs] to the reversed accumulators of targeted and finished messages. *)
let split_rev msgs acc =
  List.fold_left
    (fun (targeted, finished) -> function
      | Parent msg -> (targeted, msg :: finished)
      | Other (tar, msg) -> ((tar, msg) :: targeted, finished))
    acc msgs

(* Targets are compared like [Hashtbl] compares keys. *)
let same a b = compare a b = 0

(* A round with fewer messages than this scans each model's targets instead of
   indexing the messages: measured with 4000 models, the index already wins at
   two messages. *)
let index_threshold = 2

(* Returns, for a model's targets, the messages addressed to any of them, in
   send order. *)
let deliveries (msgs : ('tar * 'msg) list) : 'tar list -> 'msg list =
  if List.compare_length_with msgs index_threshold < 0 then fun targets ->
    List.filter_map
      (fun (tar, msg) ->
        if List.exists (same tar) targets then Some msg else None)
      msgs
  else
    let index = Hashtbl.create (List.length msgs) in
    List.iteri (fun seq (tar, msg) -> Hashtbl.add index tar (seq, msg)) msgs;
    function
    | [] -> []
    | [ tar ] ->
        (* [find_all] returns the most recently added binding first. *)
        List.rev_map snd (Hashtbl.find_all index tar)
    | targets ->
        List.sort_uniq compare targets
        |> List.concat_map (Hashtbl.find_all index)
        |> List.sort (fun (a, _) (b, _) -> Int.compare a b)
        |> List.map snd

(* Deliver targeted messages round by round until none remain. Each round visits
   the models in order; messages they send go to the next round. *)
let rec update_remain envro env targeted finished_rev objs =
  match targeted with
  | [] -> (objs, List.rev finished_rev, env)
  | _ ->
      let for_model = deliveries targeted in
      let env, objs_rev, acc, touched =
        List.fold_left
          (fun (env, objs_rev, acc, touched) obj ->
            match for_model ((unroll obj).targets ()) with
            | [] -> (env, obj :: objs_rev, acc, touched)
            | msgs ->
                let obj, env, acc =
                  List.fold_left
                    (fun (obj, env, acc) msg ->
                      let obj, out, env =
                        (unroll obj).updaterec envro env msg
                      in
                      (obj, env, split_rev out acc))
                    (obj, env, acc) msgs
                in
                (env, obj :: objs_rev, acc, true))
          (env, [], ([], finished_rev), false)
          objs
      in
      let objs = if touched then List.rev objs_rev else objs in
      let targeted_rev, finished_rev = acc in
      update_remain envro env (List.rev targeted_rev) finished_rev objs

let update_objects envro env evt objs =
  (* Visit models from the end of the list; [block] stops the traversal. *)
  let rec visit env pending visited acc =
    match pending with
    | [] -> (visited, acc, (env, false))
    | obj :: rest ->
        let obj, out, (env, block) = (unroll obj).update envro env evt in
        let acc = split_rev out acc in
        if block then (List.rev_append rest (obj :: visited), acc, (env, true))
        else visit env rest (obj :: visited) acc
  in
  let objs, (targeted_rev, finished_rev), (env, block) =
    visit env (List.rev objs) [] ([], [])
  in
  let objs, finished, env =
    update_remain envro env (List.rev targeted_rev) finished_rev objs
  in
  (objs, finished, (env, block))

let update_objects_with_target envro env msgs objs =
  update_remain envro env msgs [] objs

let remove_objects tar xs =
  List.filter (fun x -> not (List.exists (same tar) ((unroll x).targets ()))) xs
