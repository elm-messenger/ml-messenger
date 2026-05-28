open Ml_regl_core

let texture_dim runtime name =
  match Base.get_sprite name runtime with
  | Some t -> (t.Regl_proto.width, t.height)
  | None -> (0, 0)

let render_sprite runtime (x, y) (w, h) name =
  match Base.get_sprite name runtime with
  | None -> Regl_builtin_programs.empty
  | Some t ->
      let tw = float_of_int t.Regl_proto.width in
      let th = float_of_int t.height in
      let w, h =
        match (w, h) with
        | 0., 0. -> (tw, th)
        | w, 0. -> (w, if tw = 0. then 0. else w /. tw *. th)
        | 0., h -> ((if th = 0. then 0. else h /. th *. tw), h)
        | w, h -> (w, h)
      in
      Regl_builtin_programs.rect_texture (x, y) (w, h) name
