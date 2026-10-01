# Known issues

Open problems in `ml-messenger` that are not fixed yet, plus behavior that
looks like a bug but is intended. Line references are to the tree at the time
of writing.

## Open problems

- **Custom programs loaded as resources are not portable.**
  `load_resource_command` in `lib/ui.ml` registers a `Resources.Program_res`
  with `Regl_proto.create_regl_program key program`, so it gets the default
  shader language, `Glsl`: each host's native dialect (GLSL 3.30 core on
  desktop, GLSL ES in the browser). One shader source therefore compiles on
  only one backend. ml-regl's portable choice is `~shader_language:GlslEs100`,
  which the desktop host translates, but `Program_res` cannot ask for it, and
  no scene output message sends a raw host command. A fix needs the language
  in the resource definition, for example a `Program_res` argument that
  defaults to `GlslEs100`.

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
