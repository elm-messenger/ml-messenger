(lang dune 3.19)

(name ml-messenger)

(generate_opam_files true)

(source
 (github elm-messenger/ml-messenger))

(authors "Yiming Xiang <yiming@cs.utexas.edu>")

(maintainers "Yiming Xiang <yiming@cs.utexas.edu>")

(license LICENSE)

(package
 (name ml-messenger)
 (synopsis "A functional, message-driven 2D game engine for OCaml.")
 (description "The OCaml port of the Elm messenger framework, sitting on top of the ml-regl rendering backend.")
 (depends
  ocaml
  ml_regl_core
  regl_backend
  otoml
  (js_of_ocaml :with-test)
  (regl_js :with-test))
 (allow_empty))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
