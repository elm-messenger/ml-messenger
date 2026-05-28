let gen_global_component concomp gcmsg gctar runtime env =
  let id = Option.value gctar ~default:concomp.Scene.id in
  let transformed : (_, _, _, _, _, _, _, _, _) General_model.concrete_general_model =
    {
      init = (fun runtime env msg -> concomp.init runtime env msg);
      update = (fun runtime env evt data bdata -> concomp.update runtime env evt data bdata);
      updaterec = (fun runtime env msg data bdata -> concomp.updaterec runtime env msg data bdata);
      view = (fun runtime env data bdata -> concomp.view runtime env data bdata);
      matcher = (fun _ _ tar -> tar = id);
    }
  in
  General_model.abstract transformed gcmsg runtime env

let filter_alive_gc xs = List.filter (fun x -> not (General_model.unroll x).base_data.Scene.dead) xs
let combine_pp xs = List.map (fun gc -> (General_model.unroll gc).base_data.Scene.post_processor) xs
