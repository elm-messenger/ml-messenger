open Generalmodel

(* Helper function to reverse a list *)
let rev = List.rev

(* Filter finished messages (Parent messages) *)
let filter_finished_msg msgs =
  List.filter_map (function Parent x -> Some x | Other _ -> None) msgs

(* Filter unfinished messages (Other messages) *)
let filter_unfinished_msg msgs =
  List.filter_map (function Parent _ -> None | Other msg -> Some msg) msgs

(* Update one object in the list *)
let rec update_one last_env evt objs last_objs last_msg_unfinished
    last_msg_finished =
  match objs with
  | ele :: rest_objs ->
      let new_obj, new_msg, (new_env, block) =
        (unroll ele).update last_env evt
      in
      let finished_msg = filter_finished_msg new_msg in
      let unfinished_msg = filter_unfinished_msg new_msg in

      if block then
        ( rev rest_objs @ [ new_obj ] @ last_objs,
          ( last_msg_unfinished @ unfinished_msg,
            last_msg_finished @ finished_msg ),
          (new_env, block) )
      else
        update_one new_env evt rest_objs (new_obj :: last_objs)
          (last_msg_unfinished @ unfinished_msg)
          (last_msg_finished @ finished_msg)
  | [] ->
      (last_objs, (last_msg_unfinished, last_msg_finished), (last_env, false))

(* Update all objects once *)
let update_once env evt objs = update_one env evt (rev objs) [] [] []

(* Recursively update remaining objects *)
let rec update_remain env (unfinished_msg, finished_msg) objs =
  if unfinished_msg = [] then (objs, finished_msg, env)
  else
    let new_objs, (new_unfinished_msg, new_finished_msg), new_env =
      List.fold_left
        (fun (last_objs, (last_msg_unfinished, last_msg_finished), last_env) ele
           ->
          let msg_matched =
            List.filter_map
              (fun (tar, msg) ->
                if (unroll ele).matcher tar then Some msg else None)
              unfinished_msg
          in

          if msg_matched = [] then
            (* No need to update *)
            ( last_objs @ [ ele ],
              (last_msg_unfinished, last_msg_finished),
              last_env )
          else
            (* Need update *)
            let new_obj, (new_msg_unfinished, new_msg_finished), new_env2 =
              List.fold_left
                (fun ( last_obj2,
                       (last_msg_unfinished2, last_msg_finished2),
                       last_env2 ) msg ->
                  let new_ele, new_msgs, new_env3 =
                    (unroll last_obj2).updaterec last_env2 msg
                  in
                  let finished_msgs = filter_finished_msg new_msgs in
                  let unfinished_msgs = filter_unfinished_msg new_msgs in
                  ( new_ele,
                    ( last_msg_unfinished2 @ unfinished_msgs,
                      last_msg_finished2 @ finished_msgs ),
                    new_env3 ))
                (ele, ([], []), last_env)
                msg_matched
            in
            ( last_objs @ [ new_obj ],
              ( last_msg_unfinished @ new_msg_unfinished,
                last_msg_finished @ new_msg_finished ),
              new_env2 ))
        ([], ([], []), env)
        objs
    in
    update_remain new_env
      (new_unfinished_msg, finished_msg @ new_finished_msg)
      new_objs

(* Recursively update all the objects in the List *)
let update_objects env evt objs =
  let new_objs, (new_msg_unfinished, new_msg_finished), (new_env, new_block) =
    update_once env evt objs
  in
  let res_obj, res_msg, res_env =
    update_remain new_env (new_msg_unfinished, new_msg_finished) new_objs
  in
  (res_obj, res_msg, (res_env, new_block))

(* Recursively update all the objects in the List, but also uses target *)
let update_objects_with_target env msgs objs = update_remain env (msgs, []) objs

(* Remove all objects by target *)
let remove_objects t xs = List.filter (fun x -> not ((unroll x).matcher t)) xs
