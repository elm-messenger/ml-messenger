module StringMap = Map.Make (String)

type component = {
  kind : string;
  name : string;
  module_path : string option;
  msg : string option;
}

type scene = {
  namespace : string;
  name : string;
  module_path : string;
  msg : string option;
  components : component list;
}

type group = { namespace : string; components : component list }

type project = {
  init_scene : string;
  init_scene_msg : string option;
  resources : string;
  global_components : string;
  virtual_width : float;
  virtual_height : float;
  fbo_num : int;
  max_assets_per_frame : int;
  enabled_program : string;
  time_interval : string;
  app_name : string option;
  user_data : string;
  camera : string;
  volume : float;
}

let die fmt =
  Printf.ksprintf
    (fun msg ->
      prerr_endline msg;
      exit 1)
    fmt

let starts_with ~prefix s =
  let plen = String.length prefix in
  String.length s >= plen && String.equal (String.sub s 0 plen) prefix

let path_s path = String.concat "." path

let parse_toml file =
  match Otoml.Parser.from_file_result file with
  | Ok toml -> toml
  | Error msg -> die "%s: %s" file msg

let get_string file toml path =
  match Otoml.find_result toml Otoml.get_string path with
  | Ok value -> value
  | Error msg -> die "%s: %s" file msg

let get_string_opt file toml path =
  match Otoml.find_result toml Otoml.get_string path with
  | Ok value -> Some value
  | Error msg ->
      if Otoml.path_exists toml path then die "%s: %s" file msg else None

let get_int file toml path =
  match Otoml.find_result toml Otoml.get_integer path with
  | Ok value -> value
  | Error msg -> die "%s: %s" file msg

let get_float file toml path =
  match Otoml.find_result toml (Otoml.get_float ~strict:false) path with
  | Ok value -> value
  | Error msg -> die "%s: %s" file msg

let get_table_array file toml path =
  match Otoml.find_result toml Otoml.get_value path with
  | Ok (Otoml.TomlTableArray xs) -> xs
  | Ok (Otoml.TomlArray xs) -> xs
  | Ok _ -> die "%s: %s must be an array of tables" file (path_s path)
  | Error msg ->
      if Otoml.path_exists toml path then die "%s: %s" file msg else []

let get_project file =
  let tbl = parse_toml file in
  {
    init_scene = get_string file tbl [ "main"; "init_scene" ];
    init_scene_msg = get_string_opt file tbl [ "main"; "init_scene_msg" ];
    resources = get_string file tbl [ "main"; "resources" ];
    global_components = get_string file tbl [ "main"; "global_components" ];
    virtual_width = get_float file tbl [ "main"; "virtual_width" ];
    virtual_height = get_float file tbl [ "main"; "virtual_height" ];
    fbo_num = get_int file tbl [ "main"; "fbo_num" ];
    max_assets_per_frame = get_int file tbl [ "main"; "max_assets_per_frame" ];
    enabled_program = get_string file tbl [ "main"; "enabled_program" ];
    time_interval = get_string file tbl [ "main"; "time_interval" ];
    app_name = get_string_opt file tbl [ "main"; "app_name" ];
    user_data =
      get_string file tbl [ "main"; "default_global_data"; "user_data" ];
    camera = get_string file tbl [ "main"; "default_global_data"; "camera" ];
    volume = get_float file tbl [ "main"; "default_global_data"; "volume" ];
  }

let module_of_dir dir =
  let base = Filename.basename dir in
  let parts = String.split_on_char '_' base in
  match parts with
  | [] -> die "invalid directory name %s" dir
  | first :: rest ->
      let cap s =
        if String.equal s "" then s
        else
          String.uppercase_ascii (String.sub s 0 1)
          ^ String.sub s 1 (String.length s - 1)
      in
      String.concat "_" (cap first :: rest)

let parse_component file idx component_tbl =
  let kind = get_string file component_tbl [ "kind" ] in
  let name = get_string file component_tbl [ "name" ] in
  let module_path = get_string_opt file component_tbl [ "module" ] in
  let msg = get_string_opt file component_tbl [ "msg" ] in
  (match (kind, module_path, msg) with
  | "portable", None, _ ->
      die "%s: portable component %s missing components.%d.module" file name idx
  | "user", _, None ->
      die "%s: user component %s missing components.%d.msg" file name idx
  | "portable", Some _, _ | "user", _, Some _ -> ()
  | other, _, _ -> die "%s: unsupported component kind %s" file other);
  { kind; name; module_path; msg }

