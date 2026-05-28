open General_model

let split_msgs msgs =
  List.fold_left
    (fun (unfinished, finished) -> function
      | Parent x -> (unfinished, finished @ [ x ])
      | Other (tar, msg) -> (unfinished @ [ (tar, msg) ], finished))
    ([], []) msgs

let rec update_one envro last_env evt objs last_objs last_msg_unfinished last_msg_finished =
  match objs with
  | ele :: rest_objs ->
      let new_obj, new_msg, (new_env, block) = (unroll ele).update envro last_env evt in
      let unfinished_msg, finished_msg = split_msgs new_msg in
      let all_unfinished = last_msg_unfinished @ unfinished_msg in
      let all_finished = last_msg_finished @ finished_msg in
      if block then
        (List.rev rest_objs @ (new_obj :: last_objs), (all_unfinished, all_finished), (new_env, block))
      else update_one envro new_env evt rest_objs (new_obj :: last_objs) all_unfinished all_finished
  | [] -> (last_objs, (last_msg_unfinished, last_msg_finished), (last_env, false))

let update_once envro env evt objs = update_one envro env evt (List.rev objs) [] [] []

let rec update_remain envro env (unfinished_msg, finished_msg) objs =
  match unfinished_msg with
  | [] -> (objs, finished_msg, env)
  | _ ->
      let new_objs, (new_unfinished_msg, new_finished_msg), new_env =
        List.fold_left
          (fun (last_objs, (last_msg_unfinished, last_msg_finished), last_env) ele ->
            let msg_matched =
              List.filter_map
                (fun (tar, msg) -> if (unroll ele).matcher tar then Some msg else None)
                unfinished_msg
            in
            match msg_matched with
            | [] -> (last_objs @ [ ele ], (last_msg_unfinished, last_msg_finished), last_env)
            | _ ->
                let new_obj, (new_unfinished, new_finished), new_env2 =
                  List.fold_left
                    (fun (last_obj, (last_unfinished, last_finished), last_env2) msg ->
                      let new_ele, new_msgs, new_env3 = (unroll last_obj).updaterec envro last_env2 msg in
                      let unfinished, finished = split_msgs new_msgs in
                      (new_ele, (last_unfinished @ unfinished, last_finished @ finished), new_env3))
                    (ele, ([], []), last_env) msg_matched
                in
                ( last_objs @ [ new_obj ],
                  (last_msg_unfinished @ new_unfinished, last_msg_finished @ new_finished),
                  new_env2 ))
          ([], ([], []), env) objs
      in
      update_remain envro new_env (new_unfinished_msg, finished_msg @ new_finished_msg) new_objs

let update_objects envro env evt objs =
  let new_objs, (new_msg_unfinished, new_msg_finished), (new_env, new_block) = update_once envro env evt objs in
  let res_obj, res_msg, res_env = update_remain envro new_env (new_msg_unfinished, new_msg_finished) new_objs in
  (res_obj, res_msg, (res_env, new_block))

let update_objects_with_target envro env msgs objs = update_remain envro env (msgs, []) objs

let remove_objects tar xs = List.filter (fun x -> not ((unroll x).matcher tar)) xs
