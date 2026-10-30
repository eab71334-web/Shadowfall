extends Node2D
class_name Stickman
# Pose-based stickman rig. Silhouette style, thick tapered limbs, big head, IK knees/elbows.
# Origin = feet on the ground. Local +x = facing direction.
#
# Poses are dictionaries: hx,hy (hip offset), ta (torso lean, rad, + = forward),
# hf/hb (front/back hand relative to shoulder), ff/fb (front/back foot), wa (weapon angle).

const LEG_U := 24.0
const LEG_L := 24.0
const TORSO := 32.0
const ARM_U := 15.0
const ARM_L := 15.0
const HEAD_R := 13.0
const HIP_H := 42.0

# dur = seconds at normal weapon speed, hit/ms/me = normalized times (hit moment, lunge window)
const ATK := {
	"slash_down": {"dur": 0.46, "hit": 0.40, "ms": 0.28, "me": 0.46, "lunge": 70.0, "dmg": 1.0, "kb": 1.0, "reach": 0.0},
	"slash_back": {"dur": 0.42, "hit": 0.38, "ms": 0.26, "me": 0.44, "lunge": 60.0, "dmg": 1.1, "kb": 1.2, "reach": 8.0},
	"kick": {"dur": 0.42, "hit": 0.43, "ms": 0.30, "me": 0.50, "lunge": 40.0, "dmg": 0.9, "kb": 1.8, "reach": 0.0, "abs": 70.0},
	"thrust": {"dur": 0.54, "hit": 0.44, "ms": 0.30, "me": 0.52, "lunge": 120.0, "dmg": 1.5, "kb": 2.0, "reach": 26.0},
	"air": {"dur": 0.40, "hit": 0.40, "ms": 0.20, "me": 0.50, "lunge": 50.0, "dmg": 1.2, "kb": 1.2, "reach": 8.0},
}

var s := 1.0
var facing := 1
var col := Color(0.025, 0.015, 0.015)
var weapon: Dictionary = {}
var vx := 0.0
var kbv := 0.0
var vy := 0.0
var on_ground := true
var dash_t := 0.0
var land_t := 0.0
var pop_y := 0.0
var pop_vy := 0.0

var t := 0.0
var walk_t := 0.0
var atk_t := -1.0
var atk_dur := 0.4
var atk_type := "slash_down"
var cur_atk: Dictionary = {}
var lunge_total := 0.0
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
var flip := false
# per-fighter gameplay state (used by battle.gd for every player)
var combo := 0
var combo_t := 0.0
var queued_t := 0.0
var coyote := 0.0
var jump_cut := false
var run_dust_t := 0.0
var dash_cd := 0.0
var finisher := false
var dmg_mult := 1.0
var spd_mult := 1.0
# networking
var net_id := 0
var tag := ""
var nx := 0.0
var ny := 0.0
var seen_t := 0.0

var _kc := {}


func _ready() -> void:
	seed_ = randf() * 100.0
	t = randf() * 6.0


# ------------------------------------------------------------------ API
func style() -> String:
	match String(weapon.get("kind", "fist")):
		"sword", "katana", "axe", "hammer":
			return "slash"
		"dagger", "spear":
			return "stab"
	return "punch"


func play_attack(type_: String, dur: float) -> void:
	atk_type = type_
	cur_atk = ATK[type_]
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
	hurt_t = 0.26
	flash = 0.12
	atk_t = -1.0


func die() -> void:
	dead = true
	dead_t = 0.0
	atk_t = -1.0
	flash = 0.12
	pop_vy = -300.0


func revive(hp_frac: float) -> void:
	dead = false
	dead_t = 0.0
	flip = false
	hurt_t = 0.0
	atk_t = -1.0
	pop_y = 0.0
	pop_vy = 0.0
	kbv = 0.0
	vx = 0.0
	vy = 0.0
	on_ground = true
	hp = max_hp * hp_frac
	set_process(true)


func make_corpse() -> void:
	dead = true
	dead_t = 1.0
	pop_y = 0.0
	pop_vy = 0.0
	atk_t = -1.0


