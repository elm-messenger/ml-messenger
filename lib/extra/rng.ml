let gen_random_int seed (lo, hi) =
  let st = Random.State.make [| seed |] in
  lo + Random.State.int st (hi - lo + 1)

let gen_random_list_int seed len range =
  let st = Random.State.make [| seed |] in
  let lo, hi = range in
  List.init len (fun _ -> lo + Random.State.int st (hi - lo + 1))

