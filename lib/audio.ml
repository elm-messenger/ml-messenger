open Ml_regl_core

let new_audio_channel (runtime : Internal.runtime) =
  runtime.audio_repo.playing
  |> List.map (fun (p : Internal.playing_audio) -> p.channel)
  |> List.fold_left max (-1) |> ( + ) 1

let audio_duration (runtime : Internal.runtime) name =
  match Hashtbl.find_opt runtime.audio_repo.audio name with
  | None -> None
  | Some src -> Some (Regl_audio.length src)

let config_of_option = function
  | Audio_base.A_once common ->
      let c = Regl_audio.default_config in
      let common =
        Option.value common ~default:Audio_base.default_common_option
      in
      Some
        {
          c with
          playback_rate = common.rate;
          start_at = common.start;
          loop = None;
        }
  | A_loop (common, loop) ->
      let c = Regl_audio.default_config in
      let common =
        Option.value common ~default:Audio_base.default_common_option
      in
      Some { c with playback_rate = common.rate; start_at = common.start; loop }

let is_loop = function Audio_base.A_loop _ -> true | A_once _ -> false

let remove_finished_audio (repo : Internal.audio_repo) now =
  repo.playing <-
    List.filter
      (fun (pa : Internal.playing_audio) ->
        is_loop pa.opt
        ||
        match Hashtbl.find_opt repo.audio pa.name with
        | None -> false
        | Some src -> now -. pa.start_time < Regl_audio.length src *. 1000.)
      repo.playing

let play_audio (repo : Internal.audio_repo) channel name opt now =
  remove_finished_audio repo now;
  match Hashtbl.find_opt repo.audio name with
  | None -> ()
  | Some source ->
      repo.playing <-
        { Internal.channel; name; source; opt; start_time = now }
        :: repo.playing

let stop_audio (repo : Internal.audio_repo) now target =
  remove_finished_audio repo now;
  repo.playing <-
    List.filter
      (fun (pa : Internal.playing_audio) ->
        not
          (match target with
          | Audio_base.All_audio -> true
          | Audio_channel c -> pa.channel = c
          | Audio_name (c, name) -> pa.channel = c && pa.name = name))
      repo.playing

let update_audio (_repo : Internal.audio_repo)
    (_target : Audio_base.audio_target)
    (_f : Regl_audio.audio -> Regl_audio.audio) =
  ()

let audio_tree (runtime : Internal.runtime) =
  remove_finished_audio runtime.audio_repo runtime.current_timestamp;
  runtime.audio_repo.playing
  |> List.map (fun (pa : Internal.playing_audio) ->
      match config_of_option pa.opt with
      | None -> Regl_audio.audio pa.source pa.start_time
      | Some config -> Regl_audio.audio ~config pa.source pa.start_time)
  |> Regl_audio.group
  |> Regl_audio.scale_volume runtime.volume