let parse_config _root file =
  let tbl = parse_toml file in
  let dir = Filename.dirname file in
  let namespace = module_of_dir dir in
  let components =
    get_table_array file tbl [ "components" ]
    |> List.mapi (parse_component file)
  in
  if Otoml.path_exists tbl [ "scene" ] then
    `Scene
      {
        namespace;
        name = get_string file tbl [ "scene"; "name" ];
        module_path = get_string file tbl [ "scene"; "module" ];
        msg = get_string_opt file tbl [ "scene"; "msg" ];
        components;
      }
  else `Group { namespace; components }

let rec list_files root =
  let entries = Sys.readdir root |> Array.to_list |> List.sort String.compare in
  List.concat_map
    (fun entry ->
      let path = Filename.concat root entry in
      if Sys.is_directory path then
        if String.equal entry "_build" || String.equal entry ".git" then []
        else list_files path
      else [ path ])
    entries

let config_files root =
  list_files root
  |> List.filter (fun path ->
      String.equal (Filename.basename path) "config.toml")

let ensure_dir path = if not (Sys.file_exists path) then Unix.mkdir path 0o755

let write_file path contents =
  let oc = open_out path in
  Fun.protect
    ~finally:(fun () -> close_out_noerr oc)
    (fun () -> output_string oc contents)

let ocaml_string s = Printf.sprintf "%S" s

let ocaml_float f =
  let s = Printf.sprintf "%.12g" f in
  if String.contains s '.' || String.contains s 'e' || String.contains s 'E'
  then s
  else s ^ "."

let portable_component_module (c : component) = c.name ^ "_component"

let require_component_module (c : component) =
  match c.module_path with
  | Some module_path -> module_path
  | None -> die "component %s missing module" c.name

let require_component_msg (c : component) =
  match c.msg with
  | Some msg -> msg
  | None -> die "component %s missing msg" c.name

let constructor_of_module_path module_path =
  String.concat "_" (String.split_on_char '.' module_path) ^ "_Msg"

let component_message_module (c : component) =
  match c.kind with
  | "portable" -> require_component_module c
  | "user" -> require_component_msg c
  | other -> die "unsupported component kind %s" other

let component_constructor c =
  constructor_of_module_path (component_message_module c)

let msg_module_parts msg =
  let parts = String.split_on_char '.' msg in
  if parts = [] || List.exists (String.equal "") parts then
    die "invalid message module path %s" msg;
  parts

let msg_type msg = "Msg." ^ msg ^ ".msg"

let read_file path =
  let ic = open_in path in
  Fun.protect
    ~finally:(fun () -> close_in_noerr ic)
    (fun () ->
      let len = in_channel_length ic in
      really_input_string ic len)

let find_msg_file root msg =
  let module_parts = msg_module_parts msg in
  let module_name = List.hd (List.rev module_parts) in
  let expected = String.uncapitalize_ascii module_name ^ ".ml" in
  let dir_parts =
    match List.rev module_parts with
    | _module_name :: rev_dirs -> List.rev rev_dirs
    | [] -> assert false
  in
  let candidate =
    List.fold_left
      (fun dir part -> Filename.concat dir (String.uncapitalize_ascii part))
      root dir_parts
    |> fun dir -> Filename.concat dir expected
  in
  if Sys.file_exists candidate then candidate
  else
    let matches =
      list_files root
      |> List.filter (fun path -> String.equal (Filename.basename path) expected)
    in
    match matches with
    | [ path ] -> path
    | [] -> die "cannot find source file for message module %s" msg
    | _ ->
        die "message module %s is ambiguous; found multiple %s files" msg expected

let enabled_program_expr = function
  | "all" -> "Messenger.Ui.AllBuiltinProgram"
  | "none" -> "Messenger.Ui.NoBuiltinProgram"
  | "text_only" -> "Messenger.Ui.TextOnlyBuiltinProgram"
  | "basic_shapes" -> "Messenger.Ui.BasicShapesBuiltinProgram"
  | other -> die "unsupported enabled_program %s" other

let time_interval_expr = function
  | "animation_frame" -> "Ml_regl_core.Regl_proto.AnimationFrame"
  | other when starts_with ~prefix:"millisecond:" other ->
      let n = String.sub other 12 (String.length other - 12) in
      Printf.sprintf "Ml_regl_core.Regl_proto.Millisecond %s" n
  | other -> die "unsupported time_interval %s" other

