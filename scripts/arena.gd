extends Node2D
class_name Arena
# Stick Fight style arena (inspired by "Stick Fight: The Game"):
# 100 HP, punches / air kick, block + parry, throw weapons (55 dmg), weapon crates from the sky,
# guns, melee, explosives, snakes, fire, headshots, lava / spikes / moving platforms, ragdoll deaths.
# Offline vs bots or LAN PvP (host authoritative).

signal exit(action: String, data: Dictionary)

const G := 2000.0
const RUN := 300.0
const JUMP_V := -720.0
const HALF_W := 14.0
const BODY_H := 92.0
const THROW_DMG := 55.0
const COLORS := [Color(0.35, 0.75, 1.0), Color(1.0, 0.85, 0.2), Color(1.0, 0.35, 0.25), Color(0.45, 0.9, 0.3)]

# gun fields: dmg rate ammo speed spread pellets kb rk grav len (+ burst bounce expl fuse snake flame laser inf rare life)
# melee fields: dmg cd range kb ammo len lunge (+ blink)
const WP := {
	"fists": {"en": "Fists", "ar": "قبضة", "kind": "fist", "gun": false, "dmg": 22.0, "cd": 0.36, "range": 58.0, "kb": 240.0, "len": 0, "ammo": 0, "lunge": 120.0},
	"sword": {"en": "Sword", "ar": "سيف", "kind": "sword", "gun": false, "dmg": 68.0, "cd": 0.40, "range": 104.0, "kb": 260.0, "len": 46, "ammo": 25, "lunge": 230.0},
	"spear": {"en": "Spear", "ar": "رمح", "kind": "spear", "gun": false, "dmg": 20.0, "cd": 0.55, "range": 134.0, "kb": 650.0, "len": 70, "ammo": 25, "lunge": 200.0},
	"blink": {"en": "Blink Dagger", "ar": "خنجر الانتقال", "kind": "dagger", "gun": false, "dmg": 40.0, "cd": 0.5, "range": 64.0, "kb": 700.0, "len": 22, "ammo": 25, "lunge": 0.0, "blink": 150.0},
	"pistol": {"en": "Pistol", "ar": "مسدس", "kind": "pistol", "gun": true, "dmg": 32.0, "rate": 0.2, "ammo": 15, "speed": 1600.0, "spread": 0.02, "pellets": 1, "kb": 140.0, "rk": 20.0, "grav": 0.0, "len": 10},
	"revolver": {"en": "Revolver", "ar": "ريفولفر", "kind": "revolver", "gun": true, "dmg": 44.0, "rate": 0.28, "ammo": 6, "speed": 1700.0, "spread": 0.05, "pellets": 1, "kb": 160.0, "rk": 130.0, "grav": 0.0, "len": 12},
	"deagle": {"en": "Desert Eagle", "ar": "ديزرت إيغل", "kind": "deagle", "gun": true, "dmg": 56.0, "rate": 0.3, "ammo": 15, "speed": 1800.0, "spread": 0.04, "pellets": 1, "kb": 520.0, "rk": 200.0, "grav": 0.0, "len": 14},
	"uzi": {"en": "Uzi", "ar": "يوزي", "kind": "uzi", "gun": true, "dmg": 14.0, "rate": 0.07, "ammo": 40, "speed": 1500.0, "spread": 0.08, "pellets": 1, "kb": 140.0, "rk": 15.0, "grav": 0.0, "len": 12},
	"godpistol": {"en": "God Pistol", "ar": "مسدس الإله", "kind": "godpistol", "gun": true, "dmg": 45.0, "rate": 0.12, "ammo": 999, "speed": 1900.0, "spread": 0.02, "pellets": 1, "kb": 120.0, "rk": 15.0, "grav": 0.0, "len": 12, "inf": true, "rare": true},
	"ak47": {"en": "AK-47", "ar": "كلاشنكوف", "kind": "ak47", "gun": true, "dmg": 23.0, "rate": 0.1, "ammo": 30, "speed": 1700.0, "spread": 0.04, "pellets": 1, "kb": 120.0, "rk": 25.0, "grav": 0.0, "len": 18},
	"m16": {"en": "M16", "ar": "إم 16", "kind": "m16", "gun": true, "dmg": 20.0, "rate": 0.34, "ammo": 88, "speed": 1800.0, "spread": 0.03, "pellets": 1, "kb": 90.0, "rk": 20.0, "grav": 0.0, "len": 20, "burst": 3},
	"m1": {"en": "M1 Garand", "ar": "إم 1", "kind": "m1", "gun": true, "dmg": 35.0, "rate": 0.4, "ammo": 8, "speed": 1900.0, "spread": 0.02, "pellets": 1, "kb": 300.0, "rk": 70.0, "grav": 0.0, "len": 20},
	"sniper": {"en": "Sniper", "ar": "قناص", "kind": "sniper", "gun": true, "dmg": 75.0, "rate": 1.0, "ammo": 5, "speed": 3200.0, "spread": 0.0, "pellets": 1, "kb": 420.0, "rk": 220.0, "grav": 0.0, "len": 26, "laser": true},
	"sawedoff": {"en": "Sawed-Off", "ar": "شوتجن مقطوع", "kind": "sawedoff", "gun": true, "dmg": 20.0, "rate": 0.85, "ammo": 10, "speed": 1400.0, "spread": 0.28, "pellets": 5, "kb": 130.0, "rk": 520.0, "grav": 0.0, "len": 14},
	"shotgun": {"en": "Military Shotgun", "ar": "شوتجن عسكري", "kind": "shotgun", "gun": true, "dmg": 6.0, "rate": 0.55, "ammo": 10, "speed": 1500.0, "spread": 0.09, "pellets": 5, "kb": 60.0, "rk": 200.0, "grav": 0.0, "len": 18},
	"bouncer": {"en": "Bouncer", "ar": "المرتد", "kind": "bouncer", "gun": true, "dmg": 45.0, "rate": 0.14, "ammo": 30, "speed": 1300.0, "spread": 0.02, "pellets": 1, "kb": 100.0, "rk": 20.0, "grav": 0.0, "len": 14, "bounce": 6},
	"grenade": {"en": "Grenade Launcher", "ar": "قاذف قنابل", "kind": "grenade", "gun": true, "dmg": 65.0, "rate": 0.6, "ammo": 5, "speed": 850.0, "spread": 0.02, "pellets": 1, "kb": 700.0, "rk": 80.0, "grav": 900.0, "len": 14, "expl": 125.0, "fuse": 1.3},
	"rpg": {"en": "RPG", "ar": "آر بي جي", "kind": "rpg", "gun": true, "dmg": 300.0, "rate": 1.5, "ammo": 3, "speed": 700.0, "spread": 0.0, "pellets": 1, "kb": 900.0, "rk": 360.0, "grav": 0.0, "len": 24, "expl": 175.0, "rare": true},
	"snake": {"en": "Snake Gun", "ar": "مسدس الثعابين", "kind": "snake", "gun": true, "dmg": 5.0, "rate": 0.3, "ammo": 6, "speed": 0.0, "spread": 0.0, "pellets": 1, "kb": 40.0, "rk": 100.0, "grav": 0.0, "len": 12, "snake": true},
	"flame": {"en": "Flamethrower", "ar": "قاذف لهب", "kind": "flame", "gun": true, "dmg": 3.0, "rate": 0.045, "ammo": 100, "speed": 650.0, "spread": 0.12, "pellets": 1, "kb": 20.0, "rk": 10.0, "grav": -60.0, "len": 16, "flame": true, "life": 0.38},
	"minigun": {"en": "Minigun", "ar": "ميني جن", "kind": "minigun", "gun": true, "dmg": 5.0, "rate": 0.035, "ammo": 200, "speed": 1500.0, "spread": 0.1, "pellets": 1, "kb": 40.0, "rk": 50.0, "grav": 0.0, "len": 20},
	"laser": {"en": "Laser", "ar": "ليزر", "kind": "laser", "gun": true, "dmg": 10.0, "rate": 0.09, "ammo": 60, "speed": 2400.0, "spread": 0.01, "pellets": 1, "kb": 650.0, "rk": 20.0, "grav": 0.0, "len": 14},
}
const DROPS := ["sword", "spear", "blink", "pistol", "revolver", "deagle", "uzi", "ak47", "m16", "m1", "sniper", "sawedoff", "shotgun", "bouncer", "grenade", "snake", "flame", "minigun", "laser"]
const RARE := ["godpistol", "rpg"]

