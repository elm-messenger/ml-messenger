open Ml_regl_core

type t = Regl_common.camera

let default : t = { x = 0.; y = 0.; zoom = 1.; rotation = 0. }

let apply (camera : t) (renderable : Regl_common.renderable) : Regl_common.renderable =
  Regl_common.group_with_camera camera [] [ renderable ]

let judge_mouse_rect ~mouse:(mx, my) ~pos:(x, y) ~size:(w, h) =
  mx >= x && mx <= x +. w && my >= y && my <= y +. h

let judge_mouse_circle ~mouse:(mx, my) ~center:(cx, cy) ~radius =
  let dx = mx -. cx in
  let dy = my -. cy in
  (dx *. dx) +. (dy *. dy) <= radius *. radius

let mouse_to_camera_space (camera : t) (mx, my) =
  let zoom = if camera.zoom = 0. then 1. else camera.zoom in
  let dx = (mx -. camera.x) /. zoom in
  let dy = (my -. camera.y) /. zoom in
  let c = cos (-.camera.rotation) in
  let s = sin (-.camera.rotation) in
  ((dx *. c) -. (dy *. s), (dx *. s) +. (dy *. c))

let judge_mouse_rect_with_camera ~camera ~mouse ~pos ~size =
  judge_mouse_rect ~mouse:(mouse_to_camera_space camera mouse) ~pos ~size

let judge_mouse_circle_with_camera ~camera ~mouse ~center ~radius =
  judge_mouse_circle ~mouse:(mouse_to_camera_space camera mouse) ~center ~radius
