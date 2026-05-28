type component_target = int
type base_data = unit

type rect_init_data = {
  left : float;
  top : float;
  width : float;
  height : float;
  id : int;
  color : Ml_regl_core.Color.t;
}

type rect_msg = Ml_regl_core.Color.t
type rect_report_msg = int

type component_msg =
  | RectInit of rect_init_data
  | RectMsg of rect_msg
  | RectReportMsg of rect_report_msg
  | NullComponentMsg
