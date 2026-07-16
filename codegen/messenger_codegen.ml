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
      if Sys.is_directory path then list_files path else [ path ])
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

let scene_constructor (scene : scene) = scene.namespace ^ "Msg"
let component_constructor (c : component) = c.name ^ "Msg"
let portable_component_module (c : component) = c.name ^ "_component"

let require_component_module (c : component) =
  match c.module_path with
  | Some module_path -> module_path
  | None -> die "component %s missing module" c.name

let require_component_msg (c : component) =
  match c.msg with
  | Some msg -> msg
  | None -> die "component %s missing msg" c.name

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

let base_ml (scenes : scene list) (groups : group list) =
  let b = Buffer.create 4096 in
  Buffer.add_string b "(* @generated by messenger_codegen; do not edit *)\n\n";
  Buffer.add_string b "type scene_msg =\n";
  Buffer.add_string b "  | NullSceneMsg\n";
  List.iter
    (fun (scene : scene) ->
      match scene.msg with
      | None -> ()
      | Some msg ->
          Buffer.add_string b
            (Printf.sprintf "  | %s of %s\n" (scene_constructor scene) msg))
    scenes;
  Buffer.add_string b "\nmodule Components = struct\n";
  let all_groups =
    List.map (fun (s : scene) -> (s.namespace, s.components)) scenes
    @ List.map (fun (g : group) -> (g.namespace, g.components)) groups
    |> List.filter (fun (_namespace, components) -> components <> [])
  in
  List.iter
    (fun (namespace, components) ->
      Buffer.add_string b (Printf.sprintf "  module %s = struct\n" namespace);
      Buffer.add_string b "    module Component_base = struct\n";
      Buffer.add_string b "      type component_msg =\n";
      List.iter
        (fun c ->
          let msg_type =
            match c.kind with
            | "portable" -> require_component_module c ^ ".msg"
            | "user" -> require_component_msg c
            | other -> die "unsupported component kind %s" other
          in
          Buffer.add_string b
            (Printf.sprintf "        | %s of %s\n" (component_constructor c)
               msg_type))
        components;
      List.iter
        (fun c ->
          if String.equal c.kind "portable" then (
            let con = component_constructor c in
            Buffer.add_string b
              (Printf.sprintf "\n      module %s = struct\n"
                 (portable_component_module c));
            Buffer.add_string b
              (Printf.sprintf "        let wrap_msg msg = %s msg\n\n" con);
            Buffer.add_string b "        let unwrap_msg = function\n";
            Buffer.add_string b
              (Printf.sprintf "          | %s msg -> Some msg\n" con);
            if List.length components > 1 then
              Buffer.add_string b "          | _ -> None\n";
            Buffer.add_string b
              "\n\
              \        let component ~target ~map_target init_msg runtime env =\n";
            Buffer.add_string b
              "          Messenger_extra.Portable_component.adapt ~target \
               ~map_target ~wrap_msg\n";
            let module_path = require_component_module c in
            Buffer.add_string b
              (Printf.sprintf
                 "            ~unwrap_msg %s.component init_msg runtime env\n"
                 module_path);
            Buffer.add_string b "      end\n"))
        components;
      Buffer.add_string b "    end\n";
      Buffer.add_string b "  end\n")
    all_groups;
  Buffer.add_string b "end\n";
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

let usage () = die "usage: messenger_codegen --root DIR --out-dir DIR"

let mgl_ml =
  "(* @generated by messenger_codegen; do not edit *)\n\n\
   module Base = Mgl_base\n\
   module All = Mgl_all\n"

let () =
  let root = ref None in
  let out_dir = ref None in
  let rec parse = function
    | [] -> ()
    | "--" :: rest -> parse rest
    | "--root" :: value :: rest ->
        root := Some value;
        parse rest
    | "--out-dir" :: value :: rest ->
        out_dir := Some value;
        parse rest
    | _ -> usage ()
  in
  parse (Array.to_list Sys.argv |> List.tl);
  let root = match !root with Some value -> value | None -> usage () in
  let out_dir = match !out_dir with Some value -> value | None -> usage () in
  let project_file = Filename.concat root "project.toml" in
  let project = get_project project_file in
  let scenes, groups =
    config_files root
    |> List.map (parse_config root)
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
  write_file (Filename.concat out_dir "mgl_base.ml") (base_ml scenes groups);
  write_file (Filename.concat out_dir "mgl_all.ml") (all_ml project scenes);
  write_file (Filename.concat out_dir "mgl.ml") mgl_ml