# platforms [x, y, w, h], spawns [x, y], hazards [x, y, w, h, kind], movers [platform index, ax, ay, speed]; all fractions
const MAPS := [
	{"p": [[0.0, 0.84, 1.0, 0.16], [0.17, 0.64, 0.2, 0.035], [0.63, 0.64, 0.2, 0.035], [0.4, 0.44, 0.2, 0.035]],
	 "s": [[0.1, 0.84], [0.9, 0.84], [0.27, 0.64], [0.73, 0.64]], "h": [], "m": []},
	{"p": [[0.0, 0.8, 0.37, 0.2], [0.63, 0.8, 0.37, 0.2], [0.4, 0.62, 0.2, 0.035], [0.12, 0.45, 0.16, 0.035], [0.72, 0.45, 0.16, 0.035]],
	 "s": [[0.1, 0.8], [0.9, 0.8], [0.2, 0.45], [0.8, 0.45]], "h": [], "m": []},
	{"p": [[0.0, 0.84, 1.0, 0.16], [0.0, 0.56, 0.14, 0.28], [0.86, 0.56, 0.14, 0.28], [0.34, 0.62, 0.32, 0.035], [0.43, 0.4, 0.14, 0.035]],
	 "s": [[0.25, 0.84], [0.75, 0.84], [0.07, 0.56], [0.93, 0.56]], "h": [], "m": []},
	{"p": [[0.0, 0.8, 0.26, 0.2], [0.74, 0.8, 0.26, 0.2], [0.36, 0.66, 0.28, 0.035], [0.06, 0.46, 0.2, 0.035], [0.74, 0.46, 0.2, 0.035]],
	 "s": [[0.1, 0.8], [0.9, 0.8], [0.14, 0.46], [0.86, 0.46]], "h": [[0.26, 0.93, 0.48, 0.07, "lava"]], "m": []},
	{"p": [[0.0, 0.84, 1.0, 0.16], [0.2, 0.62, 0.2, 0.035], [0.6, 0.62, 0.2, 0.035], [0.4, 0.42, 0.2, 0.035]],
	 "s": [[0.08, 0.84], [0.92, 0.84], [0.3, 0.62], [0.7, 0.62]], "h": [[0.44, 0.8, 0.12, 0.04, "spikes"], [0.2, 0.8, 0.08, 0.04, "spikes"], [0.72, 0.8, 0.08, 0.04, "spikes"]], "m": []},
	{"p": [[0.0, 0.84, 0.3, 0.16], [0.7, 0.84, 0.3, 0.16], [0.38, 0.68, 0.24, 0.035], [0.4, 0.38, 0.2, 0.035]],
	 "s": [[0.1, 0.84], [0.9, 0.84], [0.5, 0.38], [0.5, 0.68]], "h": [], "m": [[2, 0.2, 0.0, 1.1], [3, 0.0, 0.1, 0.8]]},
]


class Fighter:
	var id := 0
	var idx := 0
	var node: Stickman
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var face := 1
	var on_ground := false
	var hp := 100.0
	var wid := "fists"
	var ammo := 0
	var alive := true
	var bot := false
	var wins := 0
	var pname := ""
	var fire_cd := 0.0
	var atk_cd := 0.0
	var coyote := 0.0
	var jump_cut := false
	var hit_pending := false
	var swing := 0
	var stun := 0.0
	var empty_t := 0.0
	var in_axis := 0.0
	var in_attack := false
	var in_jump_held := false
	var in_block := false
	var jump_t := -1000
	var throw_t := -1000
	var jump_sent := -1000
	var throw_sent := -1000
	var ai_t := 0.0
	var want_face := 1
	var tx := 0.0
	var ty := 0.0
	var blocking := false
	var block_age := 0.0
	var block_en := 1.5
	var burn_t := 0.0
	var damaged := false
	var burn_acc := 0.0
	var burst_left := 0
	var burst_t := 0.0
	var stand_idx := -1
	var kicking := false
	var block_hold := 0.0
	var aim := 0.0
	var aim_on := false
	var crouch := false
	var in_crouch := false


var map_start := 0
var win_target := 3
var W := 1280.0
var H := 600.0
var net := false
var is_server := true
var my_id := 1
var bots_n := 3

var fighters := {}
var order: Array = []
var rects: Array = []
var spawns: Array = []
var hazards: Array = []
var movers: Array = []
var projectiles: Array = []
var items: Array = []
var snakes: Array = []
var ragdolls: Array = []
var splats: Array = []
var proj_view: Array = []
var item_view: Array = []
var snake_view: Array = []
var round_n := 0
var map_idx := 0
var state := "ready"
var state_t := 0.0
var crate_t := 2.0
var net_t := 0.0
var in_t := 0.0
var shake := 0.0
var ended := false
var move_t := 0.0
var cam_zoom := 1.0
var cam_pos := Vector2(640, 300)
var bg_t := 0.0
var bg_seed: Array = []

var fx: Effects
var overlay: Node2D
var cam: Camera2D
var controls: TouchControls
var hud: CanvasLayer
var hud_root: Control
var hudc: Control
var banner: Label
var banner_sub: Label
var banner_tween: Tween
var pause_menu: Control


func _ready() -> void:
	var sz := get_viewport_rect().size
	W = sz.x
	H = sz.y
	net = Net.active
	is_server = (not net) or Net.is_host
	my_id = multiplayer.get_unique_id() if net else 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 9:
		bg_seed.append(Vector2(rng.randf(), rng.randf()))
	overlay = Node2D.new()
	overlay.z_index = 5
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	fx = Effects.new()
	fx.z_index = 10
	add_child(fx)
	cam = Camera2D.new()
	cam.position = Vector2(W * 0.5, H * 0.5)
	cam_pos = cam.position
	add_child(cam)
	cam.make_current()
	_build_hud()
	_make_fighters()
	if is_server:
		_start_round()
	if net:
		Net.players_changed.connect(_on_players_changed)
		Net.disconnected.connect(_on_net_lost)


# ------------------------------------------------------------------ setup
func _make_fighters() -> void:
	var ids: Array = []
	if net:
		ids = Net.players.keys()
		ids.sort()
	else:
		ids = [1]
		for b in bots_n:
			ids.append(2 + b)
	for i in ids.size():
		var id: int = ids[i]
		var f := Fighter.new()
		f.id = id
		f.idx = i
		var info: Dictionary = Net.players[id] if net else {}
		f.bot = ((not net) and id != 1) or (id == my_id and Game.autoplay) or (is_server and bool(info.get("bot", false)))
		var st := Stickman.new()
		st.thin = true
		st.col = COLORS[i]
		st.z_index = 2
		st.max_hp = 100.0
		add_child(st)
		f.node = st
		if net:
			f.pname = str(Net.players[id]["name"])
		elif id == 1:
			f.pname = Game.pname
		else:
			f.pname = "Bot %d" % (id - 1)
		st.tag = f.pname if id != my_id else ""
		fighters[id] = f
		order.append(id)
		_equip(f)


func _equip(f: Fighter) -> void:
	var w: Dictionary = WP[f.wid]
	f.node.weapon = w
	f.node.gun_mode = bool(w["gun"])


func _load_map(idx: int) -> void:
	rects.clear()
	spawns.clear()
	hazards.clear()
	movers.clear()
	var m: Dictionary = MAPS[idx % MAPS.size()]
	for p in m["p"]:
		rects.append(Rect2(float(p[0]) * W, float(p[1]) * H, float(p[2]) * W, float(p[3]) * H))
	for s in m["s"]:
		spawns.append(Vector2(float(s[0]) * W, float(s[1]) * H))
	for h in m["h"]:
		hazards.append({"r": Rect2(float(h[0]) * W, float(h[1]) * H, float(h[2]) * W, float(h[3]) * H), "k": str(h[4])})
	for mv in m["m"]:
		var i := int(mv[0])
		movers.append({"i": i, "base": rects[i], "ax": float(mv[1]) * W, "ay": float(mv[2]) * H, "sp": float(mv[3]), "delta": Vector2.ZERO})
	move_t = 0.0
	queue_redraw()


func _update_movers(dt: float) -> void:
	move_t += dt
	for m in movers:
		var base: Rect2 = m["base"]
		var sp: float = m["sp"]
		var off := Vector2(sin(move_t * sp) * float(m["ax"]), sin(move_t * sp) * float(m["ay"]))
		var old: Rect2 = rects[int(m["i"])]
		var nr := Rect2(base.position + off, base.size)
		m["delta"] = nr.position - old.position
		rects[int(m["i"])] = nr


func _wins_dict() -> Dictionary:
	var d := {}
	for id in order:
		d[id] = (fighters[id] as Fighter).wins
	return d


func _clear_round_objects() -> void:
	projectiles.clear()
	items.clear()
	snakes.clear()
	for r in ragdolls:
		if is_instance_valid(r):
			r.queue_free()
	ragdolls.clear()
	splats.clear()


func _start_round() -> void:
	round_n += 1
	if map_start < 0:
		map_idx = randi() % MAPS.size()
	else:
		map_idx = (map_start + round_n - 1) % MAPS.size()
	_load_map(map_idx)
	_clear_round_objects()
	var i := 0
	for id in order:
		var f: Fighter = fighters[id]
		f.pos = spawns[i % spawns.size()]
		f.vel = Vector2.ZERO
		f.alive = true
		f.hp = 100.0
		f.wid = "fists"
		f.ammo = 0
		f.stun = 0.0
		f.burn_t = 0.0
		f.damaged = false
		f.block_en = 1.5
		f.blocking = false
		f.burst_left = 0
		f.hit_pending = false
		f.face = 1 if f.pos.x < W * 0.5 else -1
		f.node.visible = true
		f.node.atk_t = -1.0
		_equip(f)
		i += 1
	state = "ready"
	state_t = 2.2
	crate_t = 1.2
	_banner("%s %d" % [Game.t("round"), round_n], "", 1.5)
	if net:
		rpc("_ev_round", round_n, map_idx, _wins_dict())
		rpc("_ev_banner", "%s %d" % [Game.t("round"), round_n], "", 1.5)


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	hud_root = Control.new()
	hud_root.theme = Game.ui_theme
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)
	hudc = Control.new()
	hudc.set_anchors_preset(Control.PRESET_FULL_RECT)
	hudc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hudc.draw.connect(_draw_hud)
	hud_root.add_child(hudc)
	controls = TouchControls.new()
	controls.grab_mode = true
	controls.stick_mode = true
	hud_root.add_child(controls)
	banner = UIKit.label("", 64)
	banner.position = Vector2(0, H * 0.2)
	banner.size = Vector2(W, 90)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	hud_root.add_child(banner)
	banner_sub = UIKit.label("", 38)
	banner_sub.position = Vector2(0, H * 0.2 + 88)
	banner_sub.size = Vector2(W, 60)
	banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_sub.modulate.a = 0.0
	hud_root.add_child(banner_sub)
	var pb := UIKit.button("II", Vector2(64, 56), false, 28)
	pb.position = Vector2(W - 84, 18)
	pb.pressed.connect(_toggle_pause)
	hud_root.add_child(pb)


