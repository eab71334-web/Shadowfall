extends RefCounted
class_name UIKit

const CRIMSON := Color(0.78, 0.16, 0.20)
const GOLD := Color(1.0, 0.80, 0.30)
const PANEL := Color(0.08, 0.05, 0.06, 0.88)
const CARD := Color(0.13, 0.08, 0.09, 0.92)


static func box(bg: Color, border := Color(1, 1, 1, 0.18), radius := 14, bw := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func button(text: String, size := Vector2(300, 70), accent := false, fs := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	var base := CRIMSON if accent else Color(0.14, 0.09, 0.10, 0.92)
	var bord := Color(1.0, 0.55, 0.55, 0.9) if accent else Color(1, 1, 1, 0.28)
	b.add_theme_stylebox_override("normal", box(base, bord))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.1), bord))
	b.add_theme_stylebox_override("pressed", box(base.darkened(0.25), Color.WHITE))
	b.add_theme_stylebox_override("disabled", box(Color(0.10, 0.08, 0.08, 0.7), Color(1, 1, 1, 0.10)))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_font_size_override("font_size", fs)
	b.pressed.connect(func(): Game.sfx("ui"))
	return b


static func label(text: String, fs := 26, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", maxi(2, int(fs / 9.0)))
	return l


static func panel(bg := PANEL, border := Color(1, 1, 1, 0.16)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 18, 2))
	return p


static func coin_icon(sz := 30.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var m := Vector2(sz, sz) * 0.5
		c.draw_circle(m, sz * 0.48, Color(0.75, 0.5, 0.1))
		c.draw_circle(m, sz * 0.40, GOLD)
		c.draw_arc(m, sz * 0.24, 0.0, TAU, 20, Color(0.75, 0.5, 0.1), 2.0, true))
	return c
