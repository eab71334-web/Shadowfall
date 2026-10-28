extends Node2D
class_name Stickman
# Black silhouette fighter drawn procedurally (idle, walk, jump, attack, hurt, death).
# Origin = feet on the ground. Local +x is the facing direction.

const LEG := 21.0
const TORSO := 29.0
const ARM := 15.0
const HEAD_R := 10.5

var s := 1.0
var facing := 1
var col := Color(0.025, 0.015, 0.015)
var weapon: Dictionary = {}
var vx := 0.0
var kbv := 0.0
var vy := 0.0
var on_ground := true
var dash_t := 0.0

var t := 0.0
var walk_t := 0.0
var atk_t := -1.0
var atk_dur := 0.35
var hurt_t := 0.0
var flash := 0.0
var dead := false
var dead_t := 0.0
var seed_ := 0.0

var hp := 100.0
var max_hp := 100.0
var kind := "grunt"
var atk_cd := 0.0
var hit_done := false
var dmg := 5.0
var spd := 100.0
var reach := 56.0
var is_player := false
var show_bar := 0.0


func _ready() -> void:
	seed_ = randf() * 100.0
	t = randf() * 6.0


func play_attack(dur: float) -> void:
	atk_t = 0.0
	atk_dur = dur
	hit_done = false


func is_attacking() -> bool:
	return atk_t >= 0.0


func attack_progress() -> float:
	if atk_t < 0.0:
		return -1.0
	return atk_t / atk_dur


func hurt() -> void:
	hurt_t = 0.22
	flash = 0.12


func die() -> void:
	dead = true
	dead_t = 0.0
	atk_t = -1.0
	flash = 0.12


func _process(delta: float) -> void:
	t += delta
	if dead:
		dead_t += delta
	else:
		if atk_t >= 0.0:
			atk_t += delta
			if atk_t >= atk_dur:
				atk_t = -1.0
		if hurt_t > 0.0:
			hurt_t -= delta
		if absf(vx) > 8.0 and on_ground:
			walk_t += delta * clampf(absf(vx) / 120.0, 0.6, 2.0)
	if flash > 0.0:
		flash -= delta
	if show_bar > 0.0:
		show_bar -= delta
	queue_redraw()
	if dead and dead_t > 0.8:
		set_process(false)


func _style() -> String:
	match String(weapon.get("kind", "fist")):
		"sword", "katana", "axe", "hammer":
			return "slash"
		"dagger", "spear":
			return "stab"
	return "punch"


func _limb(a: Vector2, target: Vector2, l1: float, l2: float, dir: float) -> PackedVector2Array:
	var v := target - a
	var d := v.length()
	if d < 0.001:
		return PackedVector2Array([a, a, a])
	var base := v / d
	d = minf(d, l1 + l2 - 0.05)
	var e := a + base * d
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var perp := Vector2(-base.y, base.x) * dir
	return PackedVector2Array([a, a + base * x + perp * h, e])


func _stroke(p: PackedVector2Array, c: Color, w: float) -> void:
	draw_polyline(p, c, w, true)
	draw_circle(p[0], w * 0.5, c)
	draw_circle(p[1], w * 0.5, c)
	draw_circle(p[2], w * 0.5, c)


