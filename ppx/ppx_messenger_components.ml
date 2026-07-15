open Ppxlib
open Ast_builder.Default

type entry = {
  name : string loc;
  msg_type : core_type;
  portable_component : longident loc option;
}

let loc_errorf ~loc fmt = Location.raise_errorf ~loc fmt
let lident ~loc name = { loc; txt = Longident.Lident name }
let evar ~loc name = pexp_ident ~loc (lident ~loc name)
let pvar ~loc name = ppat_var ~loc { loc; txt = name }

let remove_msg_suffix name =
  let suffix = "Msg" in
  let suffix_len = String.length suffix in
  let name_len = String.length name in
  if
    name_len > suffix_len
    && String.equal (String.sub name (name_len - suffix_len) suffix_len) suffix
  then String.sub name 0 (name_len - suffix_len)
  else name

let module_name_of_constructor name = remove_msg_suffix name ^ "_component"
let expr_of_longident ~loc lid = pexp_ident ~loc { loc; txt = lid }
let attr_name attr = attr.attr_name.txt
let portable_attr_name = "portable"

let parse_portable_attr attr =
  let loc = attr.attr_loc in
  match attr.attr_payload with
  | PStr
      [
        {
          pstr_desc =
            Pstr_eval
              ({ pexp_desc = Pexp_ident component; pexp_attributes = []; _ }, []);
          _;
        };
      ] ->
      Some component
  | _ ->
      loc_errorf ~loc
        "[@portable] expects a component value path, for example [@portable \
         Button.component]"

let parse_name ~loc = function
  | { pexp_desc = Pexp_construct ({ txt = Lident name; loc }, None); _ } ->
      { loc; txt = name }
  | _ -> loc_errorf ~loc "component name must be a capitalized identifier"

let parse_component_path ~loc = function
  | { pexp_desc = Pexp_construct (component, None); _ } -> component
  | _ -> loc_errorf ~loc "portable component must be a module path"

let parse_msg_type ~loc = function
  | { pexp_desc = Pexp_ident msg_type; _ } -> ptyp_constr ~loc msg_type []
  | _ -> loc_errorf ~loc "message type must be a type path"

let rec exprs_of_sequence expr =
  match expr.pexp_desc with
  | Pexp_sequence (left, right) ->
      exprs_of_sequence left @ exprs_of_sequence right
  | _ -> [ expr ]

let parse_expr expr =
  let loc = expr.pexp_loc in
  match expr with
  | {
   pexp_desc =
     Pexp_apply
       ( { pexp_desc = Pexp_ident { txt = Lident "="; _ }; _ },
         [
           ( Nolabel,
             {
               pexp_desc =
                 Pexp_apply
                   ( { pexp_desc = Pexp_ident { txt = Lident "portable"; _ }; _ },
                     [ (Nolabel, name_expr) ] );
               _;
             } );
           (Nolabel, component_expr);
         ] );
   _;
  } ->
      {
        name = parse_name ~loc name_expr;
        msg_type = ptyp_constr ~loc (lident ~loc "t") [];
        portable_component = Some (parse_component_path ~loc component_expr);
      }
  | {
   pexp_desc =
     Pexp_apply
       ( { pexp_desc = Pexp_ident { txt = Lident "="; _ }; _ },
         [
           ( Nolabel,
             {
               pexp_desc =
                 Pexp_apply
                   ( { pexp_desc = Pexp_ident { txt = Lident "msg"; _ }; _ },
                     [ (Nolabel, name_expr) ] );
               _;
             } );
           (Nolabel, msg_type_expr);
         ] );
   _;
  } ->
      {
        name = parse_name ~loc name_expr;
        msg_type = parse_msg_type ~loc msg_type_expr;
        portable_component = None;
      }
  | _ ->
      loc_errorf ~loc
        "%%messenger_components expects lines like: portable Button = \
         Ui.Button; or msg Panel = Panel_msg.t;"

let parse_line = function
  | { pstr_desc = Pstr_eval (expr, []); _ } ->
      exprs_of_sequence expr |> List.map parse_expr
  | { pstr_loc = loc; _ } ->
      loc_errorf ~loc
        "%%messenger_components expects lines like: portable Button = \
         Ui.Button; or msg Panel = Panel_msg.t;"

let msg_type_of_portable_component_path ~loc component_path =
  ptyp_constr ~loc { loc; txt = Longident.Ldot (component_path.txt, "msg") } []

let normalize_entry entry =
  match entry.portable_component with
  | None -> entry
  | Some component_path ->
      let loc = entry.name.loc in
      {
        entry with
        msg_type = msg_type_of_portable_component_path ~loc component_path;
      }