func _wname(id: String) -> String:
	return str((WP[id] as Dictionary)["ar" if Game.lang == "ar" else "en"])


func _draw_hud() -> void:
	var f: Font = Game.font
	var n := order.size()
	for i in n:
		var fi: Fighter = fighters[order[i]]
		var x := W * 0.5 + (float(i) - float(n - 1) * 0.5) * 170.0
		var c: Color = COLORS[fi.idx]
		hudc.draw_circle(Vector2(x - 56, 38), 14, c)
		hudc.draw_string(f, Vector2(x - 36, 32), fi.pname, HORIZONTAL_ALIGNMENT_LEFT, 110, 17, Color(1, 1, 1, 0.9))
		for k in win_target:
			hudc.draw_circle(Vector2(x - 34 + float(k) * 18.0, 52), 6, c if k < fi.wins else Color(1, 1, 1, 0.2))
	var me: Fighter = fighters.get(my_id)
	if me != null:
		if me.wid != "fists":
			var w: Dictionary = WP[me.wid]
			var tx := _wname(me.wid)
			if bool(w["gun"]) or int(w["ammo"]) > 0:
				tx = "%s  %s" % [tx, "∞" if w.has("inf") else str(me.ammo)]
			hudc.draw_string(f, Vector2(0, H - 24), tx, HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(1, 1, 1, 0.9))
		hudc.draw_rect(Rect2(W - 330 - 30, H - 90 + 50, 60, 6), Color(0, 0, 0, 0.5))
		hudc.draw_rect(Rect2(W - 330 - 30, H - 90 + 50, 60.0 * clampf(me.block_en / 1.5, 0.0, 1.0), 6), Color(1, 1, 1, 0.85))


func _set_banner_alpha(v: float) -> void:
	banner.modulate.a = v
	banner_sub.modulate.a = v


func _banner(title: String, sub := "", hold := 1.4) -> void:
	banner.text = title
	banner_sub.text = sub
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_method(_set_banner_alpha, 0.0, 1.0, 0.2)
	banner_tween.tween_interval(hold)
	banner_tween.tween_method(_set_banner_alpha, 1.0, 0.0, 0.35)


func _banner_all(title: String, sub := "", hold := 1.4) -> void:
	_banner(title, sub, hold)
	if net and is_server:
		rpc("_ev_banner", title, sub, hold)


# ------------------------------------------------------------------ drawing
func _cap(r: Rect2, c: Color) -> void:
	var th := 14.0 if r.size.y > 24.0 else 10.0
	var pts := PackedVector2Array()
	var x := r.position.x
	while x < r.end.x:
		pts.append(Vector2(x, r.position.y - 3.0 + sin(x * 0.11) * 2.5 + sin(x * 0.31) * 1.5))
		x += 10.0
	pts.append(Vector2(r.end.x, r.position.y - 3.0))
	pts.append(Vector2(r.end.x, r.position.y + th))
	var xb := r.end.x
	while xb > r.position.x:
		pts.append(Vector2(xb, r.position.y + th + 2.0 + sin(xb * 0.17) * 3.0))
		xb -= 14.0
	pts.append(Vector2(r.position.x, r.position.y + th))
	draw_colored_polygon(pts, c)


func _draw() -> void:
	var style := map_idx % 3
	var snow := style == 1
	var gold := style == 2
	var top := Color(0.16, 0.15, 0.12)
	var bot := Color(0.25, 0.23, 0.18)
	var body := Color(0.09, 0.09, 0.11)
	var capc := Color(0.78, 0.06, 0.22)
	if gold:
		top = Color(0.04, 0.08, 0.5)
		bot = Color(0.07, 0.14, 0.6)
		body = Color(0.05, 0.06, 0.2)
		capc = Color(0.96, 0.76, 0.25)
	elif snow:
		top = Color(0.03, 0.1, 0.16)
		bot = Color(0.05, 0.2, 0.26)
		body = Color(0.1, 0.4, 0.42)
		capc = Color(0.96, 0.98, 1.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]), PackedColorArray([top, top, bot, bot]))
	if gold:
		for i in 7:
			draw_circle(Vector2(W * 0.5, H * 0.45), 330.0 - float(i) * 40.0, Color(1.0, 0.65, 0.3, 0.05))
		for i in 5:
			var lx := W * (0.12 + 0.19 * float(i))
			draw_circle(Vector2(lx, H * 0.86), 5.0, Color(0.85, 0.95, 1.0, 0.9))
			draw_circle(Vector2(lx, H * 0.86), 16.0, Color(0.7, 0.9, 1.0, 0.18))
	elif not snow:
		for i in 7:
			var s: Vector2 = bg_seed[i]
			draw_circle(Vector2(s.x * W, s.y * H * 0.75), 90.0 + s.y * 90.0, Color(1, 1, 1, 0.035))
	else:
		for i in 48:
			var hx := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
			var hy := fposmod(sin(float(i) * 78.233) * 12345.6789, 1.0)
			var px := fposmod(hx * W + sin(bg_t * 0.8 + float(i)) * 18.0, W)
			var py := fposmod(hy * H + bg_t * (22.0 + float(i % 5) * 8.0), H)
			draw_circle(Vector2(px, py), 1.2 + float(i % 3) * 0.6, Color(1, 1, 1, 0.55))
	for hz in hazards:
		var r: Rect2 = hz["r"]
		if str(hz["k"]) == "lava":
			draw_rect(r, Color(0.95, 0.35, 0.08))
			draw_rect(Rect2(r.position.x, r.position.y + 10, r.size.x, r.size.y - 10), Color(0.8, 0.2, 0.05))
			var pts := PackedVector2Array()
			var x := r.position.x
			while x <= r.end.x:
				pts.append(Vector2(x, r.position.y + sin(bg_t * 3.0 + x * 0.05) * 4.0))
				x += 14.0
			draw_polyline(pts, Color(1.0, 0.8, 0.3), 4.0, true)
		else:
			var x2 := r.position.x
			while x2 < r.end.x - 4.0:
				draw_colored_polygon(PackedVector2Array([Vector2(x2, r.end.y), Vector2(x2 + 7.0, r.position.y), Vector2(x2 + 14.0, r.end.y)]), Color(0.78, 0.79, 0.85))
				x2 += 14.0
	for ri in rects.size():
		var rr: Rect2 = rects[ri]
		draw_rect(rr, body)
		draw_rect(Rect2(rr.position.x, rr.end.y - minf(rr.size.y * 0.25, 18.0), rr.size.x, minf(rr.size.y * 0.25, 18.0)), body.darkened(0.25))
		_cap(rr, capc)
	for s in splats:
		var sp: Vector3 = s
		draw_set_transform(Vector2(sp.x, sp.y), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, sp.z, Color(0.62, 0.1, 0.16, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ray_end(from: Vector2, dir: float) -> Vector2:
	var p := from
	for i in 120:
		p.x += dir * 14.0
		if p.x < 0.0 or p.x > W:
			break
		var hit := false
		for r in rects:
			if (r as Rect2).has_point(p):
				hit = true
		if hit:
			break
	return p


func _draw_overlay() -> void:
	var me0: Fighter = fighters.get(my_id)
	if me0 != null and me0.alive and me0.aim_on and not me0.bot:
		var ad := Vector2.from_angle(me0.aim)
		var o := me0.pos + Vector2(0, -64.0) + ad * 40.0
		for i in 8:
			overlay.draw_circle(o + ad * float(i) * 22.0, 2.0, Color(1, 1, 1, 0.45 - float(i) * 0.04))
		overlay.draw_arc(o + ad * 190.0, 9.0, 0.0, TAU, 14, Color(1, 1, 1, 0.55), 2.0, true)
	for f in fighters.values():
		var fi: Fighter = f
		if fi.alive and fi.wid == "sniper":
			var m := fi.pos + Vector2(float(fi.face) * 40.0, -64.0)
			overlay.draw_line(m, _ray_end(m, float(fi.face)), Color(1, 0.15, 0.1, 0.55), 1.5, true)
	for it in item_view:
		var p: Vector2 = it[0]
		if bool(it[2]):
			overlay.draw_rect(Rect2(p.x - 14, p.y - 14, 28, 28), Color(0.95, 0.95, 1.0, 0.95), true)
			overlay.draw_rect(Rect2(p.x - 14, p.y - 14, 28, 28), Color(0.3, 0.3, 0.45), false, 2.0)
			overlay.draw_line(p + Vector2(-14, 0), p + Vector2(14, 0), Color(0.3, 0.3, 0.45), 2.0)
		else:
			var w: Dictionary = WP[str(it[1])]
			var landed: bool = bool(it[3])
			var ang: float = bg_t * 2.2 if landed else float(it[4])
			var cp := p + Vector2(0, -24.0 + (sin(bg_t * 3.0 + p.x) * 4.0 if landed else 0.0))
			var wl := float(w["len"]) * 1.1 + 20.0
			overlay.draw_circle(cp, 26.0 + sin(bg_t * 4.0) * 2.0, Color(1, 1, 1, 0.10))
			if landed:
				overlay.draw_arc(cp, 29.0, 0.0, TAU, 24, Color(1, 1, 1, 0.28), 2.0, true)
			var hand := cp - Vector2.from_angle(ang) * wl * 0.5
			WeaponArt.draw(overlay, str(w["kind"]), hand, ang, float(w["len"]) * 1.1, Color(0.85, 0.85, 0.9))
	for sn in snake_view:
		var sp: Vector2 = sn[0]
		var ph: float = float(sn[2])
		var pts := PackedVector2Array()
		for k in 7:
			pts.append(sp + Vector2(-float(sn[1]) * float(k) * 6.0, sin(ph + float(k) * 0.9) * 3.0 - 4.0))
		overlay.draw_polyline(pts, Color(0.35, 0.85, 0.3), 4.0, true)
		overlay.draw_circle(pts[0], 4.0, Color(0.5, 0.95, 0.4))
	for b in proj_view:
		var p: Vector2 = b[0]
		var v: Vector2 = b[1]
		var kind := str(b[2])
		var c: Color = COLORS[int(b[3])]
		var dv := v.normalized()
		match kind:
			"flame":
				overlay.draw_circle(p, 9.0, Color(1.0, 0.55, 0.1, 0.55))
				overlay.draw_circle(p, 5.0, Color(1.0, 0.9, 0.3, 0.85))
			"grenade":
				overlay.draw_circle(p, 7.0, Color(0.25, 0.35, 0.25))
				overlay.draw_circle(p, 3.0, Color(1, 0.3, 0.2, 0.5 + 0.5 * sin(bg_t * 25.0)))
			"rpg":
				overlay.draw_line(p - dv * 24.0, p, Color(0.5, 0.52, 0.45), 6.0, true)
				overlay.draw_line(p - dv * 40.0, p - dv * 24.0, Color(1, 0.6, 0.2, 0.9), 5.0, true)
			"laser":
				overlay.draw_line(p - dv * 34.0, p, Color(0.3, 0.9, 1.0), 4.0, true)
				overlay.draw_line(p - dv * 20.0, p, Color(1, 1, 1), 1.6, true)
			"bouncer":
				overlay.draw_circle(p, 6.0, Color(0.75, 0.35, 1.0))
			_:
				overlay.draw_line(p - dv * 26.0, p, c, 3.0, true)
				overlay.draw_line(p - dv * 12.0, p, Color(1, 1, 1, 0.95), 1.6, true)


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	bg_t += dt
	if is_server:
		match state:
			"ready":
				state_t -= dt
				if state_t <= 0.0:
					state = "fight"
					_banner_all(Game.t("fight"), "", 0.6)
			"fight":
				_check_round_end()
				crate_t -= dt
				if crate_t <= 0.0:
					_spawn_crate()
					crate_t = randf_range(3.0, 5.0)
			"over":
				state_t -= dt
				if state_t <= 0.0:
					_after_round()
		_update_movers(dt)
		for f in fighters.values():
			_step_fighter(f, dt)
		_update_projectiles(dt)
		_update_snakes(dt)
		_update_items(dt)
		_refresh_views()
		if net:
			net_t -= dt
			if net_t <= 0.0:
				net_t = 0.05
				_send_snapshot()
	else:
		_client_process(dt)
	_sync_nodes()
	_update_camera(dt)
	overlay.queue_redraw()
	hudc.queue_redraw()
	if not movers.is_empty() or not hazards.is_empty():
		queue_redraw()


func _update_camera(dt: float) -> void:
	var minp := Vector2(1.0e9, 1.0e9)
	var maxp := Vector2(-1.0e9, -1.0e9)
	var n := 0
	for f in fighters.values():
		var fi: Fighter = f
		if fi.alive:
			minp.x = minf(minp.x, fi.pos.x)
			maxp.x = maxf(maxp.x, fi.pos.x)
			minp.y = minf(minp.y, fi.pos.y - 100.0)
			maxp.y = maxf(maxp.y, fi.pos.y)
			n += 1
	var tz := 1.0
	var tc := Vector2(W * 0.5, H * 0.5)
	if n > 0:
		var need_x := (maxp.x - minp.x) + 380.0
		var need_y := (maxp.y - minp.y) + 280.0
		tz = clampf(minf(W / need_x, H / need_y), 1.0, 1.45)
		tc = (minp + maxp) * 0.5
	cam_zoom = lerpf(cam_zoom, tz, 1.0 - exp(-4.0 * dt))
	cam_pos = cam_pos.lerp(tc, 1.0 - exp(-5.0 * dt))
	var z := maxf(cam_zoom, 1.0)
	var hw := W * 0.5 / z
	var hh := H * 0.5 / z
	cam.zoom = Vector2(z, z)
	cam.position = Vector2(clampf(cam_pos.x, hw, W - hw), clampf(cam_pos.y, hh, H - hh))
	shake = maxf(0.0, shake - 40.0 * dt)
	cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))


