# ML Messenger

A functional, message-driven 2D game engine for OCaml — the OCaml port of the
Elm [`messenger`](https://github.com/elm-messenger/Messenger) framework, sitting on
top of the `ml-regl` rendering runtime.

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
  implementations exchange `Regl_event`s and side effects with the core
  using a shared Protobuf-encoded protocol.


## Building

```sh
dune build
dune test
```
