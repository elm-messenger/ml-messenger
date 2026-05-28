type tetris_user_data = { last_max_score : int; current_max_score : int }
type user_data = { tetris_data : tetris_user_data }

let default = { tetris_data = { last_max_score = 0; current_max_score = 0 } }
let encode_max_score data = string_of_int data.tetris_data.current_max_score

let with_loaded_max_score value data =
  let score =
    Option.value (Option.map int_of_string_opt value) ~default:None
    |> Option.value ~default:0
  in
  ignore data;
  { tetris_data = { last_max_score = score; current_max_score = score } }
