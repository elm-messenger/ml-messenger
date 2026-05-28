open Ml_regl_core
open Messenger

let texture ?opts name path = (name, Resources.Texture_res (path, opts))
let audio name path = (name, Resources.Audio_res path)
let font name image json = (name, Resources.Font_res (image, json))
let data name path = (name, Resources.Data_res path)

let sprite_sheet =
  let player_size = [ 13; 8; 10; 10; 10; 6; 4; 7 ] in
  List.concat
    (List.mapi
       (fun row colsize ->
         (* [player_size] stores the number of 32px cells in each row, not
            the max inclusive column index. The original Elm used
            [List.range 0 colsize], but with the checked image decoder this
            attempts e.g. row 0 col 13 at x=416 on a 416px-wide sheet. *)
         List.init colsize (fun col ->
             let opts = Some { Regl_proto.mag = Some MagNearest; min = None; crop = Some ((32 * col, 32 * row), (32, 32)) } in
             texture ?opts (Printf.sprintf "char%d%d" row col) "assets/img/sheet.png"))
       player_size)

let resources =
  [ texture "enemy" "assets/img/enemy.png";
    texture "mask" "assets/img/mask.jpg";
    texture "ship" "assets/img/ship.png";
    texture "sq" "assets/img/sq.jpg";
    audio "test" "assets/aud/test.ogg";
    font "firacode" "assets/fonts/font_0.png" "assets/fonts/FiraCode-Regular.json";
    data "texts" "assets/data/texts.json" ]
  @ sprite_sheet
