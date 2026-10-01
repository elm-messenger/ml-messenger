# Component and scene redesign plan

**Current position:** Stages 1–5 done; only the optional polish in stage 6 is left. Update this line, the stage
checklists, and the log at the bottom whenever a step lands.

## Goal

Users write each component's message, init, and data types in the
component's own module. There is no global message union and no code
generation. A parent (a scene or a component) owns the union of its direct
children's messages.

The redesign is done when `test/messenger_test` builds and runs from plain
OCaml (no `messenger_codegen`, no TOML), and the old component API and the
codegen are deleted.

## Agreed design

1. **A component owns its types.** A component module defines `type msg`,
   `type init`, `type data`, and `let component = { Component.init; update;
   updaterec; view; matcher }` (a record literal, so it stays polymorphic).
   One `msg` type carries both what the component reports and what it
   receives.
2. **The parent owns the union of its children.** It defines
   `type msg = Button of Button.Model.msg | Slider of Slider.Model.msg` and one
   port per child kind:
   `let button = Component.port (fun m -> Button m) (function Button m -> Some m | _ -> None)`.
   A port's `unwrap` may also translate a shared parent message into a
   child's own message (for example `Collide ty -> Some (Enemy.Hit ty)`), so a
   parent can address children without knowing their kind.
3. **Children never reference the parent's union.** A child emits
   `Component.cmd` values:
   - `Parent m`: its own message, to the parent (wrapped by the port);
   - `Other (target, m)`: its own message, to siblings of the same kind;
   - `Sibling (target, p)`: a message already in the parent's union, which the
     child can only hold because the parent passed a capability in its init
     (for example `{ to_badge = badge.wrap }`);
   - `Som s`: a scene output message.
