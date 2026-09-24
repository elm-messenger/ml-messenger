# AGENTS.md

## Purpose and scope

`ml-messenger` is the backend-neutral, Elm-style game framework. It owns scene
and component state, typed message routing, resource orchestration, global
components, camera application, and the application configuration layer.

The player/rendering backend is the sibling repository `../ml-regl`. Read it
before changing backend-facing behavior. In particular:

- `../ml-regl/lib/` (`Ml_regl_core`) owns renderables, built-in programs,
  effects/compositors, audio descriptions, protobuf encoding, and the shared
  runtime state machine.
- `../ml-regl/lib/backend/shared/` defines the virtual `Regl_backend` entry
  point.
- `../ml-regl/lib/backend/js/` and `../ml-regl/ml-regl-js/` implement the
  Js_of_ocaml/WebGL host.
- `../ml-regl/lib/backend/desktop/` and
  `../ml-regl/declgl-desktop/` implement the OCaml-to-C++ SDL3/OpenGL host.
- `../ml-regl/lib/proto/` is the canonical protocol schema submodule. Protocol
  changes must stay compatible across the OCaml core and both hosts.

Keep application/framework logic here. Put rendering primitives, wire-format
types, runtime transport, or host-specific behavior in `ml-regl`. Do not add
JS or desktop branches to the portable framework just to work around a host.

## Repository map

- `lib/general_model.ml`: existential model wrapper used by components and
  global components.
- `lib/recursion.ml`: event traversal and recursive targeted-message routing.
- `lib/component.ml`: typed user components, z-order rendering helpers, and
  component update adapters.
- `lib/scene.ml`: scene abstraction, scene output messages, and global
  component types.
- `lib/ui.ml`: top-level init/update/view pipeline and the only call to
  `Regl_backend.create_app`.
- `lib/internal.ml`, `lib/model.ml`, `lib/base.ml`: runtime caches/input state,
  application model, and public environment accessors.
- `lib/resources.ml`, `lib/audio.ml`, `lib/camera.ml`: framework services over
  `Ml_regl_core`.
- `lib/extra/`: optional helpers published as `Messenger_extra`, including
  portable components, transitions, FPS, and asset loading.
- `codegen/messenger_codegen.ml`: TOML-driven generator for application scene
  and component message plumbing.
- `test/test_recursion.ml`: fast non-GUI unit test run by `dune runtest`.
- `test/test.ml`: minimal cross-backend compilation/smoke application.
- `test/messenger_test/`: full example application and primary integration
  fixture for scenes, components, resources, audio, camera, and transitions.
- `docs/main.typ` and `docs/architecture.png`: architecture documentation.
- `docs/known_issues.md`: open problems and intended-but-surprising behavior;
  update it when fixing or finding one.

The `messenger` library is published as `ml-messenger` and is available to
consumers as the wrapped `Messenger` module. `lib/extra` is the separate
wrapped `Messenger_extra` library, published as `ml-messenger.extra`;
applications using portable components, transitions, or other helpers must
list it in their Dune `libraries`. There are intentionally few `.mli` files,
so a new top-level binding can become public API; avoid accidental API growth.

## Core invariants

- Treat scene/component updates as functional state transitions. Thread the
  returned environment through every update; do not discard a child's or
  global component's updated environment.
- `General_model.Other (target, msg)` is routed to every matching model.
  `General_model.Parent (OtherMsg msg)` bubbles a normal message to the parent,
  while `Parent (SOMMsg som)` bubbles a `Scene.scene_output_msg` to the top-level
  handler.
- `Recursion.update_objects` updates from the end of the model list toward the
  front. A returned `block = true` stops the remaining event traversal. Keep
  this ordering when changing input dispatch or z-order behavior.
- Targeted messages are processed until none remain. Never create an
  unconditional target-message cycle; it will make the recursive dispatcher
  fail to terminate.
- The outer `Base.env.common_data` holds the active scene for global
  components. Scenes receive `Base.remove_common_data env`; composite scenes
  add their own common data before calling children and remove it afterward.
- Global components run before the active scene and may block its update. In
  the view pipeline, their post-processors wrap the scene before the camera is
  applied, and their own views are then drawn as overlays.