func _stride() -> float:
	return lerpf(8.0, 24.0, clampf(absf(vx) / 330.0, 0.0, 1.0))


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
		if land_t > 0.0:
			land_t -= delta
		if absf(vx) > 12.0 and on_ground and pop_y > -1.0:
			walk_t += absf(vx) * PI / (2.0 * _stride()) * delta
	if pop_y < 0.0 or pop_vy < 0.0:
		pop_vy += 1900.0 * delta
		pop_y += pop_vy * delta
		if pop_y >= 0.0:
			pop_y = 0.0
			if dead and absf(pop_vy) > 220.0:
				pop_vy = -pop_vy * 0.25
			else:
				pop_vy = 0.0
	if flash > 0.0:
		flash -= delta
	if show_bar > 0.0:
		show_bar -= delta
	queue_redraw()
	if dead and dead_t > 1.0 and pop_y == 0.0 and pop_vy == 0.0:
		set_process(false)


# ------------------------------------------------------------------ poses
func _pose(hipx: float, hipy: float, ta: float, hf: Vector2, hb: Vector2, ff: Vector2, fb: Vector2, wa: float) -> Dictionary:
	return {"hx": hipx, "hy": hipy, "ta": ta, "hf": hf, "hb": hb, "ff": ff, "fb": fb, "wa": wa}


func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var r := {}
	for key in a:
		r[key] = lerp(a[key], b[key], k)
	return r


