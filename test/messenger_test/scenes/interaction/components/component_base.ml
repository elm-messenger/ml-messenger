type component_target = string

type base_data = unit

type button_init_data = {
  button_center : float * float;
  button_size : float * float;
  button_color : Ml_regl_core.Color.t;
  button_content : string;
}

type button_msg = ButtonPressed | ButtonReleased

type slider_init_data = { slider_init_value : float; slider_center : float * float; slider_width : float }

type slider_msg = float

type component_msg =
  | ButtonInitMsg of button_init_data
  | ButtonUpdateMsg of button_msg
  | SliderInitMsg of slider_init_data
  | SliderUpdateMsg of slider_msg
  | NullComponentMsg