func _draw() -> void:
	var fall := 0.0
	if dead:
		fall = clampf(dead_t / 0.42, 0.0, 1.0)
		fall = 1.0 - pow(1.0 - fall, 2.0)
	var rot := -float(facing) * fall * PI * 0.5
	draw_set_transform(Vector2.ZERO, rot, Vector2(float(facing) * s, s))
	var c := col.lerp(Color(1, 1, 1), clampf(flash / 0.12, 0.0, 1.0) * 0.9)
	var ap := attack_progress()
	var strike := 0.0
	if ap >= 0.0:
		strike = clampf((ap - 0.25) / 0.35, 0.0, 1.0)
	var moving := absf(vx) > 8.0 and on_ground and not dead
	var ph := walk_t * 9.0
	var bob := sin(t * 2.6) * 1.1
	var lean := 0.0
	var crouch := 0.0
	var f_back := Vector2(-7, 0)
	var f_front := Vector2(8, 0)
	if dead:
		bob = 0.0
		f_back = Vector2(-9.0 + sin(seed_) * 4.0, -2.0)
		f_front = Vector2(12.0 + cos(seed_) * 5.0, -6.0)
	elif not on_ground:
		f_back = Vector2(-9, -11)
		f_front = Vector2(11, -7)
		lean = 3.0
	elif ap >= 0.0:
		f_back = Vector2(-13, 0)
		f_front = Vector2(15, 0)
		lean = 2.0 + 8.0 * sin(clampf(ap, 0.0, 1.0) * PI)
		crouch = 3.0
	elif moving:
		f_back = Vector2(sin(ph) * 14.0, -maxf(0.0, cos(ph)) * 7.0)
		f_front = Vector2(sin(ph + PI) * 14.0, -maxf(0.0, cos(ph + PI)) * 7.0)
		bob = -absf(sin(ph)) * 2.2
		lean = 3.0
	if hurt_t > 0.0 and not dead:
		lean = -9.0

	var hip := Vector2(lean * 0.4, -(LEG * 2.0 - 4.0 - crouch) + bob)
	var neck := hip + Vector2(lean, -TORSO)
	var head := neck + Vector2(lean * 0.25 + 1.5, -HEAD_R - 2.5)
	var shoulder := neck + Vector2(0, 5)

	var wk := String(weapon.get("kind", "fist"))
	var idle_ang := -1.0
	match wk:
		"spear":
			idle_ang = -1.3
		"dagger":
			idle_ang = -0.5
		"axe", "hammer":
			idle_ang = -0.8
	var idle_hand := shoulder + Vector2(12, 13)
	var back_hand := shoulder + Vector2(-8, 15)
	if moving:
		idle_hand = shoulder + Vector2(8.0 + sin(ph + PI) * 6.0, 14)
		back_hand = shoulder + Vector2(-6.0 + sin(ph) * 8.0, 14)
	var hand_f := idle_hand
	var wang := idle_ang

	if dead:
		hand_f = shoulder + Vector2(12.0 + cos(seed_ * 2.0) * 8.0, 9.0 + sin(seed_ * 3.0) * 4.0)
		back_hand = shoulder + Vector2(-10.0 + sin(seed_ * 2.0) * 6.0, 10)
	elif ap >= 0.0:
		var eased := 1.0 - pow(1.0 - strike, 3.0)
		if _style() == "slash":
			var ang := 0.0
			if ap < 0.25:
				ang = lerpf(idle_ang, -2.5, ap / 0.25)
			else:
				ang = lerpf(-2.5, 0.95, eased)
			hand_f = shoulder + Vector2.from_angle(ang) * 13.0
			wang = ang
		else:
			var hx := 0.0
			if ap < 0.25:
				hx = lerpf(8.0, -4.0, ap / 0.25)
			else:
				hx = lerpf(-4.0, 24.0, eased)
			hand_f = shoulder + Vector2(hx + 4.0, 7.0)
			wang = lerpf(idle_ang, -0.02, clampf(ap / 0.25, 0.0, 1.0))
		back_hand = shoulder + Vector2(-7.0 - 5.0 * strike, 11)
		if ap > 0.7:
			var r := (ap - 0.7) / 0.3
			hand_f = hand_f.lerp(idle_hand, r)
			wang = lerpf(wang, idle_ang, r)
	elif hurt_t > 0.0:
		hand_f = shoulder + Vector2(-2, 15)
		back_hand = shoulder + Vector2(-9, 13)
		wang = -0.3

	var back_leg := _limb(hip, f_back, LEG, LEG, -1.0)
	var front_leg := _limb(hip, f_front, LEG, LEG, -1.0)
	var back_arm := _limb(shoulder, back_hand, ARM, ARM, 1.0)
	var front_arm := _limb(shoulder, hand_f, ARM, ARM, 1.0)

	_stroke(back_arm, c, 4.4)
	_stroke(back_leg, c, 5.6)
	draw_line(hip, neck, c, 6.4, true)
	draw_circle(hip, 3.2, c)
	draw_circle(head, HEAD_R, c)
	_stroke(front_leg, c, 5.6)
	_stroke(front_arm, c, 4.8)
	if not dead:
		_weapon(front_arm[2], wang, strike, shoulder)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if show_bar > 0.0 and not dead and not is_player:
		var by := -(LEG * 2.0 + TORSO + HEAD_R * 2.0 + 16.0) * s
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-18, by, 36, 4), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(-18, by, 36.0 * ratio, 4), Color(1, 1, 1, 0.95))


func _weapon(hand: Vector2, ang: float, strike: float, shoulder: Vector2) -> void:
	var k := String(weapon.get("kind", "fist"))
	var L := float(weapon.get("len", 0))
	var d := Vector2.from_angle(ang)
	var n := Vector2(-d.y, d.x)
	var steel := Color(0.9, 0.92, 0.95)
	match k:
		"fist":
			draw_circle(hand, 3.8, col)
		"dagger":
			draw_line(hand - d * 3.0, hand + d * L, steel, 2.8, true)
			draw_line(hand - n * 3.5, hand + n * 3.5, col, 2.6, true)
		"sword":
			draw_line(hand - d * 7.0, hand, col, 3.6, true)
			draw_line(hand - n * 5.5, hand + n * 5.5, col, 3.2, true)
			draw_line(hand, hand + d * L, Color(1, 1, 1, 0.18), 7.0, true)
			draw_line(hand, hand + d * L, steel, 3.2, true)
		"katana":
			var kc := Color(0.82, 0.93, 1.0)
			draw_line(hand - d * 8.0, hand, col, 3.4, true)
			draw_line(hand - n * 4.0, hand + n * 4.0, col, 3.0, true)
			draw_line(hand, hand + d * L, Color(0.7, 0.9, 1.0, 0.2), 7.0, true)
			draw_line(hand, hand + d * L, kc, 2.6, true)
		"spear":
			draw_line(hand - d * 22.0, hand + d * (L - 12.0), col, 3.2, true)
			var tip := hand + d * L
			draw_colored_polygon(PackedVector2Array([hand + d * (L - 15.0) + n * 4.5, tip, hand + d * (L - 15.0) - n * 4.5]), steel)
		"axe":
			draw_line(hand - d * 8.0, hand + d * L, col, 3.4, true)
			var e := hand + d * (L - 6.0)
			draw_colored_polygon(PackedVector2Array([e + n * 2.0 - d * 8.0, e + n * 18.0 + d * 2.0, e + n * 2.0 + d * 10.0]), Color(0.72, 0.74, 0.78))
		"hammer":
			draw_line(hand - d * 8.0, hand + d * L, col, 4.0, true)
			var e2 := hand + d * L
			draw_colored_polygon(PackedVector2Array([e2 + n * 11.0 - d * 7.0, e2 + n * 11.0 + d * 9.0, e2 - n * 11.0 + d * 9.0, e2 - n * 11.0 - d * 7.0]), Color(0.55, 0.56, 0.6))
	if strike > 0.0 and strike < 1.0 and _style() == "slash":
		draw_arc(shoulder, L + 14.0, ang - 1.2, ang, 12, Color(1, 1, 1, 0.5 * (1.0 - strike)), 3.0, true)
