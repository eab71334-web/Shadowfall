extends Node2D
class_name Effects
# Hit flashes (white glow like the video), sparks, rings and floating numbers.

var items: Array = []


func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func flash(pos: Vector2, size := 40.0, dur := 0.2) -> void:
	items.append({"k": "flash", "p": pos, "t": 0.0, "d": dur, "s": size})


func ring(pos: Vector2, size := 60.0) -> void:
	items.append({"k": "ring", "p": pos, "t": 0.0, "d": 0.3, "s": size})


func sparks(pos: Vector2, dir: int, n := 8) -> void:
	for i in n:
		var a := randf_range(-0.9, 0.9) + (0.0 if dir > 0 else PI)
		var sp := 200.0 + randf() * 380.0
		items.append({"k": "spark", "p": pos, "v": Vector2.from_angle(a) * sp, "t": 0.0, "d": 0.25 + randf() * 0.2})


func text(pos: Vector2, str_: String, col := Color(1, 1, 1), size := 28) -> void:
	items.append({"k": "text", "p": pos, "t": 0.0, "d": 0.8, "str": str_, "c": col, "s": size})


func _process(delta: float) -> void:
	if items.is_empty():
		return
	var i := items.size() - 1
	while i >= 0:
		var it: Dictionary = items[i]
		it["t"] = float(it["t"]) + delta
		if it["k"] == "spark":
			it["p"] = it["p"] + it["v"] * delta
			it["v"] = it["v"] * 0.92
		elif it["k"] == "text":
			it["p"] = it["p"] + Vector2(0, -42.0 * delta)
		if float(it["t"]) >= float(it["d"]):
			items.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	var f: Font = Game.font if Game.font != null else ThemeDB.fallback_font
	for it in items:
		var k: float = float(it["t"]) / float(it["d"])
		var p: Vector2 = it["p"]
		match it["k"]:
			"flash":
				var sz: float = it["s"]
				for j in 6:
					var r := sz * (1.0 - float(j) / 6.0) * (0.6 + 0.4 * (1.0 - k))
					draw_circle(p, r, Color(1.0, 0.95, 0.85, 0.10 * (1.0 - k)))
				draw_circle(p, sz * 0.22 * (1.0 - k), Color(1, 1, 1, 0.9 * (1.0 - k)))
			"ring":
				draw_arc(p, float(it["s"]) * k, 0.0, TAU, 28, Color(1, 1, 1, 0.6 * (1.0 - k)), 3.0, true)
			"spark":
				var v: Vector2 = it["v"]
				draw_line(p, p - v * 0.04, Color(1, 0.95, 0.85, 1.0 - k), 2.0, true)
			"text":
				var c: Color = it["c"]
				c.a = 1.0 - k * k
				draw_string(f, p + Vector2(-40, 0), str(it["str"]), HORIZONTAL_ALIGNMENT_CENTER, 80.0, int(it["s"]), c)
