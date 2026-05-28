open Messenger

type ('cdata,
       'data,
       'userdata,
       'tar,
       'msg,
       'bdata,
       'scenemsg)
     concrete_iu_component = {
  init : ('cdata, 'userdata, 'msg, 'data, 'bdata) Component.component_init;
  init_update :
    ( 'cdata,
      'data,
      'userdata,
      'scenemsg,
      'tar,
      'msg,
      'bdata )
    Component.component_update;
  update :
    ( 'cdata,
      'data,
      'userdata,
      'scenemsg,
      'tar,
      'msg,
      'bdata )
    Component.component_update;
  updaterec :
    ( 'cdata,
      'data,
      'userdata,
      'scenemsg,
      'tar,
      'msg,
      'bdata )
    Component.component_updaterec;
  view : ('cdata, 'userdata, 'data, 'bdata) Component.component_view;
  matcher : ('data, 'bdata, 'tar) Component.component_matcher;
}

let res_map (((data, bdata), msgs, envres) : ('data * 'bdata) * 'msgs * 'envres)
    inited =
  (((data, inited), bdata), msgs, envres)

let to_concrete_user_component comp =
  let init runtime env msg =
    let data, bdata = comp.init runtime env msg in
    ((data, false), bdata)
  in
  let update runtime env evnt (data, inited) bdata =
    if inited then res_map (comp.update runtime env evnt data bdata) true
    else res_map (comp.init_update runtime env evnt data bdata) true
  in
  let updaterec runtime env msg (data, inited) bdata =
    res_map (comp.updaterec runtime env msg data bdata) inited
  in
  let view runtime env (data, _) bdata = comp.view runtime env data bdata in
  let matcher (data, _) bdata target = comp.matcher data bdata target in
  { General_model.init; update; updaterec; view; matcher }

let gen_iu_component comp =
  Component.gen_component (to_concrete_user_component comp)
