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
      let common =
        Option.value common ~default:Audio_base.default_common_option
      in
      Some
        {
          Regl_audio.playback_rate = common.rate;
          start_at = common.start;
          loop = None;
        }
  | A_loop (common, loop) ->
      let common =
        Option.value common ~default:Audio_base.default_common_option
      in
      Some
        {
          Regl_audio.playback_rate = common.rate;
          start_at = common.start;
          loop;
        }

let is_loop = function Audio_base.A_loop _ -> true | A_once _ -> false

(* Wall-clock play time in ms of a one-shot sound, accounting for its start
   offset and playback rate; [None] if it never ends on its own. *)
let once_duration src = function
  | Audio_base.A_loop _ -> None
  | A_once common ->
      let common =
        Option.value common ~default:Audio_base.default_common_option
      in
      let remaining =
        Float.max 0. ((Regl_audio.length src *. 1000.) -. common.start)
      in
      if common.rate > 0. then Some (remaining /. common.rate) else None

let remove_finished_audio (repo : Internal.audio_repo) now =
  repo.playing <-
    List.filter
      (fun (pa : Internal.playing_audio) ->
        is_loop pa.opt
        ||
        match Hashtbl.find_opt repo.audio pa.name with
        | None -> false
        | Some src -> (
            match once_duration src pa.opt with
            | None -> true
            | Some duration -> now -. pa.start_time < duration))
      repo.playing

let play_audio (repo : Internal.audio_repo) channel name opt now =
  remove_finished_audio repo now;
  match Hashtbl.find_opt repo.audio name with
  | None -> ()
  | Some source ->
      let audio =
        match config_of_option opt with
        | None -> Regl_audio.audio source now
        | Some config -> Regl_audio.audio ~config source now
      in
      repo.playing <-
        { Internal.channel; name; source; audio; opt; start_time = now }
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

let update_audio (repo : Internal.audio_repo) target f =
  repo.playing <-
    List.map
      (fun (pa : Internal.playing_audio) ->
        let matches =
          match target with
          | Audio_base.All_audio -> true
          | Audio_channel c -> pa.channel = c
          | Audio_name (c, name) -> pa.channel = c && pa.name = name
        in
        if matches then { pa with audio = f pa.audio } else pa)
      repo.playing

let audio_tree (runtime : Internal.runtime) =
  remove_finished_audio runtime.audio_repo runtime.current_timestamp;
  runtime.audio_repo.playing
  |> List.map (fun (pa : Internal.playing_audio) -> pa.audio)
  |> Regl_audio.group
  |> Regl_audio.scale_volume runtime.volume
