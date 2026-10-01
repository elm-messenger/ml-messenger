open Messenger

type event = Ping
type tar = Id of int
type msg = Inc
type som = Done
type data = { id : int; value : int }

let component id =
  let con : (_, _, _, _, _, _, _, _, _) General_model.concrete_general_model =
    {
      init = (fun () () _ -> ({ id; value = 0 }, ()));
      update =
        (fun () () Ping data bdata ->
          ((data, bdata), [ General_model.Other (Id id, Inc) ], ((), false)));
      updaterec =
        (fun () () Inc data bdata ->
          ( ({ data with value = data.value + 1 }, bdata),
            [ General_model.Parent (SOMMsg Done) ],
            () ));
      view = (fun () () data () -> data.value);
      targets = (fun data () -> [ Id data.id ]);
    }
  in
  General_model.abstract con Inc () ()

let () =
  let objs, msgs, (_env, block) =
    Recursion.update_objects () () Ping [ component 1; component 2 ]
  in
  assert (not block);
  assert (List.length msgs = 2);
  let values =
    List.map (fun obj -> (General_model.unroll obj).view () ()) objs
  in
  assert (values = [ 1; 1 ])

(* Randomized comparison with a reference implementation of the routing
   semantics (the original algorithm, written for clarity, not speed). Covers
   children with several and duplicate targets, broadcast targets, rounds below
   and above the index threshold, blocking, and the order the env is threaded
   in. *)

module Reference = struct
  let answers obj tar = List.mem tar ((General_model.unroll obj).targets ())

  let split msgs =
    List.fold_left
      (fun (targeted, finished) -> function
        | General_model.Parent x -> (targeted, finished @ [ x ])
        | Other (tar, msg) -> (targeted @ [ (tar, msg) ], finished))
      ([], []) msgs

  let rec remain env targeted finished objs =
    match targeted with
    | [] -> (objs, finished, env)
    | _ ->
        let objs, (targeted', finished'), env =
          List.fold_left
            (fun (done_objs, (t_acc, f_acc), env) obj ->
              let msgs =
                List.filter_map
                  (fun (tar, msg) -> if answers obj tar then Some msg else None)
                  targeted
              in
              let obj, t_acc, f_acc, env =
                List.fold_left
                  (fun (obj, t_acc, f_acc, env) msg ->
                    let obj, out, env =
                      (General_model.unroll obj).updaterec () env msg
                    in
                    let t, f = split out in
                    (obj, t_acc @ t, f_acc @ f, env))
                  (obj, t_acc, f_acc, env) msgs
              in
              (done_objs @ [ obj ], (t_acc, f_acc), env))
            ([], ([], []), env)
            objs
        in
        remain env targeted' (finished @ finished') objs

  let update env evt objs =
    let rec visit env pending visited targeted finished =
      match pending with
      | [] -> (visited, targeted, finished, (env, false))
      | obj :: rest ->
          let obj, out, (env, block) =
            (General_model.unroll obj).update () env evt
          in
          let t, f = split out in
          if block then
            ( List.rev rest @ (obj :: visited),
              targeted @ t,
              finished @ f,
              (env, true) )
          else visit env rest (obj :: visited) (targeted @ t) (finished @ f)
    in
    let objs, targeted, finished, (env, block) =
      visit env (List.rev objs) [] [] []
    in
    let objs, finished, env = remain env targeted finished objs in
    (objs, finished, (env, block))
end

type rtar = Rid of int | Group of int
type rdata = { rid : int; log : int list }

(* A message is [depth * 1000 + tag]: [depth] bounds how far it propagates and
   distinct tags make delivery order observable. *)
let random_model ~n ~rnd ~block_on rid =
  let pick a b = rnd.(((a * 31) + b) land max_int mod Array.length rnd) in
  let target k = if k mod 4 = 0 then Group (k mod 3) else Rid (k mod (n + 2)) in
  let con : (_, _, _, _, _, _, _, _, _) General_model.concrete_general_model =
    {
      init = (fun () _ _ -> ({ rid; log = [] }, ()));
      update =
        (fun () env evt data () ->
          let out =
            List.init
              (pick rid evt mod 7)
              (fun j ->
                if pick rid (j + 11) mod 3 = 0 then
                  General_model.Parent (OtherMsg ((rid * 100) + j))
                else
                  General_model.Other
                    (target (pick rid (j + evt)), 4000 + (rid * 10) + j))
          in
          ((data, ()), out, ((env * 31) + rid, evt = block_on)));
      updaterec =
        (fun () env msg data () ->
          let depth = msg / 1000 in
          let out =
            if depth <= 0 then [ General_model.Parent (OtherMsg (-msg)) ]
            else
              List.init
                (pick rid msg mod 4)
                (fun j ->
                  General_model.Other
                    ( target (pick (rid + j) msg),
                      ((depth - 1) * 1000)
                      + (((rid * 37) + (j * 7) + msg) mod 1000) ))
          in
          (({ data with log = msg :: data.log }, ()), out, (env * 17) + msg));
      view = (fun () _ data () -> (data.rid, data.log));
      targets =
        (fun data () ->
          match pick data.rid 99 mod 3 with
          | 0 -> [ Rid data.rid ]
          | 1 -> [ Rid data.rid; Group (data.rid mod 3) ]
          | _ -> [ Group (data.rid mod 3); Rid data.rid; Rid data.rid ]);
    }
  in
  General_model.abstract con 0 () 0

let () =
  let st = Random.State.make [| 2026 |] in
  let views objs =
    List.map (fun obj -> (General_model.unroll obj).view () 0) objs
  in
  for _ = 1 to 3000 do
    let n = 1 + Random.State.int st 20 in
    let rnd = Array.init 97 (fun _ -> Random.State.int st 1000) in
    let block_on = if Random.State.bool st then Random.State.int st 3 else -1 in
    let objs = List.init n (random_model ~n ~rnd ~block_on) in
    let evt = Random.State.int st 3 in
    let o1, m1, e1 = Reference.update 7 evt objs in
    let o2, m2, e2 = Recursion.update_objects () 7 evt objs in
    assert (views o1 = views o2 && m1 = m2 && e1 = e2);
    let targeted =
      List.init (Random.State.int st 20) (fun i ->
          ( (if i mod 5 = 0 then Group (i mod 3)
             else Rid (Random.State.int st (n + 2))),
            3000 + i ))
    in
    let o1, m1, e1 = Reference.remain 7 targeted [] objs in
    let o2, m2, e2 = Recursion.update_objects_with_target () 7 targeted objs in
    assert (views o1 = views o2 && m1 = m2 && e1 = e2);
    let gone = Group (Random.State.int st 3) in
    assert (
      views (Recursion.remove_objects gone objs)
      = views (List.filter (fun o -> not (Reference.answers o gone)) objs))
  done