func _ease(kind_: String, k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	match kind_:
		"o":
			return 1.0 - pow(1.0 - k, 3.0)
		"i":
			return k * k
	return k * k * (3.0 - 2.0 * k)


func _idle_pose() -> Dictionary:
	var br := sin(t * 2.4)
	return _pose(0.0, 4.0 + br * 1.2, 0.10 + br * 0.015, Vector2(15, 12.0 + br * 1.5), Vector2(5, 15), Vector2(13, 0), Vector2(-11, 0), 1.0 + br * 0.04)


func _run_pose() -> Dictionary:
	var k := clampf(absf(vx) / 300.0, 0.0, 1.0)
	var S := lerpf(8.0, 24.0, k)
	var H := lerpf(5.0, 17.0, k)
	var p := walk_t
	var fa := Vector2(S * cos(p), -H * maxf(0.0, -sin(p)))
	var fo := Vector2(S * cos(p + PI), -H * maxf(0.0, -sin(p + PI)))
	var bob := -absf(sin(p)) * lerpf(1.0, 4.0, k)
	var sw := cos(p)
	var hf := Vector2(8.0 - 12.0 * sw * k, 12.0 - 8.0 * absf(sin(p)) * k)
	var hb := Vector2(2.0 + 12.0 * sw * k, 11.0 - 7.0 * absf(sin(p)) * k)
	return _pose(2.0 * k, lerpf(4.0, 8.0, k) + bob, 0.10 + 0.32 * k, hf, hb, fa, fo, lerpf(1.1, 1.9, k))


func _air_pose() -> Dictionary:
	var kk := clampf((vy + 500.0) / 1000.0, 0.0, 1.0)
	if on_ground:
		kk = clampf((pop_vy + 300.0) / 600.0, 0.0, 1.0)
	var rise := _pose(0.0, 0.0, 0.12, Vector2(10, -8), Vector2(-4, -14), Vector2(12, -20), Vector2(-8, -8), -0.6)
	var fall := _pose(0.0, 0.0, 0.05, Vector2(14, -2), Vector2(-10, -6), Vector2(8, -6), Vector2(-4, -4), 0.4)
	return _mix(rise, fall, kk)


func _base_pose() -> Dictionary:
	if dash_t > 0.0:
		return _pose(4.0, 6.0, 0.62, Vector2(-8, 10), Vector2(-14, 8), Vector2(26, 0), Vector2(-26, -4), 2.2)
	if (not on_ground) or pop_y < -3.0:
		return _air_pose()
	if land_t > 0.0:
		var lk := clampf(land_t / 0.14, 0.0, 1.0)
		return _mix(_idle_pose(), _pose(2.0, 10.0, 0.25, Vector2(16, 12), Vector2(0, 14), Vector2(18, 0), Vector2(-16, 0), 1.0), lk)
	if absf(vx) > 12.0:
		return _run_pose()
	return _idle_pose()


func _keys(type_: String) -> Array:
	if _kc.has(type_):
		return _kc[type_]
	var k: Array = []
	match type_:
		"slash_down":
			k = [
				[0.28, _pose(-3, 3, -0.16, Vector2(-8, -23), Vector2(-2, -15), Vector2(16, 0), Vector2(-14, 0), -2.4), "io"],
				[0.42, _pose(10, 9, 0.50, Vector2(22, 13), Vector2(-14, 9), Vector2(26, 0), Vector2(-18, 0), 0.9), "o"],
				[0.66, _pose(12, 10, 0.55, Vector2(24, 16), Vector2(-15, 10), Vector2(27, 0), Vector2(-19, 0), 1.15), "io"],
			]
		"slash_back":
			k = [
				[0.26, _pose(-2, 4, 0.14, Vector2(-12, 9), Vector2(14, -4), Vector2(4, 0), Vector2(-16, 0), 2.8), "io"],
				[0.40, _pose(8, 8, 0.42, Vector2(25, -7), Vector2(-12, 8), Vector2(22, 0), Vector2(-18, 0), -0.25), "o"],
				[0.64, _pose(9, 9, 0.40, Vector2(23, -12), Vector2(-13, 9), Vector2(23, 0), Vector2(-19, 0), -0.7), "io"],
			]
		"kick":
			k = [
				[0.30, _pose(0, 6, 0.04, Vector2(12, 4), Vector2(8, 8), Vector2(10, -26), Vector2(-8, 0), 1.2), "io"],
				[0.44, _pose(-4, 4, -0.22, Vector2(-10, 4), Vector2(-14, 8), Vector2(44, -32), Vector2(-8, 0), 0.8), "o"],
				[0.66, _pose(-4, 4, -0.20, Vector2(-8, 6), Vector2(-12, 8), Vector2(40, -28), Vector2(-8, 0), 0.8), "io"],
			]
		"thrust":
			k = [
				[0.30, _pose(-4, 8, 0.06, Vector2(-2, 4), Vector2(-8, 8), Vector2(4, 0), Vector2(-20, 0), 0.0), "io"],
				[0.44, _pose(14, 12, 0.62, Vector2(29, 1), Vector2(-14, 10), Vector2(34, 0), Vector2(-22, 0), 0.0), "o"],
				[0.68, _pose(15, 12, 0.64, Vector2(29, 2), Vector2(-15, 10), Vector2(35, 0), Vector2(-23, 0), 0.05), "io"],
			]
		"air":
			k = [
				[0.26, _pose(0, 0, 0.10, Vector2(-6, -20), Vector2(-2, -12), Vector2(10, -14), Vector2(-6, -8), -2.2), "io"],
				[0.42, _pose(2, 0, 0.38, Vector2(22, 14), Vector2(-12, 8), Vector2(14, -10), Vector2(-8, -14), 1.0), "o"],
				[0.70, _pose(2, 0, 0.34, Vector2(23, 16), Vector2(-12, 9), Vector2(14, -8), Vector2(-8, -12), 1.1), "io"],
			]
	_kc[type_] = k
	return k


func _attack_pose(type_: String, ap: float, base: Dictionary) -> Dictionary:
	var keys := _keys(type_)
	var prev_t := 0.0
	var prev_p := base
	for kf in keys:
		var kt: float = kf[0]
		if ap <= kt:
			var k := (ap - prev_t) / maxf(kt - prev_t, 0.0001)
			return _mix(prev_p, kf[1], _ease(kf[2], k))
		prev_t = kt
		prev_p = kf[1]
	var k2 := (ap - prev_t) / maxf(1.0 - prev_t, 0.0001)
	return _mix(prev_p, base, _ease("io", clampf(k2, 0.0, 1.0)))


# ------------------------------------------------------------------ drawing helpers
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


func _stroke(p: PackedVector2Array, c: Color, w1: float, w2: float) -> void:
	draw_line(p[0], p[1], c, w1, true)
	draw_line(p[1], p[2], c, w2, true)
	draw_circle(p[0], w1 * 0.5, c)
	draw_circle(p[1], (w1 + w2) * 0.25 + 0.5, c)
	draw_circle(p[2], w2 * 0.5, c)


func _draw() -> void:
	var pose_: Dictionary
	var rot := 0.0
	var lie_k := 0.0
	if dead:
		var flail := _pose(0, 0, -0.9, Vector2(-16, -12), Vector2(-20, 2), Vector2(14, -12), Vector2(-12, -4), -1.0)
		var lie := _pose(0, 4, -0.1, Vector2(14.0 + sin(seed_) * 4.0, 8), Vector2(-12, 10.0 + cos(seed_) * 3.0), Vector2(16, -6), Vector2(-10.0 + sin(seed_ * 2.0) * 4.0, -2), 1.5)
		pose_ = _mix(flail, lie, _ease("io", (dead_t - 0.25) / 0.35))
		lie_k = _ease("o", dead_t / 0.36)
		rot = -float(facing) * lie_k * PI * 0.5 + sin(seed_) * 0.08 * lie_k
		if flip:
			rot -= float(facing) * TAU * _ease("o", dead_t / 0.7)
	else:
		var base := _base_pose()
		var ap0 := attack_progress()
		if ap0 >= 0.0:
			pose_ = _attack_pose(atk_type, ap0, base)
		else:
			pose_ = base
		if hurt_t > 0.0:
			var hurt_pose := _pose(-4, 6, -0.36, Vector2(-8, -18), Vector2(-14, -8), Vector2(10, 0), Vector2(-14, 0), -2.0)
			pose_ = _mix(pose_, hurt_pose, clampf(hurt_t / 0.26, 0.0, 1.0))
		if pop_y < -3.0:
			rot = -float(facing) * minf(0.5, -pop_y / 90.0)

	draw_set_transform(Vector2(0, pop_y - 6.0 * lie_k), rot, Vector2(float(facing) * s, s))
	var c := col.lerp(Color(1, 1, 1), clampf(flash / 0.12, 0.0, 1.0) * 0.9)

	var hx: float = pose_["hx"]
	var hy: float = pose_["hy"]
	var ta: float = pose_["ta"]
	var hf: Vector2 = pose_["hf"]
	var hb: Vector2 = pose_["hb"]
	var ff: Vector2 = pose_["ff"]
	var fb: Vector2 = pose_["fb"]
	var wa: float = pose_["wa"]

	var hip := Vector2(hx, -HIP_H + hy)
	var tdir := Vector2(sin(ta), -cos(ta))
	var shoulder := hip + tdir * (TORSO - 3.0)
	var neck := hip + tdir * TORSO
	var hta := ta * 1.15
	var head := neck + Vector2(sin(hta), -cos(hta)) * (HEAD_R + 1.0)

	var leg_b := _limb(hip, fb, LEG_U, LEG_L, -1.0)
	var leg_f := _limb(hip, ff, LEG_U, LEG_L, -1.0)
	var arm_b := _limb(shoulder, shoulder + hb, ARM_U, ARM_L, 1.0)
	var arm_f := _limb(shoulder, shoulder + hf, ARM_U, ARM_L, 1.0)

	if dash_t > 0.0:
		for i in 4:
			draw_line(Vector2(-34.0 - i * 8.0, -85.0 + i * 20.0), Vector2(-100.0 - i * 12.0, -85.0 + i * 20.0), Color(1, 1, 1, 0.30), 2.0, true)

	_stroke(arm_b, c, 5.8, 4.8)
	_stroke(leg_b, c, 8.2, 6.4)
	draw_line(leg_b[2], leg_b[2] + Vector2(7, 0), c, 5.0, true)
	draw_line(hip, shoulder, c, 9.5, true)
	draw_circle(hip, 5.2, c)
	draw_circle(shoulder, 5.8, c)
	draw_line(shoulder, neck, c, 5.2, true)
	draw_circle(head, HEAD_R, c)
	_stroke(leg_f, c, 8.2, 6.4)
	draw_line(leg_f[2], leg_f[2] + Vector2(7, 0), c, 5.0, true)
	_stroke(arm_f, c, 6.0, 5.0)
	draw_circle(arm_f[2], 3.8, c)
	if not dead:
		_weapon(arm_f[2], wa, shoulder)
		_smear(arm_f[2], wa, leg_f[2])

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tag != "" and not dead:
		var ty := -(HIP_H + TORSO + HEAD_R * 2.0 + 30.0) * s + pop_y
		var tf: Font = Game.font if Game.font != null else ThemeDB.fallback_font
		draw_string(tf, Vector2(-60, ty), tag, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, Color(1, 1, 1, 0.85))
	if show_bar > 0.0 and not dead and not is_player:
		var by := -(HIP_H + TORSO + HEAD_R * 2.0 + 18.0) * s + pop_y
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-18, by, 36, 4), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(-18, by, 36.0 * ratio, 4), Color(1, 1, 1, 0.95))


