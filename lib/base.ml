(* World Event *)
type world_event =
  | MouseMove of float * float
  | MouseDown of int * (float * float)
  | MouseUp of int * (float * float)
  | KeyDown of int
  | KeyUp of int
  | Tick of float
  | NullEvent

type ('common, 'user) env = { global_data : 'common; common_data : 'user }
