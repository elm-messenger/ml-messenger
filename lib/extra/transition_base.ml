open Ml_regl_core

type single_trans = Regl_common.renderable -> float -> Regl_common.renderable

type double_trans =
  Regl_common.renderable ->
  Regl_common.renderable ->
  float ->
  Regl_common.renderable

let null_transition r _ = r

type no_mix_transition = {
  current_transition : float;
  out_t : float;
  in_t : float;
  out_trans : single_trans;
  in_trans : single_trans;
}

type mix_transition = {
  current_transition : float;
  t : float;
  trans : double_trans;
}

type transition =
  | NMTransition of no_mix_transition
  | MTransition of mix_transition

let gen_no_mix_transition (out_trans, out_t_ms) (in_trans, in_t_ms) =
  NMTransition
    {
      current_transition = 0.;
      out_t = out_t_ms;
      in_t = in_t_ms;
      out_trans;
      in_trans;
    }

let gen_mix_transition (trans, t_ms) =
  MTransition { current_transition = 0.; t = t_ms; trans }