func _sync_nodes() -> void:
	for f in fighters.values():
		var fi: Fighter = f
		fi.node.position = fi.pos
		fi.node.vx = fi.vel.x
		fi.node.vy = fi.vel.y
		fi.node.on_ground = fi.on_ground
		fi.node.facing = fi.face
		fi.node.hp = fi.hp
		fi.node.show_bar = 99.0 if fi.alive else 0.0
		fi.node.visible = fi.alive
		fi.node.block_mode = fi.blocking
		fi.node.crouch_mode = fi.crouch
		fi.node.aim_angle = _aim_angle(fi)
		fi.node.aim_on = fi.aim_on and fi.alive


func _refresh_views() -> void:
	proj_view = []
	for b in projectiles:
		proj_view.append([b["p"], b["v"], b["k"], b["c"]])
	item_view = []
	for it in items:
		item_view.append([it["p"], it["wid"], it["box"], it["landed"], it["rot"]])
	snake_view = []
	for sn in snakes:
		snake_view.append([sn["p"], sn["dir"], sn["ph"]])


# ------------------------------------------------------------------ input
func _now() -> int:
	return Time.get_ticks_msec()


func _bh(f: Fighter) -> float:
	return BODY_H * 0.62 if f.crouch else BODY_H


func _aim_angle(f: Fighter) -> float:
	if f.aim_on:
		return f.aim
	return 0.0 if f.face > 0 else PI


func _read_local(f: Fighter) -> void:
	f.in_axis = controls.axis()
	f.in_attack = controls.is_held("attack")
	f.in_jump_held = controls.is_held("jump")
	f.in_block = controls.is_held("block")
	f.in_crouch = controls.crouch()
	var av := controls.aim_vec()
	f.aim_on = av != Vector2.ZERO
	if f.aim_on:
		f.aim = av.angle()
	if controls.consume("jump"):
		f.jump_t = _now()
	if controls.consume("dash"):
		f.throw_t = _now()


@rpc("any_peer", "unreliable")
func _sv_input(axis: float, atk: bool, jh: bool, blk: bool, aim: float, aim_on: bool, crouch: bool) -> void:
	if not is_server:
		return
	var f: Fighter = fighters.get(multiplayer.get_remote_sender_id())
	if f != null:
		f.in_axis = axis
		f.in_attack = atk
		f.in_jump_held = jh
		f.in_block = blk
		f.aim = aim
		f.aim_on = aim_on
		f.in_crouch = crouch


@rpc("any_peer", "reliable")
func _sv_press(n: String) -> void:
	if not is_server:
		return
	var f: Fighter = fighters.get(multiplayer.get_remote_sender_id())
	if f == null:
		return
	if n == "jump":
		f.jump_t = _now()
	elif n == "dash":
		f.throw_t = _now()


