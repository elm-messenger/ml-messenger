open Ml_regl_core
open Transition_base

let fade_out : single_trans = fun r t -> Regl_compositors.linear_fade t r (Regl_builtin_programs.clear Color.black)
let fade_in : single_trans = fun r t -> Regl_compositors.linear_fade t (Regl_builtin_programs.clear Color.black) r

let fade_out_img mask invert : single_trans =
 fun r t -> Regl_compositors.img_fade mask t invert r (Regl_builtin_programs.clear Color.black)

let fade_in_img mask invert : single_trans =
 fun r t -> Regl_compositors.img_fade mask t invert (Regl_builtin_programs.clear Color.black) r

let fade_out_with_color c : single_trans = fun r t -> Regl_compositors.linear_fade t r (Regl_builtin_programs.clear c)
let fade_in_with_color c : single_trans = fun r t -> Regl_compositors.linear_fade t (Regl_builtin_programs.clear c) r
let fade_out_with_renderable c : single_trans = fun r t -> Regl_compositors.linear_fade t r c
let fade_in_with_renderable c : single_trans = fun r t -> Regl_compositors.linear_fade t c r
let fade_mix : double_trans = fun r1 r2 t -> Regl_compositors.linear_fade t r1 r2
let fade_img_mix mask invert : double_trans = fun r1 r2 t -> Regl_compositors.img_fade mask t invert r1 r2