4. **No layer concept.** A layer is a component with subcomponents. A
   composite component defines `msg` (what it tells its parent) and
   `child_msg` (its own children's union).
5. **Inspecting children is the parent's choice.** There is no base data in
   the component spec. A parent that must read its children (collision,
   culling) creates their ports with `Component.port_with ~inspect` and reads
   `Component.inspect child`. All children in one list share the inspect
   type; `Component.port` gives `unit`.
6. **Scene prototypes need no framework support.** A prototype is a function
   returning a scene storage; levels are values.
7. **Scenes get typed keys** instead of the global `'scenemsg` parameter
   (stage 5).
8. **App registration is plain OCaml:** the `Ui.input` record in an `app.ml`.
9. **Global components are unchanged:** they keep their base data (`dead`,
   `post_processor`) and `string` messages for now.

## Component API

The signatures below are current. Stage 1 added them next to the old API with
an extra `'scenemsg` parameter; stage 4 deleted the old API and stage 5 removed
that parameter.

```ocaml
(* General_model *)
val of_data : (...) concrete_general_model -> 'data -> 'bdata -> (...) abstract_general_model
(* [abstract] = init, then [of_data]. *)

(* Component *)
type ('msg, 'pmsg, 'tar, 'userdata) cmd =
  | Parent of 'msg
  | Other of 'tar * 'msg
  | Sibling of 'tar * 'pmsg
  | Som of 'userdata Scene.scene_output_msg

type ('init, 'data, 'msg, 'pmsg, 'cdata, 'userdata, 'tar) spec = {
  init : runtime -> ('cdata, 'userdata) Base.env -> 'init -> 'data;
  update : runtime -> env -> regl_event -> 'data -> 'data * cmd list * (env * bool);
  updaterec : runtime -> env -> 'msg -> 'data -> 'data * cmd list * env;
  view : runtime -> env -> 'data -> renderable * int;
  matcher : 'data -> 'tar -> bool;
}

type ('data, 'msg, 'pmsg, 'view) port = {
  wrap : 'msg -> 'pmsg;
  unwrap : 'pmsg -> 'msg option;
  inspect : 'data -> 'view;
}

val port : ('msg -> 'pmsg) -> ('pmsg -> 'msg option) -> ('data, 'msg, 'pmsg, unit) port
val port_with : inspect:('data -> 'view) -> ('msg -> 'pmsg) -> ('pmsg -> 'msg option) -> (...) port

type ('cdata, 'userdata, 'tar, 'pmsg, 'view) t  (* over General_model *)

val make : port -> spec -> 'init -> runtime -> env -> t
val inspect : t -> 'view
val update_children : runtime -> env -> regl_event -> t list -> t list * 'pmsg list * som list * (env * bool)
val send : runtime -> env -> ('tar * 'pmsg) list -> t list -> t list * 'pmsg list * som list * env
```

`Component.view_components` and `Recursion.remove_objects` keep working on
`t` lists.

## Dependency rules under `(include_subdirs qualified)`

Dune treats a reference to a subdirectory as a dependency on everything inside
it. These rules were tested in scratch projects:

| Reference | Works? |
|---|---|
| Parent → its child directories | Yes |
| Child → a plain module in an ancestor directory (e.g. `interaction/common.ml`) | Yes, if that module references no children |
| Child → its parent's model or union | Never (a real cycle) |
| Sibling directory → sibling directory | One direction only |
| Scene → scene with params, both ways | Through plain `*_params.ml` modules next to the scene directories |
| A module inside a group → the group by its full path (`Scenes.X` from inside `scenes/`) | No; use the relative path (`X.Model`) |

## Conventions

- Component module: `msg`, `init`, `data`, `component`, plus plain accessors
  a parent may use for `inspect` (e.g. `body`).
- Parent: `type msg = Child of Child.Model.msg | ...`; a port per child kind,
  named after the child (`button`), or `*_port` when that name is taken.
- Data that children read from their parent (common data) lives in a plain
  module in the parent's directory, e.g. `common.ml`.

## Stages

### Stage 1: new component API alongside the old one (non-breaking)

- [x] `General_model.of_data`; `abstract` defined through it.
- [x] `Component`: `cmd`, `spec`, `port`, `port_with`, `t`, `make`, `inspect`,
      `update_children`, `send` (plus `split_outputs`).
- [x] `test/test_component.ml` in a `(test ...)` stanza: parent wrapping,
      `Other` reaching same-kind siblings only, `Sibling` through a capability,
      port translation of a shared message, `inspect`, `send`, SOM passthrough,
      blocking, child order.
- [x] Verify (see below).

### Stage 2: port `messenger_test` components to the new API

Codegen still generates scene registration and `scene_msg` in this stage.

- [x] Make `messenger_test` a library plus thin `main`/`main_desktop`
      executables (keep `main.bc.js` at the same path for `index.html`), so
      a headless test can link it.
- [x] Interaction: button and slider with their own types; delete unused
      `init.ml`/`msg.ml`, `component_base.ml`, and `scene_base.ml` (the scene
      has no common data, so no `common.ml` was needed).
- [x] Components: layers become composite components owning a rect union
      (`scenes/components/layer/model.ml`, `layer/rect/model.ml`).
- [x] Portable components: badge is an ordinary component used through a
      port, panel reaches the badge through a capability; drop the
      `[[components]]` entries from `config.toml`.
- [x] Scenes pass their init message to `Scene.abstract` instead of `None`.
- [x] Headless test driving scene updates (no `Ui`, so it links `regl_js`
      natively like the other tests): `test/test_example.ml`, checking the
      text in each scene's encoded frame.
- [x] Verify.

### Stage 3: remove codegen from `messenger_test`

- [x] `app.ml` builds `Ui.input` by hand (config, resources, global
      components, scene table); `main.ml` is `Ui.gen_main App.input`.
- [x] `'scenemsg` becomes `unit` until stage 5 (`App.scene_msg`; child lists
      annotate it as `unit`).
- [x] Delete `project.toml`, every `config.toml`, the unused `scene_msg.ml`,
      and the codegen rule.
- [x] Update AGENTS.md ("Application structure" replaces "Generated
      application code").
- [x] Verify.

### Stage 4: delete the old API and the codegen

Done before scene keys so stage 5 does not have to edit code that is about to
be deleted. The example no longer uses any of it.

- [x] Old `Component` types and helpers (`concrete_user_component`,
      `abstract_component`, `gen_component`, `component_storage`,
      `update_components*`, middle-step types); kept the view helpers.
      `Component.t` is now defined directly over `General_model`.
- [x] `Messenger_extra`: deleted `Portable_component`, `Layer_extra`, and
      `Composite_component`; ported `Init_update_component` (its own spec
      record plus `make`, tested in `test/test_component.ml`).
- [x] `Raw_scene` prototype helpers (`raw_scene_proto_*`, `init_compose`).
- [x] `codegen/` and the `otoml` dependency; opam file regenerated.
- [x] AGENTS.md, `docs/known_issues.md` (codegen section removed); the Readme
      had nothing to change.
- [x] Verify (plus `dune build @install`: no codegen binary installed).

### Stage 5: typed scene keys (breaking)

- [x] `'p Scene.key` (name plus `Type.Id`); `Scene.target` is
      `By_name name | By_key (key, param)`; `Scene.named`, `Scene.entry`, and
      `Scene.table` build the registry (duplicate names are reported);
      `Loader.load_target` checks the key and reports a mismatch; the
      scene's `init` gets `'p option`; `ui.user_config.init_scene` is a target
      (no `init_scene_msg`); OCaml >= 5.1 in `dune-project`.
- [x] Removed `'scenemsg` from `Scene`, `Component`, `Ui`, `Model`, `Loader`,
      `Vsr`, `Raw_scene`, global components, and `Messenger_extra`
      (`Transition_model.init_option.scene` is a `Scene.target`).
- [x] Ported `messenger_test` (`app.ml` uses `Scene.table`), `test/test.ml`,
      and the unit tests; new `test/test_scene.ml`.
- [x] Verify. Also checked on a scratch copy through `Ui` (desktop backend, no
      window): initial scene by name, transition `filter_som`, transition
      target, dead transition removal, `By_name` scene change.

### Stage 6: optional polish

- Aliases that hide the `unit` inspect parameter, `Ui.default_config`, typed
  global-component messages.

## Verification for every stage

```sh
dune build
dune runtest
dune build @fmt
dune build test/test.bc.js test/messenger_test/main.bc.js
dune build test/test_desktop.exe test/messenger_test/main_desktop.exe
```

Then inspect `git diff`. Do not launch native executables (they open a
window). Compilation does not verify rendering or audio.

## Log

- 2026-10-01: plan written; stage 1 started. Earlier design discussion and
  scratch prototypes (spaceshooter port, interaction, portable panel/badge)
  validated the API above; the scratch code is not kept.
- 2026-10-01: stage 1 done. New API in `lib/component.ml`, `of_data` in
  `lib/general_model.ml`, `test/test_component.ml`. All verification commands
  pass; a deliberately broken matcher/`Sibling` makes the test fail.
- 2026-10-01: stage 2 done. Notes:
  - The codegen rule's `(glob_files_rec **/config.toml)` matched nothing, so
    `config.toml` edits never regenerated `Mgl_base`; now
    `(glob_files_rec config.toml)`.
  - The portable scene now listens for `"Return"` (what both backends send)
    instead of `"Enter"`; the Audio scene still has `"Enter"` (known issue).
  - Rects use `Base.get_virtual_size` instead of a hard-coded view size.
  - The badge's id comes from its init (`{ id; text }`) instead of an adapter
    matcher.
- 2026-10-01: stage 3 done. The example has no codegen, no TOML, and no
  `Mgl_*` modules; `codegen/` still builds but is unused.
- 2026-10-01: swapped the old stages 4 and 5: deleting the old API first means
  the scene-key change does not have to update code that is about to go.
- 2026-10-01: stage 4 done.
- 2026-10-01: stage 5 done. The redesign's required stages are complete.
