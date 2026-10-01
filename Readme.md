# ML Messenger

A functional, message-driven 2D game engine for OCaml — the OCaml port of the
Elm [`messenger`](https://github.com/elm-messenger/Messenger) framework, sitting
on top of the [`ml-regl`](https://github.com/elm-messenger/ml-regl) rendering
backend.

## Overview

`ml-messenger` lets you build games out of pure, typed messages flowing
between **Scenes** and **Components**. The same OCaml
codebase runs on two interchangeable backends:

- `Regl_js` — Js\_of\_ocaml + `regl.js`, targeting the browser
- `Regl_desktop` — native SDL3 + OpenGL, talking to a C++ host over a
  Protobuf wire

Both backends implement the same `Regl_backend` interface, so user code is
fully portable across web and desktop.

## Architecture

![Architecture](docs/architecture.png)

- **User code** is organized as a tree: a `Scene` owns a set of `Components`
  (which can themselves be composite), and communicates with sibling
  components and parents through typed messages.
- **Core code** routes `WorldEvent`s to the active scene's `Update`, threads
  the `Env` through, then dispatches `SceneOutputMsg`s via `SOMHandler` and
  renders the scene through `PostProcessor` + `ViewHandler`.
- **Backend** is an abstract interface (`Regl_backend`); the JS and desktop
  implementations live in the
  [`ml-regl`](https://github.com/elm-messenger/ml-regl) repository, and
  exchange `Regl_event`s and side effects with the core using a shared
  Protobuf-encoded protocol.


## Building

```sh
dune build
dune test
```

## Installing

To use ml-messenger from an application in another directory, install it into
your opam switch. Install ml-regl first with its own `install.sh`, then run:

```sh
./install.sh
```

The script pins `ml-messenger` to this checkout, so opam installs the current
branch's last commit; after changing ml-messenger, commit and rerun it. An
application then lists the libraries and one backend in its `dune` file:

```dune
(libraries ml-messenger ml-messenger.extra regl_js)       ; browser
(libraries ml-messenger ml-messenger.extra regl_desktop)  ; native
```

`test/messenger_test` shows the application layout.
