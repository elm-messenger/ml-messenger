type runtime = Internal.runtime

type 'userdata global_data_init = {
  user_data : 'userdata;
  camera : Camera.t;
  volume : float;
}

type 'userdata global_data = { user_data : 'userdata; camera : Camera.t }

type ('common, 'userdata) env = {
  global_data : 'userdata global_data;
  common_data : 'common;
}

type flags = { time_stamp : float; info : string }

let remove_common_data env = { global_data = env.global_data; common_data = () }

let add_common_data common_data env =
  { global_data = env.global_data; common_data }

let global_data_of_init (g : 'a global_data_init) : 'a global_data =
  { user_data = g.user_data; camera = g.camera }

let get_current_timestamp r = r.Internal.current_timestamp
let get_mouse_pos r = r.Internal.mouse_pos
let get_pressed_mouse_buttons r = r.Internal.pressed_mouse_buttons
let get_pressed_keys r = r.Internal.pressed_keys
let get_volume r = r.Internal.volume

(** A loaded font's metrics, by its resource name. *)
let get_font_metrics name r = Hashtbl.find_opt r.Internal.font_metrics name

(** Lay [text] out as a textbox with the same options would (see
    [Ml_regl_core.Regl_text.measure]); [None] until every font in [fonts] has
    loaded. *)
let measure_text ?letter_spacing ?word_spacing ?tab_size ?line_height ?width
    ?word_break ~fonts ~size text r =
  let metrics = List.map (fun name -> get_font_metrics name r) fonts in
  if fonts = [] || List.exists Option.is_none metrics then None
  else
    Some
      (Ml_regl_core.Regl_text.measure ?letter_spacing ?word_spacing ?tab_size
         ?line_height ?width ?word_break
         (List.filter_map Fun.id metrics)
         size text)

(** [measure_text] for a [textbox_pro] option. *)
let measure_textbox opt r =
  Ml_regl_core.Regl_text.measure_textbox
    (fun name -> get_font_metrics name r)
    opt

let get_current_scene r = r.Internal.current_scene
let get_virtual_size r = r.Internal.virtual_size
let get_max_assets_per_frame r = r.Internal.max_assets_per_frame
let get_loading_progress r = (r.Internal.loaded_res_num, r.Internal.tot_res_num)
let get_fonts r = r.Internal.fonts
let get_programs r = r.Internal.programs
let get_sprite name r = Hashtbl.find_opt r.Internal.sprites name
let get_all_sprites r = r.Internal.sprites
let get_config_data key r = Hashtbl.find_opt r.Internal.config_data key
let get_local_value key r = Hashtbl.find_opt r.Internal.local_values key
