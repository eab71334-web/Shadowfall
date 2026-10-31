extends Node2D
class_name Ragdoll
# Floppy stick-figure ragdoll (Verlet points + distance links) that collides with platforms.

var pts: Array = []
var prv: Array = []
var links: Array = []
var rects: Array = []
var col := Color.WHITE
var acc := 0.0


func setup(feet: Vector2, c: Color, vel: Vector2, platforms: Array) -> void:
	col = c
	rects = platforms
	var base: Array = [
		Vector2(0, -92), Vector2(0, -80), Vector2(0, -42),
		Vector2(-8, -72), Vector2(-14, -54), Vector2(8, -72), Vector2(16, -56),
		Vector2(-5, -22), Vector2(-8, 0), Vector2(5, -22), Vector2(9, 0)]
	for b in base:
		pts.append(feet + (b as Vector2))
	for i in pts.size():
		var jitter := Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 10.0))
		prv.append((pts[i] as Vector2) - (vel + jitter) * (1.0 / 60.0))
	var pairs: Array = [[0, 1], [1, 2], [1, 3], [3, 4], [1, 5], [5, 6], [2, 7], [7, 8], [2, 9], [9, 10], [0, 2], [3, 5], [7, 9]]
	for pr in pairs:
		var a: Vector2 = base[pr[0]]
		var b: Vector2 = base[pr[1]]
		links.append([pr[0], pr[1], a.distance_to(b)])


func _process(delta: float) -> void:
	acc += minf(delta, 0.05)
	while acc >= 1.0 / 60.0:
		acc -= 1.0 / 60.0
		_step(1.0 / 60.0)
	queue_redraw()


func _step(dt: float) -> void:
	for i in pts.size():
		var p: Vector2 = pts[i]
		var q: Vector2 = prv[i]
		prv[i] = p
		pts[i] = p + (p - q) * 0.992 + Vector2(0, 1900.0) * dt * dt
	for it in 5:
		for l in links:
			var a: Vector2 = pts[l[0]]
			var b: Vector2 = pts[l[1]]
			var d := b - a
			var dist := d.length()
			if dist < 0.001:
				continue
			var diff := (dist - float(l[2])) / dist * 0.5
			pts[l[0]] = a + d * diff
			pts[l[1]] = b - d * diff
		_collide()


func _collide() -> void:
	for i in pts.size():
		var p: Vector2 = pts[i]
		for r in rects:
			var rr: Rect2 = r
			if not rr.has_point(p):
				continue
			var dl := p.x - rr.position.x
			var dr := rr.end.x - p.x
			var dtop := p.y - rr.position.y
			var dbot := rr.end.y - p.y
			var m := minf(minf(dl, dr), minf(dtop, dbot))
			var q: Vector2 = prv[i]
			if m == dtop:
				p.y = rr.position.y
				prv[i] = Vector2(lerpf(q.x, p.x, 0.25), p.y)
			elif m == dbot:
				p.y = rr.end.y
				prv[i] = Vector2(q.x, p.y)
			elif m == dl:
				p.x = rr.position.x
				prv[i] = Vector2(p.x, q.y)
			else:
				p.x = rr.end.x
				prv[i] = Vector2(p.x, q.y)
		pts[i] = p


func _draw() -> void:
	if pts.is_empty():
		return
	draw_line(pts[1], pts[2], col, 4.6, true)
	for pr in [[1, 3], [3, 4], [1, 5], [5, 6], [2, 7], [7, 8], [2, 9], [9, 10]]:
		draw_line(pts[pr[0]], pts[pr[1]], col, 3.8, true)
	draw_line(pts[0], pts[1], col, 3.0, true)
	draw_circle(pts[0], 10.5, col)
