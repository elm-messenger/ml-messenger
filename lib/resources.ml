open Ml_regl_core

type resource_def =
  | Texture_res of string * Regl_proto.texture_options option
  | Audio_res of string
  | Font_res of string * string
  | Program_res of Regl_program.regl_program
  | Data_res of string

type resource_defs = (string * resource_def) list

let resource_num = List.length
let save_sprite dst name texture = Hashtbl.replace dst name texture
let iget_sprite name dst = Hashtbl.find_opt dst name