# ------------------------------------------------------------------ simulation (host / offline)
func _step_fighter(f: Fighter, dt: float) -> void:
	if not f.alive:
		return
	if f.bot:
		_bot_think(f, dt)
	elif f.id == my_id:
		_read_local(f)
	var w: Dictionary = WP[f.wid]
	f.fire_cd -= dt
	f.atk_cd -= dt
	f.stun -= dt
	# block / parry window
	var can_block := f.in_block and f.block_en > 0.0 and f.stun <= 0.0 and not f.node.is_attacking() and state != "ready"
	if can_block:
		f.blocking = true
		f.block_age += dt
		f.block_en = maxf(0.0, f.block_en - dt * 0.55)
	else:
		f.blocking = false
		f.block_age = 0.0
		f.block_en = minf(1.5, f.block_en + dt * 0.7)
	# burn
	if f.burn_t > 0.0:
		f.burn_t -= dt
		f.burn_acc += dt
		if f.burn_acc >= 0.5:
			f.burn_acc -= 0.5
			fx.drops(f.pos + Vector2(0, -50), Color(1.0, 0.55, 0.1), 3)
			_damage_raw(f, 2.5)
			if not f.alive:
				return
	f.crouch = f.in_crouch and f.on_ground and f.stun <= 0.0 and not f.bot
	var axis := f.in_axis if (f.stun <= 0.0 and not f.blocking) else 0.0
	var target := axis * RUN * (0.55 if f.blocking else 1.0) * (0.45 if f.crouch else 1.0)
	var acc := 3200.0 if f.on_ground else 1900.0
	if axis == 0.0:
		acc = 2600.0 if f.on_ground else 500.0
	f.vel.x = move_toward(f.vel.x, target, acc * dt)
	if f.stun <= 0.0:
		if f.aim_on and absf(cos(f.aim)) > 0.15:
			f.face = 1 if cos(f.aim) > 0.0 else -1
		elif axis != 0.0:
			f.face = 1 if axis > 0.0 else -1
		elif f.bot:
			f.face = f.want_face
	# jump
	f.coyote = 0.08 if f.on_ground else f.coyote - dt
	if _now() - f.jump_t < 150 and f.coyote > 0.0 and f.stun <= 0.0:
		f.jump_t = -1000
		f.vel.y = JUMP_V
		f.on_ground = false
		f.coyote = 0.0
		f.jump_cut = false
		f.stand_idx = -1
		fx.dust(f.pos, 4)
		Game.sfx("swing", 1.5)
		if absf(f.in_axis) > 0.5 and not (f.node.gun_mode and f.aim_on):
			f.node.spin_v = signf(f.in_axis) * 8.7
	if f.vel.y < -250.0 and not f.in_jump_held and not f.jump_cut:
		f.vel.y *= 0.5
		f.jump_cut = true
	f.vel.y = minf(f.vel.y + G * dt, 1500.0)
	# ride moving platforms
	if f.on_ground and f.stand_idx >= 0:
		for m in movers:
			if int(m["i"]) == f.stand_idx:
				f.pos += (m["delta"] as Vector2)
	_move(f, dt)
	if f.pos.y > H + 140.0:
		_kill(f, f.face)
		return
	for hz in hazards:
		if Rect2(f.pos.x - HALF_W, f.pos.y - BODY_H, HALF_W * 2.0, BODY_H).intersects(hz["r"]):
			_kill(f, f.face)
			return
	# throw weapon
	if _now() - f.throw_t < 150:
		f.throw_t = -1000
		_throw_weapon(f, 0.7)
	# auto pickup (walk over a weapon while empty-handed)
	if f.wid == "fists" and f.stun <= 0.0:
		_try_pickup(f)
	# attack
	if state == "fight" and f.in_attack and f.stun <= 0.0 and not f.blocking:
		if bool(w["gun"]):
			_try_fire(f, w)
		elif f.atk_cd <= 0.0:
			_start_melee(f, w)
	if f.burst_left > 0:
		f.burst_t -= dt
		if f.burst_t <= 0.0 and f.ammo > 0:
			f.burst_left -= 1
			f.burst_t = 0.06
			_fire_one(f, w)
		elif f.ammo <= 0:
			f.burst_left = 0
	if f.hit_pending:
		var ap := f.node.attack_progress()
		if ap < 0.0:
			f.hit_pending = false
		elif ap >= float(f.node.cur_atk["hit"]):
			f.hit_pending = false
			_melee_hit(f)
	if f.empty_t > 0.0:
		f.empty_t -= dt
		if f.empty_t <= 0.0 and f.ammo <= 0 and f.wid != "fists":
			_throw_weapon(f, 0.0)


func _move(f: Fighter, dt: float) -> void:
	var was_air := not f.on_ground
	var bh := _bh(f)
	f.pos.x += f.vel.x * dt
	f.pos.x = clampf(f.pos.x, HALF_W, W - HALF_W)
	for r in rects:
		var rr: Rect2 = r
		if Rect2(f.pos.x - HALF_W, f.pos.y - bh, HALF_W * 2.0, bh).intersects(rr):
			if f.vel.x > 0.0:
				f.pos.x = rr.position.x - HALF_W
			else:
				f.pos.x = rr.end.x + HALF_W
			f.vel.x = 0.0
	f.on_ground = false
	f.stand_idx = -1
	f.pos.y += f.vel.y * dt
	for ri in rects.size():
		var rr: Rect2 = rects[ri]
		if Rect2(f.pos.x - HALF_W, f.pos.y - bh, HALF_W * 2.0, bh).intersects(rr):
			if f.vel.y > 0.0:
				f.pos.y = rr.position.y
				f.on_ground = true
				f.stand_idx = ri
				if was_air and f.vel.y > 900.0:
					f.stun = maxf(f.stun, 0.22)
				if was_air and f.vel.y > 400.0:
					f.node.land_t = 0.12
					fx.dust(f.pos, 5)
			else:
				f.pos.y = rr.end.y + bh
			f.vel.y = 0.0


func _start_melee(f: Fighter, w: Dictionary) -> void:
	var k := str(w["kind"])
	var typ := "thrust"
	if not f.on_ground and f.wid == "fists":
		typ = "kick"
		f.kicking = true
	f.node.play_attack(typ, float(w["cd"]) * 1.1)
	f.atk_cd = float(w["cd"]) * 1.1
	f.hit_pending = true
	f.vel.x += float(f.face) * (260.0 if f.kicking else float(w.get("lunge", 120.0)))
	if w.has("blink"):
		_blink(f, float(w["blink"]))
	if f.wid != "fists":
		f.ammo -= 1
		if f.ammo <= 0:
			f.empty_t = 0.5
	Game.sfx("swing", randf_range(0.9, 1.1))


func _blink(f: Fighter, dist: float) -> void:
	var dest := f.pos + Vector2(float(f.face) * dist, 0.0)
	dest.x = clampf(dest.x, HALF_W, W - HALF_W)
	for r in rects:
		if Rect2(dest.x - HALF_W, dest.y - BODY_H, HALF_W * 2.0, BODY_H).intersects(r):
			dest.x = f.pos.x
	fx.flash(f.pos + Vector2(0, -50), 34.0, 0.2)
	f.pos = dest
	fx.flash(f.pos + Vector2(0, -50), 34.0, 0.2)


func _melee_hit(f: Fighter) -> void:
	var w: Dictionary = WP[f.wid]
	var dmg := float(w["dmg"])
	var kb := float(w["kb"])
	var rng := float(w["range"])
	if f.kicking:
		dmg = 15.0
		kb = 520.0
		rng = 70.0
		f.kicking = false
	var dirv := Vector2.from_angle(_aim_angle(f))
	var origin := f.pos + Vector2(0, -50)
	for o in fighters.values():
		var t: Fighter = o
		if t == f or not t.alive:
			continue
		var to := (t.pos + Vector2(0, -45)) - origin
		var dist := to.length()
		if dist < rng + 20.0 and (dist < 32.0 or absf(to.angle_to(dirv)) < 1.0):
			_hurt(t, dmg, 1 if to.x >= 0.0 else -1, kb, f)


func _try_fire(f: Fighter, w: Dictionary) -> void:
	if f.fire_cd > 0.0 or f.ammo <= 0 or f.burst_left > 0:
		return
	f.fire_cd = float(w["rate"])
	_fire_one(f, w)
	if int(w.get("burst", 1)) > 1:
		f.burst_left = int(w["burst"]) - 1
		f.burst_t = 0.06


func _fire_one(f: Fighter, w: Dictionary) -> void:
	if not w.has("inf"):
		f.ammo -= 1
	var adir := Vector2.from_angle(_aim_angle(f))
	var muzzle := f.pos + Vector2(0, -40.0 if f.crouch else -64.0) + adir * (32.0 + float(w["len"]))
	if w.has("snake"):
		snakes.append({"p": Vector2(f.pos.x + float(f.face) * 30.0, f.pos.y - 6.0), "v": Vector2(float(f.face) * 160.0, -120.0), "dir": f.face, "life": 7.0, "o": f.id, "c": f.idx, "bite": 0.0, "ph": 0.0})
	else:
		for i in int(w["pellets"]):
			var a := _aim_angle(f) + randf_range(-1.0, 1.0) * float(w["spread"])
			var d := float(w["dmg"])
			if int(w["pellets"]) >= 5 and f.wid == "sawedoff":
				d = randf_range(10.0, 30.0)
			projectiles.append({"p": muzzle, "v": Vector2.from_angle(a) * float(w["speed"]), "o": f.id, "dmg": d, "kb": float(w["kb"]), "g": float(w["grav"]), "k": str(w["kind"]), "c": f.idx, "age": 0.0,
				"bounce": int(w.get("bounce", 0)), "expl": float(w.get("expl", 0.0)), "fuse": float(w.get("fuse", 0.0)), "life": float(w.get("life", 3.0)), "flame": w.has("flame")})
	var rk := float(w["rk"])
	f.vel.x -= adir.x * rk
	if adir.y > 0.3 and rk >= 150.0:
		f.vel.y = minf(f.vel.y, -rk * 0.9 * adir.y)
		f.on_ground = false
	elif rk >= 300.0:
		f.vel.y = minf(f.vel.y, -rk * 0.45)
		f.on_ground = false
	f.node.recoil = 1.0
	fx.flash(muzzle, 24.0, 0.1)
	if not w.has("flame"):
		fx.sparks(muzzle, f.face, 3)
	var loud := f.wid in ["sawedoff", "shotgun", "sniper", "rpg", "grenade", "deagle"]
	Game.sfx("boom" if loud else "hit", 1.6 if f.wid in ["uzi", "minigun", "flame"] else 1.2)
	if f.id == my_id:
		shake = maxf(shake, 2.0 + rk * 0.01)
		Game.vibrate(10)
	if net:
		rpc("_ev_shot", muzzle, f.face, f.id)
	if f.ammo <= 0 and not w.has("inf"):
		f.empty_t = 0.4


