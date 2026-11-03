extends Control
class_name TouchControls
# Two layouts:
#  - classic buttons (campaign): left / right / jump / dash / attack
#  - stick_mode (arena): LEFT stick = walk left/right, push UP = jump, push DOWN = crouch;
#                        RIGHT stick = aim anywhere (360 deg), push to the edge = fire / hit.
#    plus two small buttons: throw weapon (hand) and block (shield).

const STICK_R := 86.0
const FIRE_AT := 0.65

var held := {"left": false, "right": false, "jump": false, "attack": false, "dash": false, "block": false}
var pressed_at := {"jump": -1000, "attack": -1000, "dash": -1000}
var touches := {}
var rects := {}
var bot := false
var bot_axis := 0.0
var grab_mode := false
var stick_mode := false

var sl := Vector2.ZERO
var sr := Vector2.ZERO
var _sl_idx := -1
var _sr_idx := -1
var _sl_base := Vector2.ZERO
var _sr_base := Vector2.ZERO
var _sl_pos := Vector2.ZERO
var _sr_pos := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var sz := get_viewport_rect().size
	rects.clear()
	if stick_mode:
		rects["block"] = Vector3(sz.x - 330, sz.y - 90, 42)
		rects["dash"] = Vector3(sz.x - 262, sz.y - 215, 42)
	else:
		rects["left"] = Vector3(120, sz.y - 120, 62)
		rects["right"] = Vector3(290, sz.y - 120, 62)
		rects["attack"] = Vector3(sz.x - 130, sz.y - 125, 72)
		rects["jump"] = Vector3(sz.x - 290, sz.y - 95, 50)
		rects["dash"] = Vector3(sz.x - 235, sz.y - 240, 46)
		rects["block"] = Vector3(sz.x - 380, sz.y - 215, 44)
	queue_redraw()


func set_stick_mode(on: bool) -> void:
	stick_mode = on
	_layout()


func _hit(pos: Vector2) -> String:
	var best := ""
	var best_d := 1.0e9
	for n in rects:
		var r: Vector3 = rects[n]
		var d := pos.distance_to(Vector2(r.x, r.y))
		if d <= r.z * 1.25 and d < best_d:
			best = n
			best_d = d
	return best


func _press(idx: int, n: String) -> void:
	touches[idx] = n
	held[n] = true
	if pressed_at.has(n):
		pressed_at[n] = Time.get_ticks_msec()
	queue_redraw()


func _release(idx: int) -> void:
	if not touches.has(idx):
		return
	var n: String = touches[idx]
	touches.erase(idx)
	held[n] = touches.values().has(n)
	queue_redraw()


# ------------------------------------------------------------------ floating sticks
func _stick_down(idx: int, pos: Vector2) -> void:
	var sz := get_viewport_rect().size
	if pos.x < sz.x * 0.5:
		if _sl_idx == -1:
			_sl_idx = idx
			_sl_base = pos
			_sl_pos = pos
			sl = Vector2.ZERO
	elif _sr_idx == -1:
		_sr_idx = idx
		_sr_base = pos
		_sr_pos = pos
		sr = Vector2.ZERO
	queue_redraw()


func _stick_move(idx: int, pos: Vector2) -> void:
	if idx == _sl_idx:
		var d := pos - _sl_base
		if d.length() > STICK_R:
			_sl_base = pos - d.normalized() * STICK_R
			d = pos - _sl_base
		var was_up := sl.y < -0.55
		sl = d / STICK_R
		_sl_pos = _sl_base + d
		if sl.y < -0.55 and not was_up:
			pressed_at["jump"] = Time.get_ticks_msec()
	elif idx == _sr_idx:
		var d2 := pos - _sr_base
		if d2.length() > STICK_R:
			_sr_base = pos - d2.normalized() * STICK_R
			d2 = pos - _sr_base
		sr = d2 / STICK_R
		_sr_pos = _sr_base + d2
	queue_redraw()


func _stick_up(idx: int) -> void:
	if idx == _sl_idx:
		_sl_idx = -1
		sl = Vector2.ZERO
	if idx == _sr_idx:
		_sr_idx = -1
		sr = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var n := _hit(event.position)
			if n != "":
				_press(event.index, n)
			elif stick_mode:
				_stick_down(event.index, event.position)
		else:
			_release(event.index)
			_stick_up(event.index)
	elif event is InputEventScreenDrag:
		if stick_mode and (event.index == _sl_idx or event.index == _sr_idx):
			_stick_move(event.index, event.position)
		elif touches.has(event.index):
			var cur: String = touches[event.index]
			if cur == "left" or cur == "right":
				var n2 := _hit(event.position)
				if (n2 == "left" or n2 == "right") and n2 != cur:
					_release(event.index)
					_press(event.index, n2)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W, KEY_UP, KEY_SPACE:
				pressed_at["jump"] = Time.get_ticks_msec()
			KEY_J, KEY_Z:
				pressed_at["attack"] = Time.get_ticks_msec()
			KEY_K, KEY_X, KEY_SHIFT:
				pressed_at["dash"] = Time.get_ticks_msec()


# ------------------------------------------------------------------ API used by the game
func axis() -> float:
	if bot:
		return bot_axis
	var a := 0.0
	if stick_mode:
		if absf(sl.x) > 0.22:
			a = clampf(sl.x * 1.25, -1.0, 1.0)
	else:
		if held["left"]:
			a -= 1.0
		if held["right"]:
			a += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		a -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		a += 1.0
	return clampf(a, -1.0, 1.0)