let constructor_of_entry entry =
  let loc = entry.name.loc in
  constructor_declaration ~loc
    ~name:{ loc; txt = entry.name.txt ^ "Msg" }
    ~args:(Pcstr_tuple [ entry.msg_type ]) ~res:None

let parse_payload payload =
  List.concat_map parse_line payload |> List.map normalize_entry

let generated_type_decl ~loc entries =
  pstr_type ~loc Recursive
    [
      type_declaration ~loc
        ~name:{ loc; txt = "component_msg" }
        ~params:[] ~cstrs:[]
        ~kind:(Ptype_variant (List.map constructor_of_entry entries))
        ~private_:Public ~manifest:None;
    ]

let generated_wrap ~loc variant_name =
  pstr_value ~loc Nonrecursive
    [
      value_binding ~loc ~pat:(pvar ~loc "wrap_msg")
        ~expr:
          (pexp_function_cases ~loc
             [
               case ~lhs:(pvar ~loc "msg") ~guard:None
                 ~rhs:
                   (pexp_construct ~loc (lident ~loc variant_name)
                      (Some (evar ~loc "msg")));
             ]);
    ]

let generated_unwrap ~loc ~has_other_cases variant_name =
  let cases =
    [
      case
        ~lhs:
          (ppat_construct ~loc (lident ~loc variant_name)
             (Some (pvar ~loc "msg")))
        ~guard:None
        ~rhs:(pexp_construct ~loc (lident ~loc "Some") (Some (evar ~loc "msg")));
    ]
  in
  let cases =
    if has_other_cases then
      cases
      @ [
          case ~lhs:(ppat_any ~loc) ~guard:None
            ~rhs:(pexp_construct ~loc (lident ~loc "None") None);
        ]
    else cases
  in
  pstr_value ~loc Nonrecursive
    [
      value_binding ~loc ~pat:(pvar ~loc "unwrap_msg")
        ~expr:(pexp_function_cases ~loc cases);
    ]

let generated_component ~loc component_module_path =
  let component_path =
    {
      component_module_path with
      txt = Longident.Ldot (component_module_path.txt, "component");
    }
  in
  let adapt =
    pexp_ident ~loc
      {
        loc;
        txt = Longident.Ldot (Longident.Lident "Portable_component", "adapt");
      }
  in
  let body =
    pexp_apply ~loc adapt
      [
        (Labelled "target", evar ~loc "target");
        (Labelled "map_target", evar ~loc "map_target");
        (Labelled "wrap_msg", evar ~loc "wrap_msg");
        (Labelled "unwrap_msg", evar ~loc "unwrap_msg");
        (Nolabel, expr_of_longident ~loc component_path.txt);
        (Nolabel, evar ~loc "init_msg");
        (Nolabel, evar ~loc "runtime");
        (Nolabel, evar ~loc "env");
      ]
  in
  pstr_value ~loc Nonrecursive
    [
      value_binding ~loc ~pat:(pvar ~loc "component")
        ~expr:
          (pexp_fun ~loc (Labelled "target") None (pvar ~loc "target")
             (pexp_fun ~loc (Labelled "map_target") None
                (pvar ~loc "map_target")
                (pexp_fun ~loc Nolabel None (pvar ~loc "init_msg")
                   (pexp_fun ~loc Nolabel None (pvar ~loc "runtime")
                      (pexp_fun ~loc Nolabel None (pvar ~loc "env") body)))));
    ]

let generated_portable_module ~has_other_cases entry =
  match entry.portable_component with
  | None -> None
  | Some component_path ->
      let loc = entry.name.loc in
      let constructor_name = entry.name.txt ^ "Msg" in
      let module_name = module_name_of_constructor constructor_name in
      let body =
        [
          generated_wrap ~loc constructor_name;
          generated_unwrap ~loc ~has_other_cases constructor_name;
          generated_component ~loc component_path;
        ]
      in
      Some
        (pstr_module ~loc
           (module_binding ~loc
              ~name:{ loc; txt = Some module_name }
              ~expr:(pmod_structure ~loc body)))

let expand_payload ~loc payload =
  let entries = parse_payload payload in
  let has_other_cases = List.length entries > 1 in
  generated_type_decl ~loc entries
  :: List.filter_map (generated_portable_module ~has_other_cases) entries

let expand ~ctxt payload =
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  expand_payload ~loc payload

let extension =
  Extension.V3.declare_inline "messenger_components"
    Extension.Context.structure_item
    Ast_pattern.(pstr __)
    expand

let () =
  Driver.register_transformation "messenger_components"
    ~extensions:[ extension ]