let app_name_expr = function
  | None -> "None"
  | Some s -> "Some " ^ ocaml_string s

let init_scene_msg_expr = function None -> "None" | Some s -> "Some " ^ s

type msg_tree = {
  source_file : string option;
  children : msg_tree StringMap.t;
}

let empty_msg_tree = { source_file = None; children = StringMap.empty }

let rec add_msg_source full_path parts source_file tree =
  match parts with
  | [] -> (
      match tree.source_file with
      | None -> { tree with source_file = Some source_file }
      | Some existing when String.equal existing source_file -> tree
      | Some _ ->
          die "message module %s is used by multiple source files" full_path)
  | part :: rest ->
      let child =
        Option.value (StringMap.find_opt part tree.children)
          ~default:empty_msg_tree
      in
      {
        tree with
        children =
          StringMap.add part
            (add_msg_source full_path rest source_file child)
            tree.children;
      }

let add_source_contents b source_file =
  let contents = read_file source_file in
  Buffer.add_string b contents;
  if String.equal contents "" || contents.[String.length contents - 1] <> '\n'
  then Buffer.add_char b '\n'

let rec add_msg_modules b indent tree =
  StringMap.iter
    (fun module_name child ->
      Buffer.add_string b
        (Printf.sprintf "%smodule %s = struct\n" indent module_name);
      Option.iter (add_source_contents b) child.source_file;
      add_msg_modules b (indent ^ "  ") child;
      Buffer.add_string b (indent ^ "end\n"))
    tree.children

let ensure_distinct_generated_names description names =
  let rec loop seen = function
    | [] -> ()
    | name :: rest ->
        if List.mem name seen then
          die "%s %s is generated more than once" description name;
        loop (name :: seen) rest
  in
  loop [] names

let base_ml root (scenes : scene list) (groups : group list) =
  let b = Buffer.create 4096 in
  let all_groups =
    List.map (fun (s : scene) -> (s.namespace, s.components)) scenes
    @ List.map (fun (g : group) -> (g.namespace, g.components)) groups
    |> List.filter (fun (_namespace, components) -> components <> [])
  in
  let all_components =
    List.concat_map (fun (_namespace, components) -> components) all_groups
  in
  ensure_distinct_generated_names "component message constructor"
    (List.map component_constructor all_components);
  let portable_components =
    List.filter (fun (c : component) -> String.equal c.kind "portable")
      all_components
  in
  ensure_distinct_generated_names "portable component helper module"
    (List.map portable_component_module portable_components);
  let scene_message_paths =
    List.filter_map (fun (scene : scene) -> scene.msg) scenes
  in
  ensure_distinct_generated_names "scene message constructor"
    (List.map constructor_of_module_path scene_message_paths);
  let message_paths =
    scene_message_paths
    @ List.filter_map
        (fun (c : component) ->
          if String.equal c.kind "user" then Some (require_component_msg c)
          else None)
        all_components
    |> List.sort_uniq String.compare
  in
  let message_tree =
    List.fold_left
      (fun tree msg ->
        add_msg_source msg (msg_module_parts msg)
          (find_msg_file root msg) tree)
      empty_msg_tree message_paths
  in
  Buffer.add_string b "(* @generated by messenger_codegen; do not edit *)\n\n";
  if message_paths <> [] then (
    Buffer.add_string b "module Msg = struct\n";
    add_msg_modules b "  " message_tree;
    Buffer.add_string b "end\n\n");
  Buffer.add_string b "type scene_msg =\n";
  Buffer.add_string b "  | NullSceneMsg\n";
  List.iter
    (fun msg ->
      Buffer.add_string b
        (Printf.sprintf "  | %s of %s\n"
           (constructor_of_module_path msg)
           (msg_type msg)))
    scene_message_paths;
  if all_components <> [] then (
    Buffer.add_string b "\nmodule Component_base = struct\n";
    Buffer.add_string b "  type component_msg =\n";
    List.iter
      (fun c ->
        let payload_type =
          match c.kind with
          | "portable" -> require_component_module c ^ ".msg"
          | "user" -> msg_type (require_component_msg c)
          | other -> die "unsupported component kind %s" other
        in
        Buffer.add_string b
          (Printf.sprintf "    | %s of %s\n" (component_constructor c)
             payload_type))
      all_components;
    List.iter
      (fun c ->
        if String.equal c.kind "portable" then (
          let con = component_constructor c in
          Buffer.add_string b
            (Printf.sprintf "\n  module %s = struct\n"
               (portable_component_module c));
          Buffer.add_string b
            (Printf.sprintf "    let wrap_msg msg = %s msg\n\n" con);
          Buffer.add_string b "    let unwrap_msg = function\n";
          Buffer.add_string b
            (Printf.sprintf "      | %s msg -> Some msg\n" con);
          if List.length all_components > 1 then
            Buffer.add_string b "      | _ -> None\n";
          Buffer.add_string b
            "\n\
            \    let component ~matcher ~map_target init_msg runtime env =\n";
          Buffer.add_string b
            "      Messenger_extra.Portable_component.adapt ~matcher ~map_target \
             ~wrap_msg\n";
          let module_path = require_component_module c in
          Buffer.add_string b
            (Printf.sprintf
               "        ~unwrap_msg %s.component init_msg runtime env\n"
               module_path);
          Buffer.add_string b "  end\n"))
      all_components;
    Buffer.add_string b "end\n");
  Buffer.contents b