func _damage_raw(t: Fighter, dmg: float) -> void:
	t.hp -= dmg
	t.damaged = true
	if t.hp <= 0.0:
		_kill(t, t.face)


func _hurt(t: Fighter, dmg: float, dir: int, kb: float, src: Fighter = null, blockable := true) -> bool:
	if state != "fight" or not t.alive:
		return false
	var front := dir == -t.face
	if blockable and t.blocking and front:
		if t.block_age < 0.22:
			_parry(t, src)
			return false
		dmg *= 0.25
		kb *= 0.4
		fx.ring(t.pos + Vector2(float(t.face) * 24.0, -60.0), 40.0)
	t.hp -= dmg
	t.damaged = true
	t.vel.x += float(dir) * kb
	t.vel.y = minf(t.vel.y, -kb * 0.35)
	t.on_ground = false
	t.stun = 0.3 if kb > 300.0 else 0.15
	t.hit_pending = false
	t.burst_left = 0
	t.node.hurt()
	if kb >= 400.0:
		t.node.spin_v = -float(dir) * 9.5
	var hp := t.pos + Vector2(0, -60)
	_fx_hurt(hp, dir, t.idx, t.id == my_id)
	if net:
		rpc("_ev_hurt", t.id, dir, hp)
	if t.hp <= 0.0:
		_kill(t, dir)
	return true


func _parry(t: Fighter, src: Fighter) -> void:
	t.block_en = minf(1.5, t.block_en + 0.5)
	var pos := t.pos + Vector2(float(t.face) * 26.0, -62.0)
	fx.flash(pos, 46.0, 0.2)
	fx.ring(pos, 80.0)
	fx.sparks(pos, t.face, 8)
	Game.sfx("coin", 1.6)
	shake = maxf(shake, 4.0)
	if src != null:
		var d := 1 if src.pos.x > t.pos.x else -1
		src.vel.x += float(d) * 650.0
		src.vel.y = -250.0
		src.on_ground = false
		src.stun = 0.45
		src.hit_pending = false
		src.node.hurt()
	if net:
		rpc("_ev_parry", pos, t.face)


func _fx_hurt(pos: Vector2, dir: int, idx: int, mine: bool) -> void:
	fx.flash(pos, 30.0, 0.15)
	fx.sparks(pos, dir, 7)
	fx.drops(pos, COLORS[idx], 5)
	Game.sfx("hit", randf_range(0.85, 1.1))
	if mine:
		shake = maxf(shake, 5.0)
		Game.vibrate(30)


func _explode(pos: Vector2, radius: float, dmg: float, kb: float, owner: int) -> void:
	_fx_explode(pos, radius)
	if net:
		rpc("_ev_explode", pos, radius)
	var src: Fighter = fighters.get(owner)
	for o in fighters.values():
		var t: Fighter = o
		if not t.alive:
			continue
		var c := t.pos + Vector2(0, -45)
		var d := c.distance_to(pos)
		if d < radius:
			var sc := 1.0 - d / radius * 0.45
			var dir := 1 if c.x >= pos.x else -1
			_hurt(t, dmg * sc, dir, kb * sc, src, false)


func _fx_explode(pos: Vector2, radius: float) -> void:
	fx.flash(pos, radius, 0.35)
	fx.ring(pos, radius * 1.1)
	fx.drops(pos, Color(1.0, 0.6, 0.2), 16)
	fx.sparks(pos, 1, 10, 1.4)
	fx.sparks(pos, -1, 10, 1.4)
	Game.sfx("boom", 0.8)
	shake = maxf(shake, 9.0)
	cam_zoom = minf(cam_zoom + 0.15, 2.2)


func _kill(f: Fighter, dir: int) -> void:
	if not f.alive:
		return
	f.alive = false
	f.hp = 0.0
	f.blocking = false
	f.node.visible = false
	var v := Vector2(float(dir) * 520.0 + f.vel.x, -320.0 + f.vel.y * 0.4)
	_spawn_ragdoll(f.pos, f.idx, v)
	_fx_death(f.pos, f.idx)
	if f.wid != "fists" and f.wid != "godpistol":
		var save_wid := f.wid
		var save_ammo := f.ammo
		f.wid = "fists"
		_drop_item(f.pos + Vector2(0, -50), Vector2(randf_range(-180, 180), -300), save_wid, save_ammo, -1, 0.0)
	f.wid = "fists"
	if net:
		rpc("_ev_kill", f.id, dir, f.pos, v)


func _fx_death(pos: Vector2, idx: int) -> void:
	fx.drops(pos + Vector2(0, -50), Color(0.8, 0.1, 0.15), 14)
	fx.drops(pos + Vector2(0, -50), COLORS[idx], 10)
	fx.flash(pos + Vector2(0, -50), 60.0, 0.25)
	fx.ring(pos + Vector2(0, -50), 100.0)
	Game.sfx("die")
	shake = maxf(shake, 7.0)
	cam_zoom = minf(cam_zoom + 0.12, 2.2)
	var fy := _floor_y(pos.x, pos.y)
	if fy > 0.0:
		for i in 3:
			splats.append(Vector3(pos.x + randf_range(-40, 40), fy, randf_range(10.0, 26.0)))
		queue_redraw()


func _spawn_ragdoll(pos: Vector2, idx: int, vel: Vector2) -> void:
	var r := Ragdoll.new()
	r.z_index = 1
	add_child(r)
	r.setup(pos, COLORS[idx], vel, rects)
	ragdolls.append(r)


func _floor_y(x: float, y: float) -> float:
	var best := -1.0
	for r in rects:
		var rr: Rect2 = r
		if x >= rr.position.x and x <= rr.end.x and rr.position.y >= y - 12.0:
			if best < 0.0 or rr.position.y < best:
				best = rr.position.y
	return best


# ------------------------------------------------------------------ items
func _spawn_crate() -> void:
	if items.size() >= 6:
		return
	var wid: String = DROPS[randi() % DROPS.size()]
	if randf() < 0.12:
		wid = RARE[randi() % RARE.size()]
	items.append({"p": Vector2(randf_range(W * 0.08, W * 0.92), -30.0), "v": Vector2(0, 120.0), "wid": wid, "ammo": int(WP[wid]["ammo"]), "box": true, "landed": false, "owner": -1, "tt": 0.0, "ttl": 0.0, "rot": 0.0})


func _drop_item(p: Vector2, v: Vector2, wid: String, ammo: int, owner: int, tt: float) -> void:
	var ttl := 0.0
	if ammo <= 0 and wid != "fists":
		ttl = 2.5
	if wid == "godpistol" and owner >= 0:
		ttl = 1.5
	items.append({"p": p, "v": v, "wid": wid, "ammo": ammo, "box": false, "landed": false, "owner": owner, "tt": tt, "ttl": ttl, "rot": 0.0})


func _throw_weapon(f: Fighter, tt: float) -> void:
	if f.wid == "fists":
		return
	var dv := Vector2.from_angle(f.aim) if f.aim_on else Vector2(float(f.face), -0.3).normalized()
	_drop_item(f.pos + Vector2(0, -64.0) + dv * 24.0, dv * 720.0 + f.vel * 0.4, f.wid, f.ammo, f.id, tt)
	f.wid = "fists"
	f.ammo = 0
	f.empty_t = 0.0
	f.burst_left = 0
	_equip(f)
	Game.sfx("swing", 0.8)


func _try_pickup(f: Fighter) -> void:
	for i in items.size():
		var it: Dictionary = items[i]
		if bool(it["landed"]) and not bool(it["box"]):
			var d: float = (it["p"] as Vector2).distance_to(f.pos + Vector2(0, -30))
			if d < 42.0:
				f.wid = str(it["wid"])
				f.ammo = int(it["ammo"])
				items.remove_at(i)
				_equip(f)
				Game.sfx("coin", 1.2)
				return


