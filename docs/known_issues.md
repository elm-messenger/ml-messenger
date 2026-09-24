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

## Message types and code generation

The example application registers every scene and component message in
`config.toml`, and `messenger_codegen` builds app-wide closed unions
(`Mgl_base.scene_msg`, `Mgl_base.Component_base.component_msg`) from them.

- **Message modules are copied, which creates duplicate types.** The codegen
  pastes the text of each message `.ml` file into `Mgl_base.Msg`
  (`codegen/messenger_codegen.ml:303`). The original module still compiles as
  e.g. `Scenes.Portable_components.Panel_msg`, but its `msg` type is
  incompatible with the copy, so users must go through
  `Mgl_base.Msg.Scenes.Portable_components.Panel_msg`.

  The copy exists to avoid a dependency cycle. Under
  `(include_subdirs qualified)`, dune treats a reference to `Scenes.X.Msg` as a
  dependency on the whole `Scenes` group. Once any `Scenes.*.Model` refers to
  `Mgl_base`, `Mgl_base` cannot refer back to a scene's message module, and
  dune reports `Dependency cycle between ... Scenes__Panel__Model ... Base`.
- **Generated code goes stale.** The rule in `test/messenger_test/dune` depends
  only on `project.toml` and `**/config.toml`. The codegen reads the message
  `.ml` files directly from the source tree, outside dune's sandbox
  (`source_project_root`, `codegen/messenger_codegen.ml:506`), so editing a
  message file does not regenerate `Mgl_base`. The fallback in
  `source_project_root` searches the whole source tree for a `project.toml`
  with identical contents, which breaks if two projects share one.
- **Type errors in message types point into
  `_build/.../mgl_base.ml`**, because the copied text has no line directives.
- **Constructor names are derived from module paths**
  (`Scenes_Portable_components_Panel_msg_Msg`,
  `codegen/messenger_codegen.ml:200`). Renaming a directory renames the
  constructors, which breaks every caller.
- **There is one component message type for the whole app.** Every component
  depends on `Mgl_base.Component_base.component_msg`, so any `config.toml`
  change recompiles all components. Any component can also be sent any other
  component's message, and every `init`/`updaterec` needs a `| _ ->` fallback.
- **Portable components need generated adapters** (`Portable_component.adapt`
  and the generated `*_component` modules). These exist only because of the
  closed union.

## Build layout

- **The example app is compiled twice.** `test/messenger_test/dune` defines the
  JS and native executables over the same modules, so every app module is
  compiled once per executable (`.main.eobjs` and `.main_desktop.eobjs`).
  `main.ml` is copied to `main_desktop.ml`, and `js_of_ocaml-ppx` is applied to
  every app module. Putting the app in a library and linking it from two small
  executables that choose `regl_js` or `regl_desktop` would compile it once.

## Example application (`test/messenger_test`)

- **Every scene drops its init message.** All ten scenes use
  `let scene _msg runtime env = Scene.abstract scene_con None runtime env`, so a
  message passed with `SOMChangeScene (Some msg, name)` never reaches `init`.
  The declared `Scenes.Portable_components.Scene_msg` is unused as a result. The
  API makes this mistake easy, because users wire the scene storage by hand.
- **The view size is hard-coded** as `1920., 1080.`
  (`scenes/components/model.ml:45`, `scenes/camera/model.ml:47`).
  `Base.get_virtual_size` now provides it.
- **Unused files in the Interaction example.** `button/init.ml`, `button/msg.ml`,
  `slider/init.ml` and `slider/msg.ml` are never used;
  `components/component_base.ml` defines the same types again.

## Runtime

- **Message routing is quadratic.** `Recursion` appends with `@ [ x ]` inside
  folds (`lib/recursion.ml:6-7, 49, 67`), so routing cost grows quadratically
  with the number of components and messages per round.
- **Global component messaging is stringly typed.** `Scene.gc_msg` and
  `Scene.gc_target` are both `string` (`lib/scene.ml:108-109`).
- **Sequential transitions update the old scene twice per event.**
  `Transition_model.init` captures the old scene in `old_vsr` for every
  transition kind (`lib/extra/transition_model.ml:27`), and `update` steps it on
  every event. Only mixed transitions read `old_vsr`, so for sequential
  transitions this doubles the old scene's update cost for nothing.
- **Two resource keys cannot share an audio URL.** `pending_audio_urls` maps a
  URL to a single key (`lib/ui.ml:51`), so the first key is never registered.
  `Data_res` keeps a list per path but registers every key on the first
  response and treats later responses for the same path as a new key
  (`lib/ui.ml:154`), so the loaded count overshoots. Before fixing either, check
  whether both backends send one load response per request.
- **Audio cleanup cannot see transforms.** `Audio.remove_finished_audio`
  derives a one-shot sound's end time from its original play options (rate and
  start offset). `Regl_audio.audio` is abstract, so an `offset_by` applied later
  through `SOMTransformAudio` is not taken into account, and the sound may be
  stopped early.
- **Values read from local storage must be polled.** `SOMReadValue`
  (`lib/ui.ml:227`) stores the result in the runtime; the scene is not sent a
  message when it arrives, so it has to call `Base.get_local_value` until the
  value appears.

## Packaging

- **The license is a placeholder.** `dune-project` has `(license LICENSE)`, so
  the generated `ml-messenger.opam` says `license: "LICENSE"`, which is not an
  SPDX identifier. The repository has no `LICENSE` file, and one needs to be
  chosen (`ml-regl` uses `BSD-3-Clause`).
