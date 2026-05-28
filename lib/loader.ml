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
  | None -> model

