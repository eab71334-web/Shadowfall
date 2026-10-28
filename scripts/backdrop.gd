extends Node2D
class_name Backdrop
# Dusty rose-brown sky, black ground with a thin glowing white line (like the reference video).

var world := 0
var ground_y := 468.0
var vw := 1280.0
var vh := 600.0
var dust: Array = []
var ridge1 := PackedVector2Array()
var ridge2 := PackedVector2Array()
var ground_line := PackedVector2Array()
var tt := 0.0

var sky_top := [Color(0.62, 0.42, 0.38), Color(0.42, 0.18, 0.20), Color(0.21, 0.24, 0.35)]
var sky_bot := [Color(0.48, 0.30, 0.27), Color(0.25, 0.09, 0.12), Color(0.09, 0.10, 0.17)]


func _ready() -> void:
	z_index = -20
	world = clampi(world, 0, 2)
	var sz := get_viewport_rect().size
	vw = sz.x
	vh = sz.y
	ground_y = vh * 0.78
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + world
	for i in 46:
		dust.append(Vector3(rng.randf() * vw, rng.randf() * ground_y, 6.0 + rng.randf() * 22.0))
	ridge1 = _ridge(rng, ground_y - 150.0, 90.0)
	ridge2 = _ridge(rng, ground_y - 70.0, 60.0)
	var x := -20.0
	while x < vw + 40.0:
		ground_line.append(Vector2(x, ground_y + rng.randf_range(-1.4, 1.4)))
		x += 28.0


func _ridge(rng: RandomNumberGenerator, base: float, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var phase := rng.randf() * 6.0
	var x := -20.0
	while x < vw + 80.0:
		var y := base - absf(sin(x * 0.006 + phase)) * amp - rng.randf() * 14.0
		pts.append(Vector2(x, y))
		x += 60.0
	pts.append(Vector2(vw + 80.0, ground_y))
	pts.append(Vector2(-20.0, ground_y))
	return pts


func _process(delta: float) -> void:
	tt += delta
	for i in dust.size():
		var d: Vector3 = dust[i]
		d.x += d.z * delta
		d.y += sin(tt * 0.8 + float(i)) * 5.0 * delta
		if d.x > vw + 10.0:
			d.x = -10.0
		dust[i] = d
	queue_redraw()


func _draw() -> void:
	var top: Color = sky_top[world]
	var bot: Color = sky_bot[world]
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(vw, 0), Vector2(vw, ground_y), Vector2(0, ground_y)]),
		PackedColorArray([top, top, bot, bot]))
	# soft sun / moon glow
	var gc := Vector2(vw * 0.68, ground_y * 0.42)
	for i in 7:
		draw_circle(gc, 260.0 - float(i) * 34.0, Color(1.0, 0.85, 0.72, 0.035))
	draw_colored_polygon(ridge1, Color(0, 0, 0, 0.10))
	draw_colored_polygon(ridge2, Color(0, 0, 0, 0.17))
	for d in dust:
		draw_circle(Vector2(d.x, d.y), 1.3, Color(1, 1, 1, 0.45))
	# ground
	draw_rect(Rect2(0, ground_y, vw, vh - ground_y), Color(0.02, 0.015, 0.015))
	draw_polyline(ground_line, Color(1, 1, 1, 0.16), 10.0, true)
	draw_polyline(ground_line, Color(1, 1, 1, 0.95), 2.4, true)
	# vignette
	var a := Color(0, 0, 0, 0.55)
	var z := Color(0, 0, 0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vw * 0.22, 0), Vector2(vw * 0.22, vh), Vector2(0, vh)]), PackedColorArray([a, z, z, a]))
	draw_polygon(PackedVector2Array([Vector2(vw, 0), Vector2(vw * 0.78, 0), Vector2(vw * 0.78, vh), Vector2(vw, vh)]), PackedColorArray([a, z, z, a]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vw, 0), Vector2(vw, vh * 0.2), Vector2(0, vh * 0.2)]), PackedColorArray([a, a, z, z]))
