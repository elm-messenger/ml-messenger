open Messenger

type model_t = int
type msg_t = int
type env_t = (int, int) Base.env
type bd_t = int
type ren = int
type tar = int

let test_env : env_t = { global_data = 1; common_data = 2 }
let init (env : env_t) (_ : msg_t) : model_t * bd_t = (env.common_data, 0)

let update (env : env_t) (_ : Base.user_event) (model : model_t) (bd : bd_t) =
  ((model, bd), [], (env, false))

let updaterec (env : env_t) (_ : msg_t) (model : model_t) (bd : bd_t) =
  ((model, bd), [], env)

let view (env : env_t) (model : model_t) (bd : bd_t) : ren = 12
let matcher (model : model_t) (bd : bd_t) (t : tar) = false

let concrete_model :
    ( model_t,
      env_t,
      Base.user_event,
      tar,
      msg_t,
      ren,
      bd_t,
      int )
    Generalmodel.concrete_general_model =
  { init; update; updaterec; view; matcher }

let abstract_model = Generalmodel.abstract concrete_model