- `Internal.runtime` is deliberately mutable for input state and loaded asset
  caches. Keep that mutation inside runtime/service code and expose it through
  `Base` helpers where possible.
- Application code ends at `Ui.gen_main`. The selected Dune library
  (`regl_js` or `regl_desktop`) supplies the virtual `Regl_backend`
  implementation; application source should remain identical.

## Generated application code

The example app uses `(include_subdirs qualified)` and generates
`mgl_base.ml` and `mgl_all.ml` from `project.toml` plus recursively discovered
`config.toml` files. The Dune rule in `test/messenger_test/dune` runs
`messenger_codegen` automatically.

- Never hand-edit `mgl_base.ml` or `mgl_all.ml`; they begin with an
  `@generated` marker and live under `_build`.
- Put project-wide defaults, resources, initial scene, and global components
  in `project.toml`. `[main] user_data_type` names the user data type
  (default `Lib.User_data.user_data`).
- Put scene registration and component declarations in the nearest
  `config.toml`. Scene and message module paths are qualified OCaml paths.
- A `portable` component requires `module`; a `user` component requires `msg`.
  Generated constructor names are derived from full module paths and must be
  unique.
- Message source modules are folded into generated `Mgl_base.Msg`; edit the
  original message `.ml` file, then rebuild the generator targets or the app.
- `ml-messenger.opam` is generated from `dune-project`; change package
  metadata/dependencies in `dune-project`, then regenerate rather than editing
  the opam file directly.

Use `test/messenger_test` as the reference shape for new scenes, nested user
components, portable components, and resource declarations.

## Build and verification

Run commands from this repository root:

```sh
dune build
dune runtest
```

`dune runtest` currently exercises only the non-GUI recursion test. Match
verification to the change:

```sh
# Check OCaml formatting; requires ocamlformat in the active opam environment.
dune build @fmt

# Compile the browser applications and exercise code generation.
dune build test/test.bc.js test/messenger_test/main.bc.js

# Compile the native applications.
dune build test/test_desktop.exe test/messenger_test/main_desktop.exe
```

Do not launch native executables as a routine test: they open an SDL window
and block until it closes. For browser smoke testing, initialize the
`ml-regl-js` submodule, build its bundle with `pnpm`/`make`, serve the repository
root over HTTP, and open `index.html`; its script paths are absolute from that
root.

When changing shared rendering/backend behavior, also verify `../ml-regl`.
Its portable unit test is `dune runtest`. Browser test bundles live under its
`test/` and use the harnesses in `../ml-regl/html/`. Native builds require a
configured `DECLGL_BUILD_DIR` containing `libdeclgl.a` and
`declgl_link_flags.sexp`; on Linux, `../ml-regl/build.sh` prepares and builds
the complete backend stack.

Add deterministic logic tests to a Dune `(test ...)` stanza so `dune runtest`
actually executes them. For rendering, resource, audio, or input changes,
compile both backend variants and use the smallest relevant interactive smoke
app. Do not claim visual or audio verification from compilation alone.

## Style and change discipline

- Use the repository's `.ocamlformat` profile (`conventional`, wrapped
  comments). Run formatting only on files in scope.
- Follow the existing explicit record/type style around high-arity framework
  types; the annotations are useful documentation for OCaml inference errors.
- Prefer `Ml_regl_core` smart constructors and public modules over constructing
  protobuf-generated records directly.
- Keep scene output side effects centralized in `Ui.handle_som`; add a new
  output variant and its handler together.
- Preserve backend parity. Input keys follow the shared backend vocabulary
  (for example `"Space"`, `"Return"`, and 1-based mouse buttons); use
  `Messenger_extra.Key_code` when suitable.
- Do not edit `_build`, generated protocol modules, generated `mgl_*` modules,
  or files inside a submodule as if they belonged to this repository.
- The codebase disables warnings-as-errors in Dune, but new warnings should
  still be treated as defects.
- Keep commits focused and follow the existing Conventional Commit style when
  asked to commit (`feat:`, `fix:`, and similar prefixes).

Before finishing, inspect `git diff`, report which commands were run, and call
out any formatter, browser, native toolchain, or interactive checks that could
not be performed.
