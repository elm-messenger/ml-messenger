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