func _smear(hand: Vector2, wa: float, foot: Vector2) -> void:
	var ap := attack_progress()
	if ap < 0.0 or cur_atk.is_empty():
		return
	var ms: float = cur_atk["ms"]
	var me: float = cur_atk["me"]
	if ap < ms or ap > me + 0.22:
		return
	var fade := 1.0 - (ap - ms) / (me - ms + 0.22)
	var L := float(weapon.get("len", 0)) + 10.0
	match atk_type:
		"slash_down", "slash_back":
			if style() != "slash":
				return
			var a_from := -2.4 if atk_type == "slash_down" else 2.8
			if absf(wa - a_from) < 0.2:
				return
			var outer := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in 9:
				var ang := lerpf(a_from, wa, float(i) / 8.0)
				var dv := Vector2.from_angle(ang)
				outer.append(hand + dv * L)
				inner.append(hand + dv * L * 0.45)
			inner.reverse()
			outer.append_array(inner)
			draw_colored_polygon(outer, Color(1, 1, 1, 0.30 * fade))
		"thrust", "air":
			for i in 3:
				var y := -6.0 + float(i) * 6.0
				draw_line(hand + Vector2(-8.0 - i * 10.0, y), hand + Vector2(-60.0 - i * 14.0, y), Color(1, 1, 1, 0.40 * fade), 2.0, true)
		"kick":
			for i in 3:
				draw_line(foot + Vector2(-6.0, -6.0 + i * 6.0), foot + Vector2(-50.0, -10.0 + i * 8.0), Color(1, 1, 1, 0.40 * fade), 2.0, true)


