open Ml_regl_core
module StringSet = Set.Make (String)
module IntSet = Set.Make (Int)

type playing_audio = {
  channel : int;
  name : string;
  source : Regl_audio.source;
  opt : Audio_base.audio_option;
  start_time : float;
}

type audio_repo = {
  audio : (string, Regl_audio.source) Hashtbl.t;
  mutable playing : playing_audio list;
}

type runtime = {
  sprites : (string, Regl_proto.texture) Hashtbl.t;
  mutable loaded_res_num : int;
  mutable tot_res_num : int;
  mutable startup_failed : string list;
  mutable fonts : StringSet.t;
  mutable programs : StringSet.t;
  audio_repo : audio_repo;
  config_data : (string, string) Hashtbl.t;
  local_values : (string, string) Hashtbl.t;
  pending_data_paths : (string, string list) Hashtbl.t;
  pending_audio_urls : (string, string) Hashtbl.t;
  mutable current_timestamp : float;
  mutable pressed_mouse_buttons : IntSet.t;
  mutable pressed_keys : StringSet.t;
  mutable mouse_pos : float * float;
  mutable volume : float;
  mutable current_scene : string;
}

let empty_audio_repo () = { audio = Hashtbl.create 16; playing = [] }

let empty_runtime () =
  {
    sprites = Hashtbl.create 16;
    loaded_res_num = 0;
    tot_res_num = 0;
    startup_failed = [];
    fonts = StringSet.empty;
    programs = StringSet.empty;
    audio_repo = empty_audio_repo ();
    config_data = Hashtbl.create 16;
    local_values = Hashtbl.create 16;
    pending_data_paths = Hashtbl.create 16;
    pending_audio_urls = Hashtbl.create 16;
    current_timestamp = 0.;
    pressed_mouse_buttons = IntSet.empty;
    pressed_keys = StringSet.empty;
    mouse_pos = (0., 0.);
    volume = 1.;
    current_scene = "";
  }
