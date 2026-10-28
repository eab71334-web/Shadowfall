extends Control
class_name TouchControls
# Multi-touch buttons: left / right / jump / dash / attack. Keyboard works too (A D W K J / arrows).

var held := {"left": false, "right": false, "jump": false, "attack": false, "dash": false}
var pressed_at := {"jump": -1000, "attack": -1000, "dash": -1000}
var touches := {}
var rects := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var sz := get_viewport_rect().size
	rects["left"] = Vector3(120, sz.y - 120, 62)
	rects["right"] = Vector3(290, sz.y - 120, 62)
	rects["attack"] = Vector3(sz.x - 130, sz.y - 125, 72)
	rects["jump"] = Vector3(sz.x - 290, sz.y - 95, 50)
	rects["dash"] = Vector3(sz.x - 235, sz.y - 240, 46)
	queue_redraw()


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


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var n := _hit(event.position)
			if n != "":
				_press(event.index, n)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if touches.has(event.index):
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


func axis() -> float:
	var a := 0.0
	if held["left"] or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		a -= 1.0
	if held["right"] or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		a += 1.0
	return a


func is_held(n: String) -> bool:
	if n == "attack":
		return held["attack"] or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_Z)
	return held.get(n, false)


func consume(n: String) -> bool:
	if Time.get_ticks_msec() - int(pressed_at[n]) < 180:
		pressed_at[n] = -1000
		return true
	return false


func _draw() -> void:
	for n in rects:
		var r: Vector3 = rects[n]
		var c := Vector2(r.x, r.y)
		var on: bool = held.get(n, false)
		draw_circle(c, r.z, Color(0, 0, 0, 0.50 if on else 0.30))
		draw_arc(c, r.z, 0.0, TAU, 40, Color(1, 1, 1, 0.75 if on else 0.45), 3.0, true)
		_icon(n, c, r.z, Color(1, 1, 1, 0.95 if on else 0.65))


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
			draw_polyline(PackedVector2Array([c + Vector2(-u, -u), c + Vector2(0, 0), c + Vector2(-u, u)]), col, 4.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(0, -u), c + Vector2(u, 0), c + Vector2(0, u)]), col, 4.0, true)
		"attack":
			draw_line(c + Vector2(-u, u), c + Vector2(u, -u), col, 6.0, true)
			draw_line(c + Vector2(-u, -u), c + Vector2(u, u), col, 6.0, true)
			draw_arc(c, u * 1.5, -0.6, 0.6, 10, Color(col.r, col.g, col.b, 0.5), 3.0, true)