func crouch() -> bool:
	if bot:
		return false
	return (stick_mode and sl.y > 0.6) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)


func aim_vec() -> Vector2:
	if stick_mode and sr.length() > 0.2:
		return sr.normalized()
	return Vector2.ZERO


func is_held(n: String) -> bool:
	if bot:
		return n == "attack"
	if n == "attack":
		if stick_mode:
			return sr.length() > FIRE_AT or Input.is_physical_key_pressed(KEY_J)
		return held["attack"] or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_Z)
	if n == "jump":
		return held["jump"] or (stick_mode and sl.y < -0.55) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SPACE)
	return held.get(n, false)


func consume(n: String) -> bool:
	if bot:
		if n == "jump":
			return randf() < 0.012
		if n == "dash":
			return randf() < 0.004
		return false
	if Time.get_ticks_msec() - int(pressed_at[n]) < 180:
		pressed_at[n] = -1000
		return true
	return false


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	var sz := get_viewport_rect().size
	if stick_mode:
		_draw_stick(Vector2(140, sz.y - 120), _sl_idx != -1, _sl_base, _sl_pos, false)
		_draw_stick(Vector2(sz.x - 140, sz.y - 120), _sr_idx != -1, _sr_base, _sr_pos, true)
	for n in rects:
		var r: Vector3 = rects[n]
		var c := Vector2(r.x, r.y)
		var on: bool = held.get(n, false)
		draw_circle(c, r.z, Color(0, 0, 0, 0.50 if on else 0.30))
		draw_arc(c, r.z, 0.0, TAU, 40, Color(1, 1, 1, 0.75 if on else 0.45), 3.0, true)
		_icon(n, c, r.z, Color(1, 1, 1, 0.95 if on else 0.65))


func _draw_stick(idle: Vector2, active: bool, base: Vector2, knob: Vector2, is_aim: bool) -> void:
	var c := base if active else idle
	var k := knob if active else idle
	draw_circle(c, STICK_R, Color(0, 0, 0, 0.30 if active else 0.20))
	draw_arc(c, STICK_R, 0.0, TAU, 48, Color(1, 1, 1, 0.65 if active else 0.35), 3.0, true)
	if is_aim:
		draw_arc(c, STICK_R * FIRE_AT, 0.0, TAU, 40, Color(1, 0.4, 0.3, 0.45), 2.0, true)
	else:
		var a := Color(1, 1, 1, 0.35)
		draw_polyline(PackedVector2Array([c + Vector2(-14, -STICK_R + 26), c + Vector2(0, -STICK_R + 12), c + Vector2(14, -STICK_R + 26)]), a, 4.0, true)
		draw_polyline(PackedVector2Array([c + Vector2(-14, STICK_R - 26), c + Vector2(0, STICK_R - 12), c + Vector2(14, STICK_R - 26)]), a, 4.0, true)
	draw_circle(k, 36.0, Color(1, 1, 1, 0.38 if active else 0.22))
	draw_arc(k, 36.0, 0.0, TAU, 28, Color(1, 1, 1, 0.8 if active else 0.45), 3.0, true)


func _icon(n: String, c: Vector2, r: float, col: Color) -> void:
	var u := r * 0.42
	match n:
		"left":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-u, 0), c + Vector2(u * 0.7, -u), c + Vector2(u * 0.7, u)]), col)
		"right":
			draw_colored_polygon(PackedVector2Array([c + Vector2(u, 0), c + Vector2(-u * 0.7, -u), c + Vector2(-u * 0.7, u)]), col)
		"jump":
			draw_polyline(PackedVector2Array([c + Vector2(-u, u * 0.5), c + Vector2(0, -u * 0.6), c + Vector2(u, u * 0.5)]), col, 5.0, true)
		"dash":
			if grab_mode:
				draw_arc(c + Vector2(0, -u * 0.2), u * 0.9, PI, TAU, 14, col, 4.0, true)
				draw_line(c + Vector2(-u * 0.9, -u * 0.2), c + Vector2(-u * 0.9, u * 0.8), col, 4.0, true)
				draw_line(c + Vector2(u * 0.9, -u * 0.2), c + Vector2(u * 0.9, u * 0.8), col, 4.0, true)
				draw_line(c + Vector2(-u * 0.9, u * 0.8), c + Vector2(u * 0.9, u * 0.8), col, 4.0, true)
			else:
				draw_polyline(PackedVector2Array([c + Vector2(-u, -u), c + Vector2(0, 0), c + Vector2(-u, u)]), col, 4.0, true)
				draw_polyline(PackedVector2Array([c + Vector2(0, -u), c + Vector2(u, 0), c + Vector2(0, u)]), col, 4.0, true)
		"block":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-u, -u), c + Vector2(u, -u), c + Vector2(u, u * 0.2), c + Vector2(0, u * 1.1), c + Vector2(-u, u * 0.2)]), col)
		"attack":
			draw_line(c + Vector2(-u, u), c + Vector2(u, -u), col, 6.0, true)
			draw_line(c + Vector2(-u, -u), c + Vector2(u, u), col, 6.0, true)
			draw_arc(c, u * 1.5, -0.6, 0.6, 10, Color(col.r, col.g, col.b, 0.5), 3.0, true)
