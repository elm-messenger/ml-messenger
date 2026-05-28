open Ml_regl_core

type t = Regl_common.camera

let default ~width ~height : t =
  { x = width /. 2.; y = height /. 2.; zoom = 1.; rotation = 0. }

let origin : t = { x = 0.; y = 0.; zoom = 1.; rotation = 0. }

let apply (camera : t) (renderable : Regl_common.renderable) :
    Regl_common.renderable =
  Regl_common.group_with_camera camera [] [ renderable ]

let judge_mouse_rect ~mouse:(mx, my) ~pos:(x, y) ~size:(w, h) =
  mx >= x && mx <= x +. w && my >= y && my <= y +. h

let judge_mouse_circle ~mouse:(mx, my) ~center:(cx, cy) ~radius =
  let dx = mx -. cx in
  let dy = my -. cy in
  (dx *. dx) +. (dy *. dy) <= radius *. radius

let world_to_view (camera : t) (x, y) =
  let zoom = if camera.zoom = 0. then 1. else camera.zoom in
  let dx = x -. camera.x in
  let dy = y -. camera.y in
  if camera.rotation = 0. then (dx *. zoom, dy *. zoom)
  else
    let c = cos camera.rotation in
    let s = sin camera.rotation in
    ( (dx *. zoom *. c) +. (dy *. zoom *. s),
      (dy *. zoom *. c) -. (dx *. zoom *. s) )

let view_to_world (camera : t) (x, y) =
  let zoom = if camera.zoom = 0. then 1. else camera.zoom in
  let xs = x /. zoom in
  let ys = y /. zoom in
  if camera.rotation = 0. then (xs +. camera.x, ys +. camera.y)
  else
    let c = cos camera.rotation in
    let s = sin camera.rotation in
    ((xs *. c) -. (ys *. s) +. camera.x, (ys *. c) +. (xs *. s) +. camera.y)

let mouse_to_camera_space ~view_size:(vw, vh) camera (mx, my) =
  view_to_world camera (mx -. (vw /. 2.), my -. (vh /. 2.))

let judge_mouse_rect_with_camera ~view_size ~camera ~mouse ~pos ~size =
  judge_mouse_rect
    ~mouse:(mouse_to_camera_space ~view_size camera mouse)
    ~pos ~size

let judge_mouse_circle_with_camera ~view_size ~camera ~mouse ~center ~radius =
  judge_mouse_circle
    ~mouse:(mouse_to_camera_space ~view_size camera mouse)
    ~center ~radius
