type audio_common_option = { rate : float; start : float }

type audio_target = All_audio | Audio_channel of int | Audio_name of int * string

type audio_option = A_loop of audio_common_option option * Ml_regl_core.Regl_audio.loop option | A_once of audio_common_option option

let default_common_option = { rate = 1.; start = 0. }
