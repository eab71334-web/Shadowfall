extends RefCounted
class_name WeaponArt

const GUNS := {
	"pistol": {"b": 16, "t": 6.0, "c": Color(0.14, 0.15, 0.19), "grip": 10},
	"revolver": {"b": 18, "t": 6.0, "c": Color(0.35, 0.3, 0.3), "grip": 11, "cyl": true},
	"deagle": {"b": 22, "t": 8.0, "c": Color(0.7, 0.7, 0.76), "grip": 11},
	"uzi": {"b": 18, "t": 6.0, "c": Color(0.14, 0.15, 0.19), "grip": 9, "mag": 14},
	"godpistol": {"b": 18, "t": 7.0, "c": Color(1.0, 0.82, 0.2), "grip": 10, "glow": true},
	"ak47": {"b": 34, "t": 5.0, "c": Color(0.2, 0.2, 0.22), "mag": 14, "stock": 18, "wood": true},
	"m16": {"b": 36, "t": 5.0, "c": Color(0.14, 0.15, 0.19), "mag": 12, "stock": 16},
	"m1": {"b": 38, "t": 5.0, "c": Color(0.45, 0.3, 0.18), "stock": 18, "wood": true},
	"sniper": {"b": 48, "t": 4.5, "c": Color(0.14, 0.15, 0.19), "scope": true, "stock": 20, "wood": true},
	"sawedoff": {"b": 22, "t": 7.0, "c": Color(0.14, 0.15, 0.19), "stock": 10, "wood": true, "double": true},
	"shotgun": {"b": 34, "t": 5.5, "c": Color(0.14, 0.15, 0.19), "stock": 18, "wood": true, "pump": true},
	"bouncer": {"b": 26, "t": 7.0, "c": Color(0.7, 0.3, 0.9), "grip": 9},
	"grenade": {"b": 24, "t": 12.0, "c": Color(0.3, 0.4, 0.3), "grip": 9},
	"rpg": {"b": 40, "t": 11.0, "c": Color(0.35, 0.37, 0.3), "tip": true, "stock": 16},
	"snake": {"b": 20, "t": 7.0, "c": Color(0.3, 0.7, 0.3), "grip": 9, "snake": true},
	"flame": {"b": 26, "t": 7.0, "c": Color(0.8, 0.3, 0.2), "tank": true, "grip": 8},
	"minigun": {"b": 34, "t": 11.0, "c": Color(0.3, 0.3, 0.35), "multi": true, "grip": 8},
	"laser": {"b": 26, "t": 7.0, "c": Color(0.3, 0.8, 0.9), "grip": 9, "glow": true},
}
# Draws every weapon (melee + guns) onto any CanvasItem. Used by Stickman and by Arena pickups.