let all_ml project (scenes : scene list) =
  let b = Buffer.create 4096 in
  Buffer.add_string b "(* @generated by messenger_codegen; do not edit *)\n\n";
  Buffer.add_string b "type user_data = Lib.User_data.user_data\n";
  Buffer.add_string b "type scene_msg = Mgl_base.scene_msg\n\n";
  Buffer.add_string b "let virtual_size : Messenger.Ui.size =\n";
  Buffer.add_string b
    (Printf.sprintf "  { width = %s; height = %s }\n\n"
       (ocaml_float project.virtual_width)
       (ocaml_float project.virtual_height));
  Buffer.add_string b
    "let default_global_data : user_data Messenger.Base.global_data_init =\n";
  let camera_expr =
    match project.camera with
    | "default" ->
        "Messenger.Camera.default ~width:virtual_size.width \
         ~height:virtual_size.height"
    | expr -> expr
  in
  Buffer.add_string b "  {\n";
  Buffer.add_string b (Printf.sprintf "    user_data = %s;\n" project.user_data);
  Buffer.add_string b (Printf.sprintf "    camera = %s;\n" camera_expr);
  Buffer.add_string b
    (Printf.sprintf "    volume = %s;\n" (ocaml_float project.volume));
  Buffer.add_string b "  }\n\n";
  Buffer.add_string b
    "let config : (user_data, scene_msg) Messenger.Ui.user_config =\n";
  Buffer.add_string b "  {\n";
  Buffer.add_string b
    (Printf.sprintf "    init_scene = %s;\n" (ocaml_string project.init_scene));
  Buffer.add_string b
    (Printf.sprintf "    init_scene_msg = %s;\n"
       (init_scene_msg_expr project.init_scene_msg));
  Buffer.add_string b "    virtual_size;\n";
  Buffer.add_string b (Printf.sprintf "    fbo_num = %d;\n" project.fbo_num);
  Buffer.add_string b
    (Printf.sprintf "    max_assets_per_frame = %d;\n"
       project.max_assets_per_frame);
  Buffer.add_string b
    (Printf.sprintf "    enabled_program = %s;\n"
       (enabled_program_expr project.enabled_program));
  Buffer.add_string b
    (Printf.sprintf "    time_interval = %s;\n"
       (time_interval_expr project.time_interval));
  Buffer.add_string b "    default_global_data;\n";
  Buffer.add_string b
    (Printf.sprintf "    app_name = %s;\n" (app_name_expr project.app_name));
  Buffer.add_string b "  }\n\n";
  Buffer.add_string b
    "let all_scenes : (user_data, scene_msg) Messenger.Scene.all_scenes =\n";
  Buffer.add_string b "  let tbl = Hashtbl.create 16 in\n";
  Buffer.add_string b "  List.iter\n";
  Buffer.add_string b "    (fun (name, scene) -> Hashtbl.add tbl name scene)\n";
  Buffer.add_string b "    [\n";
  List.iter
    (fun scene ->
      Buffer.add_string b
        (Printf.sprintf "      (%s, %s.scene);\n" (ocaml_string scene.name)
           scene.module_path))
    scenes;
  Buffer.add_string b "    ];\n";
  Buffer.add_string b "  tbl\n\n";
  Buffer.add_string b
    "let input : (user_data, scene_msg) Messenger.Ui.input =\n";
  Buffer.add_string b "  {\n";
  Buffer.add_string b "    config;\n";
  Buffer.add_string b (Printf.sprintf "    resources = %s;\n" project.resources);
  Buffer.add_string b "    scenes = all_scenes;\n";
  Buffer.add_string b
    (Printf.sprintf "    global_components = %s;\n" project.global_components);
  Buffer.add_string b "  }\n";
  Buffer.contents b

