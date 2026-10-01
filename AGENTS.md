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
- `lib/component.ml`: components with their own message types (`spec`,
  `port`, `make`, `update_children`, `send`) and z-order rendering helpers.
- `lib/scene.ml`: scene abstraction, scene output messages, and global
  component types.
- `lib/ui.ml`: top-level init/update/view pipeline and the only call to
  `Regl_backend.create_app`.
- `lib/internal.ml`, `lib/model.ml`, `lib/base.ml`: runtime caches/input state,
  application model, and public environment accessors.
- `lib/resources.ml`, `lib/audio.ml`, `lib/camera.ml`: framework services over
  `Ml_regl_core`.
- `lib/extra/`: optional helpers published as `Messenger_extra`, including
  transitions, FPS, asset loading, and init-update components.
- `test/test_recursion.ml`, `test/test_component.ml`: fast non-GUI unit tests
  for routing and the component API, run by `dune runtest`.
- `test/test_example.ml`: headless test that drives `messenger_test` scenes
  without `Ui` and checks the text they draw.
- `test/test_ui.ml`: drives `Ui.init`/`Ui.update` (resource loading,
  transitions, global components). It links the desktop backend but never
  calls `Ui.gen_main`, so it opens no window.
- `test/test.ml`: minimal cross-backend compilation/smoke application.
- `test/messenger_test/`: full example application and primary integration
  fixture for scenes, components, resources, audio, camera, and transitions.
  It is a library (`messenger_test`); `main.ml` only picks a backend.
- `docs/main.typ` and `docs/architecture.png`: architecture documentation.
- `docs/known_issues.md`: open problems and intended-but-surprising behavior;
  update it when fixing or finding one.
- `docs/redesign_plan.md`: the in-progress component/scene redesign; read its
  current position before changing components or scenes.

The `messenger` library is published as `ml-messenger` and is available to
consumers as the wrapped `Messenger` module. `lib/extra` is the separate
wrapped `Messenger_extra` library, published as `ml-messenger.extra`;
applications using transitions or other helpers must
list it in their Dune `libraries`. There are intentionally few `.mli` files,
so a new top-level binding can become public API; avoid accidental API growth.

## Core invariants

- Treat scene/component updates as functional state transitions. Thread the
  returned environment through every update; do not discard a child's or
  global component's updated environment.
- `General_model.Other (target, msg)` is delivered to every model whose
  `targets` include `target`. Targets are compared structurally and hashed, so
  they must not contain functions.
  `General_model.Parent (OtherMsg msg)` bubbles a normal message to the parent,
  while `Parent (SOMMsg som)` bubbles a `Scene.scene_output_msg` to the top-level
  handler.
- `Recursion.update_objects` updates from the end of the model list toward the
  front. A returned `block = true` stops the remaining event traversal. Keep
  this ordering when changing input dispatch or z-order behavior.
- Targeted messages are processed until none remain. Never create an
  unconditional target-message cycle; it will make the recursive dispatcher
  fail to terminate.
- Routing is linear: an event costs O(n + M) for n models and M emitted
  messages, and each round of targeted messages O(n + m + deliveries). Keep it
  that way: accumulate in reverse instead of appending with `@`, and look
  messages up by target (`Recursion.deliveries`) instead of testing every
  model against every message.
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

## Application structure

Applications are plain OCaml; there is no code generation.
`test/messenger_test` is the reference shape:

- The app is a library with `(include_subdirs qualified)`. `app.ml` builds the
  `Ui.input` record (config, resources, global components, and the scene
  table); `main.ml` is only `Ui.gen_main App.input`, copied to
  `main_desktop.ml` for the native backend.
- A component module defines its own `msg`, `init`, and `data` types and a
  `component` record literal (`{ Component.init; update; updaterec; view;
  targets }`, where `targets` lists the addresses it answers to). It never
  names its parent's message type.
- A parent (scene or component) defines the union of its direct children's
  messages and one `Component.port` per child kind, creates children with
  `Component.make`, and updates them with `Component.update_children` or
  `Component.send`. A component with subcomponents (what Elm messenger calls
  a layer) defines `msg` for its parent and `child_msg` for its children.
- Children report with `Component.Parent`, reach same-kind siblings with
  `Other`, other siblings with `Sibling` (through a capability the parent
  passes in their init), and scene output with `Som`.
- Scenes are registered in `app.ml` with `Scene.table`: `Scene.named name
  scene` for a scene without parameters, `Scene.entry key scene` for one that
  is started with typed parameters (`let key : params Scene.key = Scene.key
  "Game"`). Scenes change with `SOMChangeScene (By_name name)` or
  `SOMChangeScene (By_key (key, params))`, and the scene's `init` receives
  `None` or `Some params`. Put a key that other scenes use in a plain module
  next to the scene directories so scenes can refer to each other's keys
  without a cycle.
- A storage read (`SOMReadValue key`) is answered by a
  `Regl_proto.ValueRead { key; value }` event (`value = None` when nothing is
  stored), delivered to global components, the active scene, and its
  children like any other input. `Base.get_local_value` caches the latest
  value.
- Under `(include_subdirs qualified)`, a reference to a subdirectory depends on
  everything in it. Children may read plain modules in ancestor directories
  (e.g. a `common.ml`), but must never reference their parent's model or
  union; sibling directories may reference each other in one direction only.
  See `docs/redesign_plan.md` for the tested rules.
- `ml-messenger.opam` is generated from `dune-project`; change package
  metadata/dependencies in `dune-project`, then regenerate rather than editing
  the opam file directly.

## Build and verification

Run commands from this repository root:

```sh
dune build
dune runtest
```

`dune runtest` runs the non-GUI unit tests and the headless example test.
Match verification to the change:

```sh
# Check OCaml formatting; requires ocamlformat in the active opam environment.
dune build @fmt

# Compile the browser applications.
dune build test/test.bc.js test/messenger_test/main.bc.js

# Compile the native applications.
dune build test/test_desktop.exe test/messenger_test/main_desktop.exe
```

Do not launch native executables as a routine test: they open an SDL window
and block until it closes. For browser smoke testing, initialize the
`ml-regl-js` submodule, build its bundle with `pnpm`/`make`, serve the repository
root over HTTP, and open `index.html`; its script paths are absolute from that
root.

This repository builds against the opam-installed `ml-regl` packages, which
are pinned to `../ml-regl`'s `main` branch. After committing an `ml-regl`
change, reinstall them before building here:

```sh
cd ../ml-regl
export DECLGL_BUILD_DIR=$PWD/declgl-desktop/build/linux-release
opam update ml_regl_core regl_backend regl_desktop regl_js
opam reinstall -y ml_regl_core regl_backend regl_desktop regl_js
```

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
- Do not edit `_build`, generated protocol modules,
  or files inside a submodule as if they belonged to this repository.
- The codebase disables warnings-as-errors in Dune, but new warnings should
  still be treated as defects.
- Keep commits focused and follow the existing Conventional Commit style when
  asked to commit (`feat:`, `fix:`, and similar prefixes).

Before finishing, inspect `git diff`, report which commands were run, and call
out any formatter, browser, native toolchain, or interactive checks that could
not be performed.