static func draw(ci: CanvasItem, k: String, hand: Vector2, ang: float, L: float, col: Color) -> void:
	var d := Vector2.from_angle(ang)
	var n := Vector2(-d.y, d.x)
	var steel := Color(0.9, 0.92, 0.95)
	var dark := Color(0.14, 0.15, 0.19)
	match k:
		"dagger":
			ci.draw_line(hand - d * 3.0, hand + d * L, steel, 3.0, true)
			ci.draw_line(hand - n * 3.5, hand + n * 3.5, col, 2.8, true)
		"sword":
			ci.draw_line(hand - d * 7.0, hand, col, 3.8, true)
			ci.draw_line(hand - n * 6.0, hand + n * 6.0, col, 3.4, true)
			ci.draw_line(hand, hand + d * L, Color(1, 1, 1, 0.20), 8.0, true)
			ci.draw_line(hand, hand + d * L, steel, 3.4, true)
		"katana":
			var kc := Color(0.82, 0.93, 1.0)
			ci.draw_line(hand - d * 9.0, hand, col, 3.6, true)
			ci.draw_line(hand - n * 4.5, hand + n * 4.5, col, 3.2, true)
			ci.draw_line(hand, hand + d * L, Color(0.7, 0.9, 1.0, 0.22), 8.0, true)
			ci.draw_line(hand, hand + d * L, kc, 2.8, true)
		"spear":
			ci.draw_line(hand - d * 24.0, hand + d * (L - 12.0), col, 3.4, true)
			var tip := hand + d * L
			ci.draw_colored_polygon(PackedVector2Array([hand + d * (L - 16.0) + n * 5.0, tip, hand + d * (L - 16.0) - n * 5.0]), steel)
		"axe":
			ci.draw_line(hand - d * 8.0, hand + d * L, col, 3.6, true)
			var e := hand + d * (L - 6.0)
			ci.draw_colored_polygon(PackedVector2Array([e + n * 2.0 - d * 9.0, e + n * 19.0 + d * 2.0, e + n * 2.0 + d * 11.0]), Color(0.72, 0.74, 0.78))
		"hammer":
			ci.draw_line(hand - d * 8.0, hand + d * L, col, 4.2, true)
			var e2 := hand + d * L
			ci.draw_colored_polygon(PackedVector2Array([e2 + n * 12.0 - d * 8.0, e2 + n * 12.0 + d * 10.0, e2 - n * 12.0 + d * 10.0, e2 - n * 12.0 - d * 8.0]), Color(0.55, 0.56, 0.6))
		_:
			if GUNS.has(k):
				_draw_gun(ci, GUNS[k], hand, ang)


static func _draw_gun(ci: CanvasItem, g: Dictionary, hand: Vector2, ang: float) -> void:
	var d := Vector2.from_angle(ang)
	var n := Vector2(-d.y, d.x)
	var c: Color = g["c"]
	var steel := Color(0.9, 0.92, 0.95)
	var wood := Color(0.55, 0.36, 0.2)
	var b := float(g["b"])
	var t := float(g["t"])
	var back := float(g.get("stock", 8.0))
	if g.has("glow"):
		ci.draw_circle(hand + d * (b * 0.5), 15.0, Color(c.r, c.g, c.b, 0.2))
	if g.has("wood"):
		ci.draw_line(hand - d * back, hand - d * 2.0, wood, t + 1.5, true)
	ci.draw_line(hand - d * minf(back, 8.0), hand + d * b, c, t, true)
	if g.has("double"):
		ci.draw_line(hand - d * 4.0 + n * 3.5, hand + d * b + n * 3.5, c, t * 0.6, true)
	if g.has("grip"):
		ci.draw_line(hand, hand + n * float(g["grip"]) - d * 3.0, c, 5.0, true)
	if g.has("mag"):
		ci.draw_line(hand + d * (b * 0.3), hand + d * (b * 0.25) + n * float(g["mag"]), c, 4.5, true)
	if g.has("scope"):
		ci.draw_line(hand + d * 6.0 - n * (t + 2.0), hand + d * 22.0 - n * (t + 2.0), c, 4.5, true)
	if g.has("pump"):
		ci.draw_line(hand + d * 12.0, hand + d * 22.0, wood, t + 3.0, true)
	if g.has("multi"):
		for i in 3:
			ci.draw_line(hand + d * 4.0 + n * (float(i) - 1.0) * 3.5, hand + d * b + n * (float(i) - 1.0) * 3.5, c.lightened(0.25), 2.5, true)
	if g.has("tank"):
		ci.draw_circle(hand - d * 8.0 + n * 9.0, 8.0, Color(0.9, 0.7, 0.2))
	if g.has("tip"):
		ci.draw_circle(hand + d * b, t * 0.7, Color(0.85, 0.25, 0.2))
	if g.has("snake"):
		ci.draw_circle(hand + d * b, 5.0, Color(0.5, 0.9, 0.4))
	if g.has("cyl"):
		ci.draw_circle(hand + d * 4.0, 5.5, c.lightened(0.2))
	ci.draw_line(hand + d * 4.0 - n * (t * 0.3), hand + d * b - n * (t * 0.3), steel, 1.2, true)
