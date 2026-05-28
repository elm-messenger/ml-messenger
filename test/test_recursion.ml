open Messenger

type event = Ping
type tar = Id of int
type msg = Inc
type som = Done

type data = { id : int; value : int }
type bdata = unit

let component id =
  let con : (_, _, _, _, _, _, _, _, _) General_model.concrete_general_model =
    {
      init = (fun () () _ -> ({ id; value = 0 }, ()));
      update =
        (fun () () Ping data bdata ->
          ((data, bdata), [ General_model.Other (Id id, Inc) ], ((), false)));
      updaterec =
        (fun () () Inc data bdata ->
          (({ data with value = data.value + 1 }, bdata), [ General_model.Parent (SOMMsg Done) ], ()));
      view = (fun () () data () -> data.value);
      matcher = (fun data () (Id id) -> data.id = id);
    }
  in
  General_model.abstract con Inc () ()

let () =
  let objs, msgs, (_env, block) = Recursion.update_objects () () Ping [ component 1; component 2 ] in
  assert (not block);
  assert (List.length msgs = 2);
  let values = List.map (fun obj -> (General_model.unroll obj).view () ()) objs in
  assert (values = [ 1; 1 ])
