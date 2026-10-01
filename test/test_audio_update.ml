open Messenger
open Ml_regl_core

let diff state runtime =
  Regl_audio.diff_actions state (Audio.audio_tree runtime)

let assert_action_count expected actions =
  assert (List.length actions = expected)

let () =
  let runtime = Internal.empty_runtime () in
  let first = { Regl_audio.buffer_id = 1; duration = 10.0 } in
  let second = { Regl_audio.buffer_id = 2; duration = 10.0 } in
  Hashtbl.add runtime.audio_repo.audio "first" first;
  Hashtbl.add runtime.audio_repo.audio "second" second;
  Audio.play_audio runtime.audio_repo 3 "first" (Audio_base.A_once None) 0.0;
  Audio.play_audio runtime.audio_repo 4 "second" (Audio_base.A_once None) 0.0;

  let state, started = diff Regl_audio.empty_state runtime in
  assert_action_count 2 started;

  Audio.update_audio runtime.audio_repo (Audio_base.Audio_channel 3)
    (Regl_audio.scale_volume 0.5);
  let state, channel_update = diff state runtime in
  assert_action_count 1 channel_update;

  let state, unchanged = diff state runtime in
  assert_action_count 0 unchanged;

  Audio.update_audio runtime.audio_repo
    (Audio_base.Audio_name (4, "second"))
    (Regl_audio.scale_volume 0.25);
  let state, name_update = diff state runtime in
  assert_action_count 1 name_update;

  Audio.update_audio runtime.audio_repo Audio_base.All_audio
    (Regl_audio.scale_volume 0.5);
  let _, all_update = diff state runtime in
  assert_action_count 2 all_update

(* Finished sounds are dropped when they really end: at a slower rate, after
   [offset_by] applied once playing, and never for a looping sound. *)
let () =
  let runtime = Internal.empty_runtime () in
  let repo = runtime.audio_repo in
  Hashtbl.add repo.audio "s" { Regl_audio.buffer_id = 1; duration = 10.0 };
  let playing () = List.length repo.playing in
  let play opt = Audio.play_audio repo 0 "s" opt 0.0 in
  play (Audio_base.A_once (Some { rate = 0.5; start = 0. }));
  Audio.remove_finished_audio repo 15_000.;
  assert (playing () = 1);
  Audio.remove_finished_audio repo 20_001.;
  assert (playing () = 0);
  play (A_once None);
  Audio.update_audio repo (Audio_channel 0) (Regl_audio.offset_by 3_000.);
  Audio.remove_finished_audio repo 12_000.;
  assert (playing () = 1);
  Audio.remove_finished_audio repo 13_001.;
  assert (playing () = 0);
  play (A_loop (None, Some { loop_start = 0.; loop_end = 1_000. }));
  Audio.remove_finished_audio repo 1e9;
  assert (playing () = 1)
