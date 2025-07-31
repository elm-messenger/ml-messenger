type world_event =
  | WMouseMove of float * float
  | WMouseDown of int * (float * float)
  | WMouseUp of int * (float * float)
  | WKeyDown of int
  | WKeyUp of int
  | WTick of float
  | WNullEvent


type user_event =
  | MouseMove of float * float
  | MouseDown of int * (float * float)
  | MouseUp of int * (float * float)
  | KeyDown of int
  | KeyUp of int
  | Tick of float
  | NullEvent

type ('common, 'user) env = { global_data : 'common; common_data : 'user }
