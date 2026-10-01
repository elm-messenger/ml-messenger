# Known issues

Open problems in `ml-messenger` that are not fixed yet, plus behavior that
looks like a bug but is intended. Line references are to the tree at the time
of writing.

## Intended behavior

- **A failed asset load blocks the loading screen forever.** Load failures
  (`REGLTextureLoadFail`, `AudioLoadFailed`, ...) are not counted as progress in
  `lib/ui.ml`, so `Messenger_extra.Asset_loading` never reaches
  `loaded >= total`. A missing asset is a packaging error, and a stuck loading
  screen makes it visible.
- **Input order and draw order are independent.** `Recursion.update_objects`
  dispatches events from the end of the component list to the front, while
  `Component.view_components` draws by z-index. List order decides who gets
  input first; z-index only decides drawing.

## Runtime

- **Global component messaging is stringly typed.** `Scene.gc_msg` and
  `Scene.gc_target` are both `string` (`lib/scene.ml:107-108`).
- **Sequential transitions update the old scene twice per event.**
  `Transition_model.init` captures the old scene in `old_vsr` for every
  transition kind (`lib/extra/transition_model.ml:26`), and `update` steps it on
  every event. Only mixed transitions read `old_vsr`, so for sequential
  transitions this doubles the old scene's update cost for nothing.
- **Two resource keys cannot share an audio URL.** `pending_audio_urls` maps a
  URL to a single key (`lib/ui.ml:50`), so the first key is never registered.
  `Data_res` keeps a list per path but registers every key on the first
  response and treats later responses for the same path as a new key
  (`lib/ui.ml:150`), so the loaded count overshoots. Before fixing either, check
  whether both backends send one load response per request.
- **Audio cleanup cannot see transforms.** `Audio.remove_finished_audio`
  derives a one-shot sound's end time from its original play options (rate and
  start offset). `Regl_audio.audio` is abstract, so an `offset_by` applied later
  through `SOMTransformAudio` is not taken into account, and the sound may be
  stopped early.
- **Values read from local storage must be polled.** `SOMReadValue`
  (`lib/ui.ml:223`) stores the result in the runtime; the scene is not sent a
  message when it arrives, so it has to call `Base.get_local_value` until the
  value appears.