func _update_items(dt: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		if float(it["ttl"]) > 0.0:
			it["ttl"] = float(it["ttl"]) - dt
			if float(it["ttl"]) <= 0.0:
				items.remove_at(i)
				continue
		if bool(it["landed"]):
			continue
		var v: Vector2 = it["v"]
		var p: Vector2 = it["p"]
		v.y += (G * 0.55 if bool(it["box"]) else G) * dt
		if bool(it["box"]):
			v.y = minf(v.y, 260.0)
		else:
			it["rot"] = float(it["rot"]) + 14.0 * dt * signf(v.x if v.x != 0.0 else 1.0)
		var np := p + v * dt
		var hit_floor := false
		for r in rects:
			var rr: Rect2 = r
			if rr.has_point(np + Vector2(0, 6)):
				if v.y > 0.0 and p.y + 6.0 <= rr.position.y + 12.0:
					np.y = rr.position.y - 6.0
					hit_floor = true
				else:
					v.x = -v.x * 0.4
					np.x = p.x
		if hit_floor:
			it["landed"] = true
			it["box"] = false
			it["rot"] = 0.0
			v = Vector2.ZERO
			fx.dust(np, 3)
		if float(it["tt"]) > 0.0:
			it["tt"] = float(it["tt"]) - dt
			for o in fighters.values():
				var t: Fighter = o
				if t.alive and t.id != int(it["owner"]) and Rect2(t.pos.x - 18, t.pos.y - _bh(t) - 8.0, 36, _bh(t) + 8.0).has_point(np):
					var d := 1 if v.x > 0.0 else -1
					_hurt(t, THROW_DMG, d, 480.0, fighters.get(int(it["owner"])))
					it["tt"] = 0.0
					v.x *= -0.3
		it["v"] = v
		it["p"] = np
		if np.y > H + 200.0:
			items.remove_at(i)


func _rect_hit(pt: Vector2) -> int:
	for i in rects.size():
		if (rects[i] as Rect2).has_point(pt):
			return i
	return -1


func _update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var b: Dictionary = projectiles[i]
		var v: Vector2 = b["v"]
		v.y += float(b["g"]) * dt
		var p: Vector2 = b["p"]
		var steps := maxi(1, int(ceil(v.length() * dt / 10.0)))
		var dead_ := false
		var is_gren := str(b["k"]) == "grenade"
		for s in steps:
			var np := p + v * dt / float(steps)
			var ri := _rect_hit(np)
			if ri >= 0:
				if is_gren or int(b["bounce"]) > 0:
					if _rect_hit(Vector2(np.x, p.y)) >= 0:
						v.x = -v.x * (0.5 if is_gren else 1.0)
						np.x = p.x
					else:
						v.y = -v.y * (0.5 if is_gren else 1.0)
						np.y = p.y
					if not is_gren:
						b["bounce"] = int(b["bounce"]) - 1
						if int(b["bounce"]) <= 0:
							dead_ = true
				else:
					dead_ = true
				if dead_:
					p = np
					break
			p = np
			for o in fighters.values():
				var t: Fighter = o
				if not t.alive or t.id == int(b["o"]):
					continue
				if Rect2(t.pos.x - 17, t.pos.y - _bh(t) - 8.0, 34, _bh(t) + 8.0).has_point(p):
					var dirx := 1 if v.x > 0.0 else -1
					if t.blocking and dirx == -t.face and t.block_age < 0.22 and float(b["expl"]) <= 0.0:
						v = -v
						b["o"] = t.id
						b["c"] = t.idx
						_parry(t, null)
						continue
					var rel := p.y - t.pos.y
					var mult := 1.0
					if rel < -(_bh(t) - 10.0):
						mult = 2.0
					elif rel < -(_bh(t) - 22.0):
						mult = 1.5
					if float(b["expl"]) > 0.0:
						dead_ = true
					else:
						_hurt(t, float(b["dmg"]) * mult, dirx, float(b["kb"]), fighters.get(int(b["o"])))
						if bool(b["flame"]):
							t.burn_t = 6.0
						if mult > 1.4:
							fx.text(p + Vector2(0, -20), "x%s" % ("2" if mult > 1.9 else "1.5"), Color(1, 0.9, 0.3), 24)
						dead_ = true
					break
			if dead_:
				break
		b["p"] = p
		b["v"] = v
		b["age"] = float(b["age"]) + dt
		if is_gren:
			b["fuse"] = float(b["fuse"]) - dt
			if float(b["fuse"]) <= 0.0:
				dead_ = true
		if dead_ and float(b["expl"]) > 0.0:
			_explode(p, float(b["expl"]), float(b["dmg"]), float(b["kb"]), int(b["o"]))
		if dead_ or p.x < -100.0 or p.x > W + 100.0 or p.y > H + 200.0 or float(b["age"]) > float(b["life"]):
			projectiles.remove_at(i)


func _update_snakes(dt: float) -> void:
	for i in range(snakes.size() - 1, -1, -1):
		var sn: Dictionary = snakes[i]
		sn["life"] = float(sn["life"]) - dt
		sn["ph"] = float(sn["ph"]) + dt * 12.0
		sn["bite"] = float(sn["bite"]) - dt
		var p: Vector2 = sn["p"]
		var v: Vector2 = sn["v"]
		# chase nearest enemy
		var tgt: Fighter = null
		var bd := 1.0e9
		for o in fighters.values():
			var t: Fighter = o
			if t.alive and t.id != int(sn["o"]):
				var d := absf(t.pos.x - p.x) + absf(t.pos.y - p.y)
				if d < bd:
					bd = d
					tgt = t
		if tgt != null:
			sn["dir"] = 1 if tgt.pos.x > p.x else -1
		v.x = float(sn["dir"]) * 150.0
		v.y += G * 0.8 * dt
		var np := p + v * dt
		if _rect_hit(Vector2(np.x + float(sn["dir"]) * 8.0, p.y - 4.0)) >= 0:
			v.y = -420.0
			np.x = p.x
		var landed := false
		var ri := _rect_hit(Vector2(np.x, np.y + 2.0))
		if ri >= 0 and v.y > 0.0:
			np.y = (rects[ri] as Rect2).position.y
			v.y = 0.0
			landed = true
		if not landed and np.y > H + 150.0:
			sn["life"] = 0.0
		sn["p"] = np
		sn["v"] = v
		if tgt != null and float(sn["bite"]) <= 0.0 and state == "fight":
			if Rect2(tgt.pos.x - 18, tgt.pos.y - 100, 36, 100).has_point(np):
				sn["bite"] = 0.5
				_hurt(tgt, 5.0, int(sn["dir"]), 60.0, fighters.get(int(sn["o"])), false)
		if float(sn["life"]) <= 0.0:
			snakes.remove_at(i)


# ------------------------------------------------------------------ rounds
func _alive_list() -> Array:
	var a: Array = []
	for id in order:
		var f: Fighter = fighters[id]
		if f.alive:
			a.append(f)
	return a


func _check_round_end() -> void:
	if order.size() < 2:
		return
	var al := _alive_list()
	if al.size() > 1:
		return
	state = "over"
	state_t = 2.6
	if al.size() == 1:
		var w: Fighter = al[0]
		w.wins += 1
		_banner_all("%s %s" % [w.pname, Game.t("wins_round")], Game.t("flawless") if not w.damaged else "", 2.0)
		if net:
			rpc("_ev_wins", _wins_dict())
	else:
		_banner_all(Game.t("draw"), "", 2.0)


func _after_round() -> void:
	for id in order:
		var f: Fighter = fighters[id]
		if f.wins >= win_target:
			_end_match(f)
			return
	_start_round()


func _end_match(w: Fighter) -> void:
	if ended:
		return
	ended = true
	var names: Array = []
	var wins: Array = []
	var cols: Array = []
	for id in order:
		var f: Fighter = fighters[id]
		names.append(f.pname)
		wins.append(f.wins)
		cols.append(f.idx)
	var data := {"winner": w.pname, "widx": w.idx, "names": names, "wins": wins, "cols": cols}
	if net:
		rpc("_ev_end", data)
	exit.emit("arena_end", data)


# ------------------------------------------------------------------ bots
func _edge_ahead(f: Fighter) -> bool:
	var x := f.pos.x + float(f.face) * 46.0
	for r in rects:
		var rr: Rect2 = r
		if x >= rr.position.x and x <= rr.end.x and rr.position.y >= f.pos.y - 6.0 and rr.position.y <= f.pos.y + 150.0:
			return false
	return true


func _danger_ahead(f: Fighter) -> bool:
	var x := f.pos.x + float(f.face) * 50.0
	for hz in hazards:
		var r: Rect2 = hz["r"]
		if x >= r.position.x - 20.0 and x <= r.end.x + 20.0:
			return true
	return false


func _bot_think(f: Fighter, dt: float) -> void:
	f.ai_t -= dt
	f.block_hold -= dt
	if f.block_hold <= 0.0:
		f.in_block = false
	if f.ai_t > 0.0:
		return
	f.ai_t = randf_range(0.08, 0.2)
	var tgt: Fighter = null
	var bd := 1.0e9
	for o in fighters.values():
		var t: Fighter = o
		if t == f or not t.alive:
			continue
		var d := absf(t.pos.x - f.pos.x) + absf(t.pos.y - f.pos.y) * 0.5
		if d < bd:
			bd = d
			tgt = t
	f.in_axis = 0.0
	f.in_attack = false
	f.in_jump_held = false
	if tgt == null:
		return
	var w: Dictionary = WP[f.wid]
	var is_gun := bool(w["gun"])
	var has_item := false
	var ip := Vector2.ZERO
	if f.wid == "fists":
		var best := 520.0
		for it in item_view:
			if bool(it[3]) and not bool(it[2]):
				var d2 := absf((it[0] as Vector2).x - f.pos.x) + absf((it[0] as Vector2).y - f.pos.y) * 0.5
				if d2 < best:
					best = d2
					ip = it[0]
					has_item = true
	var goal := ip if has_item else tgt.pos
	var dx := goal.x - f.pos.x
	var ideal := 10.0 if has_item else 64.0
	if not has_item:
		if is_gun:
			ideal = 300.0
			if f.wid == "sniper":
				ideal = 520.0
			elif f.wid in ["sawedoff", "shotgun", "flame"]:
				ideal = 150.0
		elif f.wid == "spear":
			ideal = 110.0
	if absf(dx) > ideal + 24.0:
		f.in_axis = signf(dx)
	elif is_gun and not has_item and absf(dx) < ideal - 90.0:
		f.in_axis = -signf(dx)
	f.want_face = 1 if tgt.pos.x > f.pos.x else -1
	f.aim_on = false
	if is_gun and not has_item:
		f.aim_on = true
		f.aim = ((tgt.pos + Vector2(0, -50)) - (f.pos + Vector2(0, -64))).angle() + randf_range(-0.06, 0.06)
	if has_item:
		f.want_face = 1 if dx >= 0.0 else -1
	var dy := goal.y - f.pos.y
	if f.on_ground:
		var blocked := f.in_axis != 0.0 and absf(f.vel.x) < 20.0
		var edge := f.in_axis != 0.0 and _edge_ahead(f) and not _danger_ahead(f)
		if dy < -70.0 or blocked or (edge and randf() < 0.7) or randf() < 0.012:
			f.jump_t = _now()
			f.in_jump_held = true
	if _danger_ahead(f) and f.in_axis != 0.0 and f.on_ground and randf() < 0.9:
		f.jump_t = _now()
		f.in_jump_held = true
	if not has_item:
		var dist := absf(tgt.pos.x - f.pos.x)
		var same_row := absf(tgt.pos.y - f.pos.y) < 80.0
		if is_gun:
			if same_row and dist < 750.0 and f.face == f.want_face and randf() < 0.75:
				f.in_attack = true
		elif dist < float(w["range"]) - 12.0 and same_row and randf() < 0.8:
			f.in_attack = true
		if not is_gun and f.wid != "fists" and dist > 220.0 and dist < 520.0 and same_row and f.face == f.want_face and randf() < 0.05:
			f.throw_t = _now()
		if tgt.node.is_attacking() and dist < 120.0 and same_row and randf() < 0.35:
			f.in_block = true
			f.block_hold = 0.35


# ------------------------------------------------------------------ networking: host -> clients
func _send_snapshot() -> void:
	if Net.players.size() < 2:
		return
	var fl: Array = []
	for id in order:
		var f: Fighter = fighters[id]
		fl.append([f.id, f.pos.x, f.pos.y, f.vel.x, f.vel.y, f.face, f.hp, f.wid, f.ammo, f.alive,
			f.node.atk_type if f.node.is_attacking() else "", f.node.atk_t, f.node.atk_dur, f.on_ground, f.blocking, f.aim, f.aim_on, f.crouch])
	var bl: Array = []
	for b in projectiles:
		var p: Vector2 = b["p"]
		var v: Vector2 = b["v"]
		bl.append([p.x, p.y, v.x, v.y, b["k"], b["c"]])
	var il: Array = []
	for it in items:
		var p2: Vector2 = it["p"]
		il.append([p2.x, p2.y, it["wid"], it["box"], it["landed"], it["rot"]])
	var sl: Array = []
	for sn in snakes:
		var p3: Vector2 = sn["p"]
		sl.append([p3.x, p3.y, sn["dir"], sn["ph"]])
	rpc("_cl_snap", {"f": fl, "b": bl, "i": il, "n": sl, "s": state, "mt": move_t})


@rpc("authority", "unreliable_ordered")
func _cl_snap(snap: Dictionary) -> void:
	if is_server:
		return
	state = str(snap["s"])
	move_t = float(snap["mt"])
	for d in snap["f"]:
		var f: Fighter = fighters.get(int(d[0]))
		if f == null:
			continue
		f.tx = float(d[1])
		f.ty = float(d[2])
		f.vel = Vector2(float(d[3]), float(d[4]))
		f.face = int(d[5])
		f.hp = float(d[6])
		var wid := str(d[7])
		if wid != f.wid:
			f.wid = wid
			_equip(f)
		f.ammo = int(d[8])
		f.alive = bool(d[9])
		var at := str(d[10])
		var att := float(d[11])
		if att >= 0.0 and at != "":
			if not f.node.is_attacking() or f.node.atk_type != at:
				f.node.play_attack(at, float(d[12]))
			f.node.atk_t = att
		else:
			f.node.atk_t = -1.0
		var was_ground := f.on_ground
		f.on_ground = bool(d[13])
		f.blocking = bool(d[14])
		f.aim = float(d[15])
		f.aim_on = bool(d[16])
		f.crouch = bool(d[17])
		if was_ground and not f.on_ground and f.vel.y < -300.0 and absf(f.vel.x) > 150.0 and not f.node.gun_mode:
			f.node.spin_v = signf(f.vel.x) * 8.7
	proj_view = []
	for b in snap["b"]:
		proj_view.append([Vector2(float(b[0]), float(b[1])), Vector2(float(b[2]), float(b[3])), str(b[4]), int(b[5])])
	item_view = []
	for it in snap["i"]:
		item_view.append([Vector2(float(it[0]), float(it[1])), str(it[2]), bool(it[3]), bool(it[4]), float(it[5])])
	snake_view = []
	for sn in snap["n"]:
		snake_view.append([Vector2(float(sn[0]), float(sn[1])), int(sn[2]), float(sn[3])])


func _client_process(dt: float) -> void:
	var me: Fighter = fighters[my_id]
	if me.bot:
		_bot_think(me, dt)
	else:
		_read_local(me)
	in_t -= dt
	if in_t <= 0.0:
		in_t = 0.033
		rpc_id(1, "_sv_input", me.in_axis, me.in_attack, me.in_jump_held, me.in_block, me.aim, me.aim_on, me.in_crouch)
	if me.jump_t != me.jump_sent:
		me.jump_sent = me.jump_t
		rpc_id(1, "_sv_press", "jump")
	if me.throw_t != me.throw_sent:
		me.throw_sent = me.throw_t
		rpc_id(1, "_sv_press", "dash")
	var k := 1.0 - exp(-20.0 * dt)
	for f in fighters.values():
		var fi: Fighter = f
		fi.pos = fi.pos.lerp(Vector2(fi.tx, fi.ty), k)
	move_t += dt
	for m in movers:
		var base: Rect2 = m["base"]
		var sp: float = m["sp"]
		var off := Vector2(sin(move_t * sp) * float(m["ax"]), sin(move_t * sp) * float(m["ay"]))
		rects[int(m["i"])] = Rect2(base.position + off, base.size)


@rpc("authority", "reliable")
func _ev_round(r: int, midx: int, wins: Dictionary) -> void:
	if is_server:
		return
	round_n = r
	map_idx = midx
	_load_map(midx)
	_clear_round_objects()
	for id in order:
		var f: Fighter = fighters[id]
		f.alive = true
		f.wid = "fists"
		f.blocking = false
		_equip(f)
		f.wins = int(wins.get(id, 0))


@rpc("authority", "reliable")
func _ev_wins(wins: Dictionary) -> void:
	if is_server:
		return
	for id in order:
		(fighters[id] as Fighter).wins = int(wins.get(id, 0))


@rpc("authority", "reliable")
func _ev_banner(title: String, sub: String, hold: float) -> void:
	if is_server:
		return
	_banner(title, sub, hold)


@rpc("authority", "reliable")
func _ev_shot(pos: Vector2, dir: int, id: int) -> void:
	if is_server:
		return
	fx.flash(pos, 24.0, 0.1)
	fx.sparks(pos, dir, 3)
	Game.sfx("hit", 1.3)
	var f: Fighter = fighters.get(id)
	if f != null:
		f.node.recoil = 1.0


@rpc("authority", "reliable")
func _ev_hurt(id: int, dir: int, pos: Vector2) -> void:
	if is_server:
		return
	var f: Fighter = fighters.get(id)
	if f == null:
		return
	f.node.hurt()
	if f.vel.length() > 500.0:
		f.node.spin_v = -float(dir) * 9.5
	_fx_hurt(pos, dir, f.idx, id == my_id)


@rpc("authority", "reliable")
func _ev_parry(pos: Vector2, dir: int) -> void:
	if is_server:
		return
	fx.flash(pos, 46.0, 0.2)
	fx.ring(pos, 80.0)
	fx.sparks(pos, dir, 8)
	Game.sfx("coin", 1.6)


@rpc("authority", "reliable")
func _ev_explode(pos: Vector2, radius: float) -> void:
	if is_server:
		return
	_fx_explode(pos, radius)


@rpc("authority", "reliable")
func _ev_kill(id: int, dir: int, pos: Vector2, vel: Vector2) -> void:
	if is_server:
		return
	var f: Fighter = fighters.get(id)
	if f == null:
		return
	f.alive = false
	_spawn_ragdoll(pos, f.idx, vel)
	_fx_death(pos, f.idx)


@rpc("authority", "reliable")
func _ev_end(data: Dictionary) -> void:
	if is_server or ended:
		return
	ended = true
	exit.emit("arena_end", data)


func _on_players_changed() -> void:
	for id in fighters.keys():
		if not Net.players.has(id):
			var f: Fighter = fighters[id]
			fighters.erase(id)
			order.erase(id)
			f.node.queue_free()


func _on_net_lost() -> void:
	if ended:
		return
	ended = true
	exit.emit("menu", {})


# ------------------------------------------------------------------ pause / leave
func _toggle_pause() -> void:
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null
		get_tree().paused = false
		return
	if ended:
		return
	if not net:
		get_tree().paused = true
	pause_menu = Control.new()
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.add_child(pause_menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	cc.add_child(vb)
	vb.add_child(UIKit.label(Game.t("paused"), 54))
	var b1 := UIKit.button(Game.t("resume"), Vector2(340, 70), true)
	b1.pressed.connect(_toggle_pause)
	vb.add_child(b1)
	var b3 := UIKit.button(Game.t("menu"), Vector2(340, 70))
	b3.pressed.connect(_leave)
	vb.add_child(b3)


func _leave() -> void:
	get_tree().paused = false
	ended = true
	if net:
		Net.leave()
	exit.emit("menu", {})
