open Ml_regl_core

type resource_def =
  | Texture_res of string * Regl_proto.texture_options option
  | Audio_res of string
  | Font_res of string * string
  | Program_res of Regl_program.regl_program * Regl_proto.shader_language
      (** [GlslEs100] works on both hosts (the desktop host translates it);
          [Glsl] is each host's native dialect. *)
  | Data_res of string

type resource_defs = (string * resource_def) list

(* Loads a resource takes: a font is its atlas and its metrics (the JSON, read
   again for Base.measure_text). *)
let load_count = function Font_res _ -> 2 | _ -> 1

let resource_num defs =
  List.fold_left (fun n (_, def) -> n + load_count def) 0 defs

let save_sprite dst name texture = Hashtbl.replace dst name texture
let iget_sprite name dst = Hashtbl.find_opt dst name
