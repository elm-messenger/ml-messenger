let exist_scene name scenes = Hashtbl.mem scenes name
let get_scene name scenes = Hashtbl.find_opt scenes name

let load_scene scenest param model =
  let env = model.Model.env in
  let ncenv = Base.remove_common_data env in
  let new_scene = scenest param model.runtime ncenv in
  { model with env = { env with common_data = new_scene } }

let report fmt =
  Printf.ksprintf (fun msg -> Printf.eprintf "ml-messenger: %s\n%!" msg) fmt

(* Start the target scene; keep the current one (and report why) if the target
   is not registered or its parameters do not match the registered key. *)
let load_target (target : Scene.target) scenes model =
  let name = Scene.target_name target in
  match get_scene name scenes with
  | None ->
      let registered =
        Hashtbl.to_seq_keys scenes |> List.of_seq
        |> List.sort_uniq String.compare
      in
      report
        "cannot load unknown scene %S; keeping the current scene (registered \
         scenes: %s)"
        name
        (String.concat ", " registered);
      model
  | Some (Scene.Entry (key, storage)) -> (
      let start param =
        let new_model = load_scene storage param model in
        new_model.runtime.current_scene <- name;
        new_model
      in
      match target with
      | By_name _ -> start None
      | By_key (target_key, param) -> (
          match Type.Id.provably_equal target_key.id key.id with
          | Some Equal -> start (Some param)
          | None ->
              report
                "cannot load scene %S: it was registered with a different key, \
                 so its parameters have another type; keeping the current \
                 scene"
                name;
              model))
