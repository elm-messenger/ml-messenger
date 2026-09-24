let exist_scene name scenes = Hashtbl.mem scenes name
let get_scene name scenes = Hashtbl.find_opt scenes name

let load_scene scenest smsg model =
  let env = model.Model.env in
  let ncenv = Base.remove_common_data env in
  let new_scene = scenest smsg model.runtime ncenv in
  { model with env = { env with common_data = new_scene } }

let load_scene_by_name name scenes smsg model =
  match get_scene name scenes with
  | Some scenest ->
      let new_model = load_scene scenest smsg model in
      new_model.runtime.current_scene <- name;
      new_model
  | None ->
      let registered =
        Hashtbl.to_seq_keys scenes |> List.of_seq
        |> List.sort_uniq String.compare
      in
      Printf.eprintf
        "ml-messenger: cannot load unknown scene %S; keeping the current scene \
         (registered scenes: %s)\n\
         %!"
        name
        (String.concat ", " registered);
      model
