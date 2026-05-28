open Ml_regl_core
open Messenger

type ('cdata, 'userdata, 'tar, 'msg, 'bdata, 'scenemsg) children =
  ( 'cdata,
    'userdata,
    'tar,
    'msg,
    'bdata,
    'scenemsg )
  Component.abstract_component
  list

let update_children = Component.update_components
let update_children_with_block = Component.update_components_with_block
let update_children_with_target = Component.update_components_with_target
let view_children = Component.view_components

let view_children_with_z ?(effects = []) z runtime env children =
  (Regl_common.group effects [ view_children runtime env children ], z)
