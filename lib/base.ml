type runtime = Internal.runtime

type 'userdata global_data_init = { user_data : 'userdata; camera : Camera.t; volume : float }

type 'userdata global_data = { user_data : 'userdata; camera : Camera.t }

type ('common, 'userdata) env = { global_data : 'userdata global_data; common_data : 'common }

type flags = { time_stamp : float; info : string }

let remove_common_data env = { global_data = env.global_data; common_data = () }
let add_common_data common_data env = { global_data = env.global_data; common_data }

let global_data_of_init (g : 'a global_data_init) : 'a global_data = { user_data = g.user_data; camera = g.camera }

let get_scene_start_time r = r.Internal.scene_start_time
let get_global_start_time r = r.Internal.global_start_time
let get_global_start_frame r = r.Internal.global_start_frame
let get_scene_start_frame r = r.Internal.scene_start_frame
let get_current_timestamp r = r.Internal.current_timestamp
let get_delta_time r = r.Internal.last_frame_delta
let get_mouse_pos r = r.Internal.mouse_pos
let get_pressed_mouse_buttons r = r.Internal.pressed_mouse_buttons
let get_pressed_keys r = r.Internal.pressed_keys
let get_volume r = r.Internal.volume
let get_current_scene r = r.Internal.current_scene
let get_loading_progress r = (r.Internal.loaded_res_num, r.Internal.tot_res_num)
let get_fonts r = r.Internal.fonts
let get_programs r = r.Internal.programs
let get_sprite name r = Hashtbl.find_opt r.Internal.sprites name
let get_all_sprites r = r.Internal.sprites
let get_config_data key r = Hashtbl.find_opt r.Internal.config_data key
let get_local_value key r = Hashtbl.find_opt r.Internal.local_values key
