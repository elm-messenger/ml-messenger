open Messenger

(* A layer is a component with subcomponents. [msg] is what it tells the scene;
   [child_msg] is the union of its own children. *)
type msg = Rect_clicked of int
type child_msg = Rect of Rect.Model.msg

let rect = Component.port (fun msg -> Rect msg) (fun (Rect msg) -> Some msg)

type init = { target : string; z_index : int; rects : Rect.Model.init list }

type data = {
  init : init;
  children :
    (unit, Lib.User_data.user_data, int, child_msg, unit) Component.t list;
}

let init runtime env (init : init) =
  {
    init;
    children =
      List.map
        (fun r -> Component.make rect Rect.Model.component r runtime env)
        init.rects;
  }

let update runtime env evnt data =
  let children, msgs, soms, (env, block) =
    Component.update_children runtime env evnt data.children
  in
  let reports =
    List.filter_map
      (function
        | Rect (Clicked id) -> Some (Component.Parent (Rect_clicked id))
        | Rect (Paint _) -> None)
      msgs
  in
  ( { data with children },
    reports @ List.map (fun som -> Component.Som som) soms,
    (env, block) )

let updaterec _runtime env _msg data = (data, [], env)

let view runtime env data =
  (Component.view_components runtime env data.children, data.init.z_index)

let component =
  {
    Component.init;
    update;
    updaterec;
    view;
    matcher = (fun data target -> String.equal target data.init.target);
  }