func _weapon(hand: Vector2, ang: float, shoulder: Vector2) -> void:
	var k := String(weapon.get("kind", "fist"))
	var L := float(weapon.get("len", 0)) * 1.1
	var d := Vector2.from_angle(ang)
	var n := Vector2(-d.y, d.x)
	var steel := Color(0.9, 0.92, 0.95)
	match k:
		"dagger":
			draw_line(hand - d * 3.0, hand + d * L, steel, 3.0, true)
			draw_line(hand - n * 3.5, hand + n * 3.5, col, 2.8, true)
		"sword":
			draw_line(hand - d * 7.0, hand, col, 3.8, true)
			draw_line(hand - n * 6.0, hand + n * 6.0, col, 3.4, true)
			draw_line(hand, hand + d * L, Color(1, 1, 1, 0.20), 8.0, true)
			draw_line(hand, hand + d * L, steel, 3.4, true)
		"katana":
			var kc := Color(0.82, 0.93, 1.0)
			draw_line(hand - d * 9.0, hand, col, 3.6, true)
			draw_line(hand - n * 4.5, hand + n * 4.5, col, 3.2, true)
			draw_line(hand, hand + d * L, Color(0.7, 0.9, 1.0, 0.22), 8.0, true)
			draw_line(hand, hand + d * L, kc, 2.8, true)
		"spear":
			draw_line(hand - d * 24.0, hand + d * (L - 12.0), col, 3.4, true)
			var tip := hand + d * L
			draw_colored_polygon(PackedVector2Array([hand + d * (L - 16.0) + n * 5.0, tip, hand + d * (L - 16.0) - n * 5.0]), steel)
		"axe":
			draw_line(hand - d * 8.0, hand + d * L, col, 3.6, true)
			var e := hand + d * (L - 6.0)
			draw_colored_polygon(PackedVector2Array([e + n * 2.0 - d * 9.0, e + n * 19.0 + d * 2.0, e + n * 2.0 + d * 11.0]), Color(0.72, 0.74, 0.78))
		"hammer":
			draw_line(hand - d * 8.0, hand + d * L, col, 4.2, true)
			var e2 := hand + d * L
			draw_colored_polygon(PackedVector2Array([e2 + n * 12.0 - d * 8.0, e2 + n * 12.0 + d * 10.0, e2 - n * 12.0 + d * 10.0, e2 - n * 12.0 - d * 8.0]), Color(0.55, 0.56, 0.6))