let rec find_workspace_root path =
  if Sys.file_exists (Filename.concat path "dune-project") then Some path
  else
    let parent = Filename.dirname path in
    if String.equal parent path then None else find_workspace_root parent

let source_project_root project_file fallback =
  (* Dune actions run in _build, where source .ml files are not staged. *)
  let cwd = Sys.getcwd () in
  let source_root =
    match Sys.getenv_opt "DUNE_SOURCEROOT" with
    | Some root -> Some root
    | None -> find_workspace_root cwd
  in
  match source_root with
  | None -> fallback
  | Some source_root ->
      let build_prefix = Filename.concat source_root "_build" ^ Filename.dir_sep in
      if starts_with ~prefix:build_prefix cwd then
        let suffix =
          String.sub cwd (String.length build_prefix)
            (String.length cwd - String.length build_prefix)
        in
        (match String.index_opt suffix Filename.dir_sep.[0] with
        | None -> source_root
        | Some slash ->
            let project_suffix =
              String.sub suffix (slash + 1) (String.length suffix - slash - 1)
            in
            Filename.concat source_root project_suffix)
      else
        let project_name = Filename.basename project_file in
        let project_contents = read_file project_file in
        let matches =
          list_files source_root
          |> List.filter (fun path ->
                 String.equal (Filename.basename path) project_name
                 && String.equal (read_file path) project_contents)
        in
        match matches with [ path ] -> Filename.dirname path | _ -> fallback

let usage () =
  die
    "usage: messenger_codegen [--root DIR | --project FILE] [--out-dir DIR] \
     [--config-files FILE ...]"

let () =
  let root_arg = ref None in
  let project_file = ref None in
  let out_dir = ref None in
  let config_files_arg = ref [] in
  let rec take_config_files files = function
    | arg :: rest when not (starts_with ~prefix:"--" arg) ->
        take_config_files (arg :: files) rest
    | rest -> (List.rev files, rest)
  in
  let rec parse = function
    | [] -> ()
    | "--" :: rest -> parse rest
    | "--root" :: value :: rest ->
        root_arg := Some value;
        parse rest
    | "--project" :: value :: rest ->
        project_file := Some value;
        parse rest
    | "--out-dir" :: value :: rest ->
        out_dir := Some value;
        parse rest
    | "--config-files" :: rest ->
        let files, rest = take_config_files [] rest in
        if files = [] then usage ();
        config_files_arg := !config_files_arg @ files;
        parse rest
    | _ -> usage ()
  in
  parse (Array.to_list Sys.argv |> List.tl);
  let out_dir = Option.value !out_dir ~default:"." in
  let project_file =
    match (!project_file, !root_arg) with
    | Some file, _ -> file
    | None, Some root -> Filename.concat root "project.toml"
    | None, None -> "project.toml"
  in
  let project_root = Filename.dirname project_file in
  let source_root = source_project_root project_file project_root in
  let project = get_project project_file in
  let scene_config_files =
    match !config_files_arg with
    | [] ->
        let files = config_files project_root in
        if files = [] then config_files source_root else files
    | files -> files
  in
  let scenes, groups =
    scene_config_files
    |> List.map (parse_config source_root)
    |> List.fold_left
         (fun (scenes, groups) -> function
           | `Scene scene -> (scene :: scenes, groups)
           | `Group group -> (scenes, group :: groups))
         ([], [])
  in
  let scenes = List.sort (fun a b -> String.compare a.name b.name) scenes in
  let groups =
    List.sort (fun a b -> String.compare a.namespace b.namespace) groups
  in
  ensure_dir out_dir;
  write_file (Filename.concat out_dir "mgl_base.ml")
    (base_ml source_root scenes groups);
  write_file (Filename.concat out_dir "mgl_all.ml") (all_ml project scenes)
