extends Node2D
class_name Battle
# Single player + LAN co-op. In LAN mode the host simulates everything and sends snapshots;
# clients send their input and render puppets.

signal exit(action: String, data: Dictionary)

const SEQ := {
	"slash": ["slash_down", "slash_back", "kick", "thrust"],
	"stab": ["thrust", "thrust", "kick", "thrust"],
	"punch": ["thrust", "thrust", "kick", "thrust"],
}
const E_ATK := {
	"grunt": ["slash_down", "thrust"],
	"runner": ["kick", "thrust"],
	"brute": ["slash_down", "slash_down"],
	"boss": ["slash_down", "slash_back", "thrust", "kick"],
}
const E_DUR := {"grunt": 1.45, "runner": 1.0, "brute": 1.7, "boss": 1.15}
const RUN_SPEED := 330.0
const ACCEL := 3400.0
const DECEL := 4200.0
const GRAVITY := 2300.0
const JUMP_V := -780.0

const ENEMY := {
	"grunt": {"hp": 38.0, "dmg": 7.0, "spd": 125.0, "reach": 54.0, "cd": 1.5, "s": 1.0, "weapon": "dagger", "coins": 4},
	"runner": {"hp": 24.0, "dmg": 5.0, "spd": 230.0, "reach": 46.0, "cd": 1.0, "s": 0.92, "weapon": "fists", "coins": 5},
	"brute": {"hp": 140.0, "dmg": 16.0, "spd": 80.0, "reach": 74.0, "cd": 2.1, "s": 1.28, "weapon": "hammer", "coins": 14},
	"boss": {"hp": 650.0, "dmg": 22.0, "spd": 125.0, "reach": 96.0, "cd": 1.5, "s": 1.5, "weapon": "katana", "coins": 80},
}

var level_n := 1
var W := 1280.0
var H := 600.0
var ground_y := 468.0
var net := false
var is_server := true
var my_id := 1

var backdrop: Backdrop
var player: Stickman
var players := {}      # peer_id -> Stickman
var inputs := {}       # peer_id -> remote input state (host only)
var enemies: Array = []   # host only
var puppets := {}      # net_id -> Stickman (client only)
var corpses: Array = []
var next_nid := 1
var net_t := 0.0
var in_t := 0.0
var fx: Effects
var controls: TouchControls
var hud: CanvasLayer
var hud_root: Control
var bar: Control
var banner: Label
var banner_sub: Label
var pause_menu: Control

var waves: Array = []
var queue: Array = []
var wave_idx := 0
var state := "intro"
var intro_t := 2.8
var clear_t := 0.0
var end_t := 0.0
var spawn_t := 0.0
var kills := 0
var coins_earned := 0
var shake := 0.0
var ended := false
var banner_tween: Tween
var cam: Camera2D
var zoom_cur := 1.0
var zoom_tgt := 1.0
var zoom_hold_until := 0
var focus := Vector2.ZERO
var sm_until := 0
var sm_scale := 1.0
var hs_until := 0
var flash_rect: ColorRect
var flash_a := 0.0
var flash_col := Color.WHITE
var bar_top: ColorRect
var bar_bot: ColorRect
var lb_cur := 0.0
var lb_target := 0.0
var lb_until := 0
var combo_count := 0
var combo_timer := 0.0
var combo_label: Label


func _ready() -> void:
	var sz := get_viewport_rect().size
	W = sz.x
	H = sz.y
	net = Net.active
	is_server = (not net) or Net.is_host
	my_id = multiplayer.get_unique_id() if net else 1
	backdrop = Backdrop.new()
	backdrop.world = Game.world_of(level_n)
	add_child(backdrop)
	ground_y = backdrop.ground_y
	_make_players()
	fx = Effects.new()
	fx.z_index = 10
	add_child(fx)
	cam = Camera2D.new()
	cam.position = Vector2(W * 0.5, H * 0.5)
	add_child(cam)
	cam.make_current()
	focus = cam.position
	waves = Game.build_waves(level_n)
	_build_hud()
	if Game.autoplay:
		controls.bot = true
		player.max_hp = 99999.0
		player.hp = 99999.0
	var sub := ""
	if level_n == 1:
		sub = "تواضعنا لهم فظنو انهم اقوياء :"
	_banner("%s %d  -  %s" % [Game.t("level"), level_n, Game.level_name(level_n)], sub, 1.8)
	if net:
		Net.players_changed.connect(_on_players_changed)
		Net.disconnected.connect(_on_net_lost)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_menu == null and not ended and not net:
		_toggle_pause()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ------------------------------------------------------------------ setup
func _make_players() -> void:
	var ids: Array = []
	if net:
		ids = Net.players.keys()
		ids.sort()
	else:
		ids = [1]
	var n := ids.size()
	for i in n:
		var id: int = ids[i]
		var info: Dictionary = Net.players[id] if net else Net.my_info()
		var f := _make_fighter(true, "player", str(info["weapon"]))
		f.net_id = id
		f.max_hp = float(info["hp"])
		f.hp = f.max_hp
		f.dmg_mult = float(info["dmg"])
		f.spd_mult = float(info["spd"])
		f.position = Vector2(W * 0.5 + (float(i) - float(n - 1) * 0.5) * 80.0, ground_y)
		f.nx = f.position.x
		f.ny = f.position.y
		if net and id != my_id:
			f.tag = str(info["name"])
		players[id] = f
		if is_server:
			inputs[id] = {"axis": 0.0, "attack": false, "jump_held": false, "jump_t": -1000, "dash_t": -1000, "attack_t": -1000}
	player = players[my_id]


func _make_fighter(is_p: bool, k: String, wid := "") -> Stickman:
	var f := Stickman.new()
	f.is_player = is_p
	f.kind = k
	if is_p:
		f.weapon = Game.WEAPONS[wid if wid != "" else Game.equipped]
		f.z_index = 2
	else:
		var d: Dictionary = ENEMY[k]
		f.weapon = Game.WEAPONS[d["weapon"]]
		f.s = float(d["s"])
		f.z_index = 1
	add_child(f)
	return f


func _spawn(k: String) -> void:
	var d: Dictionary = ENEMY[k]
	var e := _make_fighter(false, k)
	var left := randi() % 2 == 0
	e.position = Vector2(-40.0 if left else W + 40.0, ground_y)
	e.facing = 1 if left else -1
	var lv := float(level_n - 1)
	var pm := 1.0 + 0.6 * float(players.size() - 1)
	e.max_hp = float(d["hp"]) * (1.0 + 0.16 * lv) * pm
	e.hp = e.max_hp
	e.dmg = float(d["dmg"]) * (1.0 + 0.09 * lv)
	e.spd = float(d["spd"]) * (1.0 + 0.012 * lv)
	e.reach = float(d["reach"])
	e.atk_cd = randf_range(0.4, 1.2)
	e.net_id = next_nid
	next_nid += 1
	enemies.append(e)
	if k == "boss":
		_banner_all("BOSS", "", 1.2)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	hud_root = Control.new()
	hud_root.theme = Game.ui_theme
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud_root)
	bar = Control.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	hud_root.add_child(bar)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	hud_root.add_child(flash_rect)
	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_top.size = Vector2(W, 0)
	hud_root.add_child(bar_top)
	bar_bot = ColorRect.new()
	bar_bot.color = Color.BLACK
	bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bot.position = Vector2(0, H)
	bar_bot.size = Vector2(W, 0)
	hud_root.add_child(bar_bot)
	combo_label = UIKit.label("", 46, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	combo_label.position = Vector2(34, 92 + 20.0 * float(maxi(0, players.size() - 1)))
	combo_label.size = Vector2(300, 60)
	combo_label.pivot_offset = Vector2(20, 30)
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_label.visible = false
	hud_root.add_child(combo_label)
	controls = TouchControls.new()
	hud_root.add_child(controls)
	banner = UIKit.label("", 54)
	banner.position = Vector2(0, H * 0.14)
	banner.size = Vector2(W, 80)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	hud_root.add_child(banner)
	banner_sub = UIKit.label("", 40)
	banner_sub.position = Vector2(0, H * 0.14 + 78)
	banner_sub.size = Vector2(W, 60)
	banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_sub.modulate.a = 0.0
	hud_root.add_child(banner_sub)
	var pb := UIKit.button("II", Vector2(64, 56), false, 28)
	pb.position = Vector2(W - 84, 18)
	pb.pressed.connect(_toggle_pause)
	hud_root.add_child(pb)


func _draw_bar() -> void:
	var f: Font = Game.font
	var ratio := clampf(player.hp / player.max_hp, 0.0, 1.0)
	var x := 30.0
	var y := 26.0
	var w := 280.0
	bar.draw_rect(Rect2(x - 3, y - 3, w + 6, 22), Color(0, 0, 0, 0.45))
	var c := Color(0.35, 0.95, 0.45).lerp(Color(0.95, 0.2, 0.2), 1.0 - ratio)
	bar.draw_rect(Rect2(x, y, w * ratio, 16), c)
	var dr := clampf(1.0 - player.dash_cd / 0.9, 0.0, 1.0)
	bar.draw_rect(Rect2(x, y + 26, w * 0.55, 6), Color(0, 0, 0, 0.5))
	bar.draw_rect(Rect2(x, y + 26, w * 0.55 * dr, 6), Color(1, 1, 1, 0.85))
	var row := 0
	for id in players:
		if id == my_id:
			continue
		var o: Stickman = players[id]
		var oy := y + 46.0 + float(row) * 22.0
		bar.draw_string(f, Vector2(x, oy + 12), o.tag, HORIZONTAL_ALIGNMENT_LEFT, 120, 16, Color(1, 1, 1, 0.85))
		bar.draw_rect(Rect2(x + 110, oy, 160, 8), Color(0, 0, 0, 0.5))
		bar.draw_rect(Rect2(x + 110, oy, 160.0 * clampf(o.hp / maxf(o.max_hp, 1.0), 0.0, 1.0), 8), Color(0.5, 0.9, 1.0, 0.9))
		row += 1
	var wt := "%s %d / %d" % [Game.t("wave"), mini(wave_idx, waves.size()), waves.size()]
	bar.draw_string(f, Vector2(0, 44), wt, HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 1, 1, 0.9))
	bar.draw_circle(Vector2(W - 230, 40), 12, Color(0.75, 0.5, 0.1))
	bar.draw_circle(Vector2(W - 230, 40), 9.5, UIKit.GOLD)
	bar.draw_string(f, Vector2(W - 208, 49), str(coins_earned), HORIZONTAL_ALIGNMENT_LEFT, 110, 26, Color.WHITE)


func _set_banner_alpha(v: float) -> void:
	banner.modulate.a = v
	banner_sub.modulate.a = v


func _banner(title: String, sub := "", hold := 1.4) -> void:
	banner.text = title
	banner_sub.text = sub
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.tween_method(_set_banner_alpha, 0.0, 1.0, 0.25)
	banner_tween.tween_interval(hold)
	banner_tween.tween_method(_set_banner_alpha, 1.0, 0.0, 0.4)


func _banner_all(title: String, sub := "", hold := 1.4) -> void:
	_banner(title, sub, hold)
	if net and is_server:
		rpc("_ev_banner", title, sub, hold)


# ------------------------------------------------------------------ input helpers
func _ax(id: int) -> float:
	if id == my_id:
		return controls.axis()
	return float(inputs[id]["axis"])


func _held(id: int, n: String) -> bool:
	if id == my_id:
		return controls.is_held(n)
	if n == "attack":
		return bool(inputs[id]["attack"])
	if n == "jump":
		return bool(inputs[id]["jump_held"])
	return false


func _pressed(id: int, n: String) -> bool:
	if id == my_id:
		return controls.consume(n)
	var k := n + "_t"
	if Time.get_ticks_msec() - int(inputs[id][k]) < 180:
		inputs[id][k] = -1000
		return true
	return false


@rpc("any_peer", "unreliable")
func _sv_input(axis: float, atk: bool, jh: bool) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if inputs.has(id):
		inputs[id]["axis"] = axis
		inputs[id]["attack"] = atk
		inputs[id]["jump_held"] = jh


@rpc("any_peer", "reliable")
func _sv_press(n: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if inputs.has(id) and inputs[id].has(n + "_t"):
		inputs[id][n + "_t"] = Time.get_ticks_msec()


func _bot_axis_for(p: Stickman) -> float:
	var best = null
	var bd := 4000.0
	var pool: Array = enemies if is_server else puppets.values()
	for e in pool:
		if e.dead:
			continue
		var d := absf(e.position.x - p.position.x)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return 0.0
	var dd: float = best.position.x - p.position.x
	return 0.0 if absf(dd) < 80.0 else signf(dd)


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var target := 1.0
	if now < sm_until:
		target = sm_scale
	if now < hs_until:
		target = minf(target, 0.05)
	if target > Engine.time_scale:
		Engine.time_scale = minf(target, Engine.time_scale + 0.25)
	else:
		Engine.time_scale = target
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	var dt := delta
	if controls.bot:
		controls.bot_axis = _bot_axis_for(player)
	if is_server:
		match state:
			"intro":
				intro_t -= delta
				if intro_t <= 0.0:
					_next_wave()
			"fight":
				_update_fight(dt)
			"clear":
				clear_t -= delta
				if clear_t <= 0.0:
					_next_wave()
			"won":
				end_t -= real_dt
				if end_t <= 0.0:
					_end(true)
			"lost":
				end_t -= real_dt
				if end_t <= 0.0:
					_end(false)
		for id in players.keys():
			_update_fighter(players[id], id, dt)
		_update_enemies(dt)
		if net:
			net_t -= real_dt
			if net_t <= 0.0:
				net_t = 0.05
				_send_snapshot()
	else:
		_client_process(dt, real_dt)
	_update_corpses(dt)
	_update_camera(real_dt, now)
	bar.queue_redraw()


func _update_camera(rdt: float, now: int) -> void:
	if now >= zoom_hold_until:
		zoom_tgt = lerpf(zoom_tgt, 1.0, 1.0 - exp(-5.0 * rdt))
	zoom_cur = lerpf(zoom_cur, zoom_tgt, 1.0 - exp(-16.0 * rdt))
	var z := maxf(zoom_cur, 1.0)
	cam.zoom = Vector2(z, z)
	var f := Vector2(W * 0.5, H * 0.5).lerp(focus, clampf((z - 1.0) * 3.0, 0.0, 1.0))
	var hw := W * 0.5 / z
	var hh := H * 0.5 / z
	f.x = clampf(f.x, hw, W - hw)
	f.y = clampf(f.y, hh, H - hh)
	cam.position = f
	shake = maxf(0.0, shake - 40.0 * rdt)
	cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	flash_a = maxf(0.0, flash_a - 4.0 * rdt)
	flash_rect.color = Color(flash_col.r, flash_col.g, flash_col.b, flash_a)
	if now >= lb_until:
		lb_target = 0.0
	lb_cur = lerpf(lb_cur, lb_target, 1.0 - exp(-10.0 * rdt))
	bar_top.size = Vector2(W, lb_cur)
	bar_bot.position = Vector2(0, H - lb_cur)
	bar_bot.size = Vector2(W, lb_cur)
	combo_timer -= rdt
	if combo_timer <= 0.0 and combo_count > 0:
		combo_count = 0
		combo_label.visible = false
	combo_label.scale = combo_label.scale.lerp(Vector2.ONE, 1.0 - exp(-12.0 * rdt))


func _hitstop(secs: float) -> void:
	hs_until = maxi(hs_until, Time.get_ticks_msec() + int(secs * 1000.0))


func _punch(amount: float, pos: Vector2) -> void:
	zoom_cur = maxf(zoom_cur, amount)
	focus = pos


func _flash(c: Color, a: float) -> void:
	flash_col = c
	flash_a = maxf(flash_a, a)


func _cinematic(scale_: float, secs: float, zoom: float, pos: Vector2, flash_amt: float) -> void:
	var now := Time.get_ticks_msec()
	sm_scale = scale_
	sm_until = now + int(secs * 1000.0)
	zoom_tgt = zoom
	zoom_hold_until = sm_until
	focus = pos
	lb_target = 62.0
	lb_until = sm_until + 200
	_flash(Color.WHITE, flash_amt)
	Game.sfx("boom", 1.0)
	Game.vibrate(70)


func _cinematic_all(scale_: float, secs: float, zoom: float, pos: Vector2, flash_amt: float) -> void:
	_cinematic(scale_, secs, zoom, pos, flash_amt)
	if net and is_server:
		rpc("_ev_cine", scale_, secs, zoom, pos, flash_amt)


func _register_hit() -> void:
	combo_count += 1
	combo_timer = 2.2
	combo_label.visible = true
	combo_label.text = "%d  %s" % [combo_count, Game.t("hits")]
	combo_label.scale = Vector2(1.35, 1.35)


# ------------------------------------------------------------------ waves (host / single)
func _alive_count() -> int:
	var n := 0
	for id in players:
		var p: Stickman = players[id]
		if not p.dead:
			n += 1
	return n


func _next_wave() -> void:
	var anchor := player.position
	for id in players:
		var p: Stickman = players[id]
		if p.dead:
			p.revive(0.4)
			p.position = Vector2(clampf(anchor.x + randf_range(-60.0, 60.0), 40.0, W - 40.0), ground_y)
	queue = waves[wave_idx].duplicate()
	wave_idx += 1
	spawn_t = 0.6
	state = "fight"
	_banner_all("%s %d / %d" % [Game.t("wave"), wave_idx, waves.size()], "", 1.0)


func _update_fight(dt: float) -> void:
	spawn_t -= dt
	var max_alive := 6 + 3 * (players.size() - 1)
	if queue.size() > 0 and spawn_t <= 0.0 and enemies.size() < max_alive:
		_spawn(queue.pop_front())
		spawn_t = 0.9 + randf() * 0.8
	elif queue.is_empty() and enemies.is_empty() and _alive_count() > 0:
		if wave_idx >= waves.size():
			state = "won"
			end_t = 2.2
			_banner_all(Game.t("victory"), "", 1.4)
		else:
			state = "clear"
			clear_t = 1.8
			for id in players:
				var p: Stickman = players[id]
				if not p.dead:
					p.hp = minf(p.max_hp, p.hp + p.max_hp * 0.12)
			_banner_all(Game.t("wave_clear"), "", 1.0)


# ------------------------------------------------------------------ fighters (host / single)
func _update_fighter(p: Stickman, id: int, dt: float) -> void:
	if p.dead:
		return
	var axis := _ax(id)
	p.position.x += p.kbv * dt
	p.kbv = move_toward(p.kbv, 0.0, 1800.0 * dt)
	p.dash_cd = maxf(0.0, p.dash_cd - dt)
	if p.dash_t > 0.0:
		p.dash_t -= dt
		p.position.x += float(p.facing) * 760.0 * dt
		p.vx = float(p.facing) * 760.0
	else:
		var target := axis * RUN_SPEED * p.spd_mult
		if p.is_attacking():
			target *= 0.15
		elif p.hurt_t > 0.0:
			target *= 0.5
		var rate := DECEL
		if absf(target) > absf(p.vx) or signf(target) != signf(p.vx):
			rate = ACCEL
		p.vx = move_toward(p.vx, target, rate * dt)
		p.position.x += p.vx * dt
		if axis != 0.0 and not p.is_attacking() and p.hurt_t <= 0.0:
			p.facing = 1 if axis > 0.0 else -1
	# jump (coyote time + buffered input + variable height)
	if p.on_ground:
		p.coyote = 0.09
	else:
		p.coyote -= dt
	var ap := p.attack_progress()
	if _pressed(id, "jump") and p.coyote > 0.0 and (ap < 0.0 or ap > 0.6):
		p.atk_t = -1.0
		p.vy = JUMP_V
		p.on_ground = false
		p.coyote = 0.0
		p.jump_cut = false
		fx.dust(p.position, 6)
		Game.sfx("swing", 1.5)
	if not p.on_ground:
		p.vy += GRAVITY * dt
		if p.vy < -200.0 and not p.jump_cut and not _held(id, "jump"):
			p.vy *= 0.45
			p.jump_cut = true
		p.position.y += p.vy * dt
		if p.position.y >= ground_y:
			p.position.y = ground_y
			if p.vy > 300.0:
				p.land_t = 0.14
				fx.dust(p.position, 8)
				if p == player:
					shake = maxf(shake, 2.0)
			p.vy = 0.0
			p.on_ground = true
	# dash
	ap = p.attack_progress()
	if _pressed(id, "dash") and p.dash_cd <= 0.0 and p.dash_t <= 0.0 and (ap < 0.0 or ap > 0.5):
		p.atk_t = -1.0
		p.dash_t = 0.2
		p.dash_cd = 0.8
		if axis != 0.0:
			p.facing = 1 if axis > 0.0 else -1
		fx.ring(p.position + Vector2(0, -40), 70.0)
		fx.dust(p.position, 6)
	# attack + combo chaining
	var want := _held(id, "attack") or _pressed(id, "attack")
	if want:
		if not p.is_attacking():
			_player_attack_start(p, id)
		else:
			p.queued_t = 0.25
	p.queued_t -= dt
	if p.is_attacking():
		p.combo_t = 0.5
		if p.queued_t > 0.0 and p.attack_progress() >= 0.6:
			_player_attack_start(p, id)
	else:
		p.combo_t -= dt
	if p.is_attacking():
		var a: Dictionary = p.cur_atk
		var apn := p.attack_progress()
		if p.lunge_total != 0.0 and apn >= float(a["ms"]) and apn <= float(a["me"]):
			var win := (float(a["me"]) - float(a["ms"])) * p.atk_dur
			p.position.x += float(p.facing) * p.lunge_total * dt / win
		if not p.hit_done and apn >= float(a["hit"]):
			p.hit_done = true
			_player_strike(p)
	# running dust
	if p.on_ground and absf(p.vx) > 200.0:
		p.run_dust_t -= dt
		if p.run_dust_t <= 0.0:
			fx.dust(p.position + Vector2(float(-p.facing) * 12.0, 0), 1)
			p.run_dust_t = 0.11
	p.position.x = clampf(p.position.x, 28.0, W - 28.0)


func _nearest_enemy(x: float, max_d: float):
	var best = null
	var bd := max_d
	for e in enemies:
		var d := absf(e.position.x - x)
		if d < bd:
			bd = d
			best = e
	return best


func _player_attack_start(p: Stickman, id: int) -> void:
	var seq: Array = SEQ[p.style()]
	var atk := ""
	if not p.on_ground:
		atk = "air"
	elif p.dash_t > 0.0:
		atk = "thrust"
	else:
		if p.combo_t <= 0.0:
			p.combo = 0
		atk = seq[p.combo % seq.size()]
		p.combo += 1
	p.finisher = atk == "thrust" and p.combo > 0 and p.combo % 4 == 0 and p.on_ground and p.dash_t <= 0.0
	var axis := _ax(id)
	var ne = _nearest_enemy(p.position.x, 230.0)
	if axis != 0.0:
		p.facing = 1 if axis > 0.0 else -1
	elif ne != null:
		p.facing = 1 if ne.position.x > p.position.x else -1
	var a: Dictionary = Stickman.ATK[atk]
	var w: Dictionary = p.weapon
	var sp := clampf(float(w["cd"]) / 0.36, 0.7, 1.7)
	p.play_attack(atk, float(a["dur"]) * sp)
	var lunge := float(a["lunge"])
	if ne != null and (ne.position.x - p.position.x) * float(p.facing) > 0.0:
		var gap: float = absf(ne.position.x - p.position.x) - float(w["range"]) * 0.7
		lunge = clampf(gap, 18.0, lunge * 1.5)
	p.lunge_total = lunge
	p.queued_t = 0.0
	Game.sfx("swing", randf_range(0.9, 1.15))


func _player_strike(p: Stickman) -> void:
	var a: Dictionary = p.cur_atk
	var w: Dictionary = p.weapon
	var rng := float(w["range"]) + float(a["reach"])
	if a.has("abs"):
		rng = float(a["abs"])
	var kb := float(w["kb"]) * float(a["kb"])
	if p.finisher:
		kb *= 1.7
	var ymax := 130.0 if p.atk_type == "air" else 90.0
	var any_hit := false
	for e in enemies.duplicate():
		var dx: float = (e.position.x - p.position.x) * float(p.facing)
		if dx > -16.0 and dx < rng + 16.0 * e.s and absf(e.position.y - p.position.y) < ymax:
			var d := float(w["dmg"]) * p.dmg_mult * float(a["dmg"]) * randf_range(0.92, 1.08)
			var crit := randf() < 0.12
			if crit:
				d *= 1.7
			if p.finisher:
				d *= 1.4
				crit = true
			_damage_enemy(e, d, p.facing, kb, crit, p)
			any_hit = true
	if any_hit and p.finisher:
		var fp := p.position + Vector2(float(p.facing) * 50.0, -60.0)
		_cinematic_all(0.28, 0.5, 1.28, fp, 0.55)
		var tp := p.position + Vector2(0, -150)
		fx.text(tp, Game.t("finish"), UIKit.GOLD, 46)
		if net:
			rpc("_ev_text", tp, Game.t("finish"), UIKit.GOLD, 46)
		p.finisher = false


func _damage_enemy(e, amount: float, dir: int, kb: float, crit: bool, attacker: Stickman) -> void:
	e.hp -= amount
	e.hurt()
	e.hurt_t = 0.25 + clampf(kb / 1200.0, 0.0, 0.4)
	e.kbv = float(dir) * kb * 2.4
	var heavy := kb >= 250.0 or crit
	if heavy:
		e.pop_vy = -240.0
	e.show_bar = 2.0
	e.atk_cd = maxf(e.atk_cd, 0.6)
	var hp_: Vector2 = e.position + Vector2(float(dir) * 14.0, -55.0 * e.s)
	var aid: int = attacker.net_id
	_fx_hit(hp_, dir, int(amount), heavy, crit, kb, aid == my_id)
	if net:
		rpc("_ev_hit", hp_, dir, int(amount), heavy, crit, kb, aid, int(e.net_id))
	if e.hp <= 0.0:
		_kill_enemy(e, dir, heavy)


func _kill_enemy(e, dir: int, heavy := false) -> void:
	enemies.erase(e)
	e.die()
	e.kbv = float(dir) * 420.0
	if heavy:
		e.flip = true
		e.pop_vy = -520.0
		e.kbv = float(dir) * 480.0
	e.z_index = -1
	corpses.append(e)
	if corpses.size() > 36:
		var old = corpses.pop_front()
		old.queue_free()
	kills += 1
	var c := int(ENEMY[e.kind]["coins"])
	coins_earned += c
	_fx_kill(e.position, c)
	if net:
		rpc("_ev_kill", int(e.net_id), dir, heavy, e.position, c)
	var last_of_level := enemies.is_empty() and queue.is_empty() and wave_idx >= waves.size()
	if e.kind == "boss" or last_of_level:
		_cinematic_all(0.18, 1.1, 1.45, e.position + Vector2(0, -50), 0.6)
		shake = 10.0
	elif enemies.is_empty() and queue.is_empty():
		_cinematic_all(0.45, 0.4, 1.16, e.position + Vector2(0, -50), 0.25)


func _update_enemies(dt: float) -> void:
	for e in enemies:
		e.atk_cd -= dt
		e.position.x += e.kbv * dt
		e.kbv = move_toward(e.kbv, 0.0, 1500.0 * dt)
		e.position.x = clampf(e.position.x, -60.0, W + 60.0)
		var p = _nearest_player(e.position.x)
		if e.hurt_t > 0.0 or p == null:
			e.vx = 0.0
			continue
		var dist: float = p.position.x - e.position.x
		if not e.is_attacking():
			e.facing = 1 if dist > 0.0 else -1
		if e.is_attacking():
			e.vx = 0.0
			var a: Dictionary = e.cur_atk
			var apn: float = e.attack_progress()
			if e.lunge_total != 0.0 and apn >= float(a["ms"]) and apn <= float(a["me"]):
				var win: float = (float(a["me"]) - float(a["ms"])) * float(e.atk_dur)
				e.position.x += float(e.facing) * e.lunge_total * dt / win
			if not e.hit_done and apn >= float(a["hit"]):
				e.hit_done = true
				_enemy_strike(e)
		elif absf(dist) > e.reach + 36.0:
			e.vx = float(e.facing) * e.spd
			e.position.x += e.vx * dt
		else:
			e.vx = 0.0
			if e.atk_cd <= 0.0:
				var arr: Array = E_ATK[e.kind]
				var at: String = arr[randi() % arr.size()]
				var ad: Dictionary = Stickman.ATK[at]
				e.play_attack(at, float(ad["dur"]) * float(E_DUR[e.kind]))
				e.lunge_total = float(ad["lunge"]) * 0.8
				e.atk_cd = float(ENEMY[e.kind]["cd"]) * randf_range(0.9, 1.2)
		for o in enemies:
			if o != e and absf(o.position.x - e.position.x) < 26.0:
				var sg := signf(e.position.x - o.position.x)
				if sg == 0.0:
					sg = 1.0 if randf() > 0.5 else -1.0
				e.position.x += sg * 60.0 * dt


func _nearest_player(x: float):
	var best = null
	var bd := 1.0e9
	for id in players:
		var p: Stickman = players[id]
		if p.dead:
			continue
		var d := absf(p.position.x - x)
		if d < bd:
			bd = d
			best = p
	return best


func _update_corpses(dt: float) -> void:
	for c in corpses:
		if absf(c.kbv) > 1.0:
			c.position.x = clampf(c.position.x + c.kbv * dt, 10.0, W - 10.0)
			var fr := 300.0 if c.pop_y < -1.0 else 1500.0
			c.kbv = move_toward(c.kbv, 0.0, fr * dt)


func _enemy_strike(e) -> void:
	var a: Dictionary = e.cur_atk
	var rr: float = e.reach + float(a["reach"]) * 0.5
	if a.has("abs"):
		rr = float(a["abs"]) * 0.8
	for id in players.keys():
		var p: Stickman = players[id]
		if p.dead or p.dash_t > 0.0:
			continue
		var dx: float = (p.position.x - e.position.x) * float(e.facing)
		if dx > -10.0 and dx < rr + 18.0 and absf(p.position.y - e.position.y) < 70.0:
			_damage_player(p, e.dmg * float(a["dmg"]), e.facing)


func _damage_player(p: Stickman, amount: float, dir: int) -> void:
	p.hp -= amount
	p.hurt()
	p.combo = 0
	p.kbv = float(dir) * 300.0
	p.pop_vy = -150.0
	_fx_hurt(p.position, dir, int(amount), p == player)
	if net:
		rpc("_ev_hurt", p.net_id, dir, int(amount))
	if p.hp <= 0.0:
		p.hp = 0.0
		p.die()
		p.kbv = float(dir) * 300.0
		if _alive_count() == 0 and state != "lost":
			state = "lost"
			end_t = 2.0
			_cinematic_all(0.25, 1.0, 1.3, p.position + Vector2(0, -50), 0.3)
			_banner_all(Game.t("defeat"), "", 1.5)


func _end(win: bool) -> void:
	if ended:
		return
	ended = true
	var ratio := 0.0
	for id in players:
		var p: Stickman = players[id]
		ratio += p.hp / maxf(p.max_hp, 1.0)
	ratio /= float(maxi(players.size(), 1))
	var stars_n := 1
	if win:
		if ratio > 0.6:
			stars_n = 3
		elif ratio > 0.3:
			stars_n = 2
	var reward := coins_earned
	if win:
		reward += 25 * level_n
	var data := {"stars": stars_n, "coins": reward, "kills": kills, "level": level_n}
	if net:
		rpc("_ev_end", win, data)
	exit.emit("win" if win else "lose", data)


# ------------------------------------------------------------------ shared visual effects
func _fx_hit(pos: Vector2, dir: int, amount: int, heavy: bool, crit: bool, kb: float, mine: bool) -> void:
	fx.flash(pos, 56.0 if crit else 38.0)
	fx.sparks(pos, dir, 10 if crit else 6)
	if heavy:
		fx.slash(pos, dir, 120.0 if crit else 100.0)
		fx.sparks(pos, dir, 16, 1.8)
		fx.ring(pos, 90.0)
	fx.text(pos + Vector2(0, -60), str(amount), UIKit.GOLD if crit else Color.WHITE, 34 if crit else 26)
	shake = maxf(shake, 3.0 + kb * 0.012)
	_hitstop(clampf(0.05 + kb * 0.0004, 0.05, 0.16))
	Game.sfx("hit", randf_range(0.9, 1.15))
	if mine:
		_register_hit()
		_punch(1.04 + minf(kb * 0.0002, 0.07), pos)
		Game.vibrate(15)


func _fx_kill(pos: Vector2, coins: int) -> void:
	fx.text(pos + Vector2(0, -75), "+%d" % coins, UIKit.GOLD, 26)
	fx.flash(pos + Vector2(0, -45), 70.0, 0.3)
	Game.sfx("die", randf_range(0.9, 1.1))


func _fx_hurt(pos: Vector2, dir: int, amount: int, mine: bool) -> void:
	fx.flash(pos + Vector2(float(-dir) * 6.0, -55), 44.0)
	fx.sparks(pos + Vector2(0, -55), dir, 5)
	fx.text(pos + Vector2(0, -120), str(amount), Color(1, 0.4, 0.4), 26)
	Game.sfx("hit", 0.7)
	if mine:
		shake = maxf(shake, 6.0)
		_flash(Color(1, 0.15, 0.15), 0.28)
		_hitstop(0.07)
		Game.vibrate(40)


# ------------------------------------------------------------------ networking: host -> clients
func _pack(f: Stickman) -> Array:
	return [f.net_id, f.kind, f.position.x, f.position.y, f.facing, f.vx, f.hp, f.max_hp,
		f.atk_type if f.is_attacking() else "", f.atk_t, f.atk_dur, f.dash_t, f.on_ground, f.dead, f.vy]


func _send_snapshot() -> void:
	if Net.players.size() < 2:
		return
	var pl: Array = []
	for id in players:
		pl.append(_pack(players[id]))
	var en: Array = []
	for e in enemies:
		en.append(_pack(e))
	rpc("_cl_snap", {"w": wave_idx, "c": coins_earned, "p": pl, "e": en})


@rpc("authority", "unreliable_ordered")
func _cl_snap(snap: Dictionary) -> void:
	if is_server:
		return
	wave_idx = int(snap["w"])
	coins_earned = int(snap["c"])
	var now := Time.get_ticks_msec() / 1000.0
	for d in snap["p"]:
		var f = players.get(int(d[0]))
		if f != null:
			_apply(f, d, now)
	for d in snap["e"]:
		var nid := int(d[0])
		var f = puppets.get(nid)
		if f == null:
			f = _make_fighter(false, str(d[1]))
			f.net_id = nid
			f.position = Vector2(float(d[2]), float(d[3]))
			puppets[nid] = f
		_apply(f, d, now)


func _apply(f, d: Array, now: float) -> void:
	f.nx = float(d[2])
	f.ny = float(d[3])
	f.facing = int(d[4])
	f.vx = float(d[5])
	f.hp = float(d[6])
	f.max_hp = float(d[7])
	var at: String = d[8]
	var att: float = d[9]
	if att >= 0.0 and at != "":
		if not f.is_attacking() or f.atk_type != at:
			f.play_attack(at, float(d[10]))
		f.atk_t = att
	else:
		f.atk_t = -1.0
	f.dash_t = float(d[11])
	f.on_ground = bool(d[12])
	f.vy = float(d[14])
	var dead_ := bool(d[13])
	if dead_ and not f.dead:
		f.die()
	elif (not dead_) and f.dead and f.is_player:
		f.revive(float(d[6]) / maxf(f.max_hp, 1.0))
	f.seen_t = now


@rpc("authority", "reliable")
func _ev_hit(pos: Vector2, dir: int, amount: int, heavy: bool, crit: bool, kb: float, aid: int, nid: int) -> void:
	if is_server:
		return
	_fx_hit(pos, dir, amount, heavy, crit, kb, aid == my_id)
	var f = puppets.get(nid)
	if f != null:
		f.hurt()
		f.show_bar = 2.0
		if heavy:
			f.pop_vy = -240.0


@rpc("authority", "reliable")
func _ev_kill(nid: int, dir: int, heavy: bool, pos: Vector2, coins: int) -> void:
	if is_server:
		return
	_fx_kill(pos, coins)
	var f = puppets.get(nid)
	if f == null:
		return
	puppets.erase(nid)
	f.die()
	f.kbv = float(dir) * 420.0
	if heavy:
		f.flip = true
		f.pop_vy = -520.0
		f.kbv = float(dir) * 480.0
	f.z_index = -1
	corpses.append(f)
	if corpses.size() > 36:
		var old = corpses.pop_front()
		old.queue_free()


@rpc("authority", "reliable")
func _ev_hurt(pid: int, dir: int, amount: int) -> void:
	if is_server:
		return
	var f = players.get(pid)
	if f == null:
		return
	f.hurt()
	f.pop_vy = -150.0
	_fx_hurt(f.position, dir, amount, pid == my_id)


@rpc("authority", "reliable")
func _ev_banner(title: String, sub: String, hold: float) -> void:
	if is_server:
		return
	_banner(title, sub, hold)


@rpc("authority", "reliable")
func _ev_cine(scale_: float, secs: float, zoom: float, pos: Vector2, flash_amt: float) -> void:
	if is_server:
		return
	_cinematic(scale_, secs, zoom, pos, flash_amt)


@rpc("authority", "reliable")
func _ev_text(pos: Vector2, s: String, col: Color, size: int) -> void:
	if is_server:
		return
	fx.text(pos, s, col, size)


@rpc("authority", "reliable")
func _ev_end(win: bool, data: Dictionary) -> void:
	if is_server or ended:
		return
	ended = true
	exit.emit("win" if win else "lose", data)


# ------------------------------------------------------------------ networking: client side
func _client_process(dt: float, real_dt: float) -> void:
	in_t -= real_dt
	if in_t <= 0.0:
		in_t = 0.033
		rpc_id(1, "_sv_input", controls.axis(), controls.is_held("attack"), controls.is_held("jump"))
	for n in ["jump", "dash", "attack"]:
		if controls.consume(n):
			rpc_id(1, "_sv_press", n)
			if n == "dash" and player.dash_cd <= 0.0:
				player.dash_cd = 0.8
	player.dash_cd = maxf(0.0, player.dash_cd - dt)
	var k := 1.0 - exp(-20.0 * real_dt)
	for id in players:
		var f: Stickman = players[id]
		f.position = f.position.lerp(Vector2(f.nx, f.ny), k)
	var now := Time.get_ticks_msec() / 1000.0
	for nid in puppets.keys():
		var e: Stickman = puppets[nid]
		e.position = e.position.lerp(Vector2(e.nx, e.ny), k)
		if now - e.seen_t > 1.0:
			e.queue_free()
			puppets.erase(nid)
	if player.on_ground and absf(player.vx) > 200.0 and not player.dead:
		player.run_dust_t -= dt
		if player.run_dust_t <= 0.0:
			fx.dust(player.position + Vector2(float(-player.facing) * 12.0, 0), 1)
			player.run_dust_t = 0.11


func _on_players_changed() -> void:
	for id in players.keys():
		if not Net.players.has(id):
			var f: Stickman = players[id]
			players.erase(id)
			inputs.erase(id)
			f.queue_free()


func _on_net_lost() -> void:
	if ended:
		return
	ended = true
	exit.emit("menu", {})


# ------------------------------------------------------------------ pause / leave
func _toggle_pause() -> void:
	if pause_menu != null:
		_resume()
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
	b1.pressed.connect(_resume)
	vb.add_child(b1)
	if not net:
		var b2 := UIKit.button(Game.t("retry"), Vector2(340, 70))
		b2.pressed.connect(func(): _leave("retry"))
		vb.add_child(b2)
	var b3 := UIKit.button(Game.t("menu"), Vector2(340, 70))
	b3.pressed.connect(func(): _leave("menu"))
	vb.add_child(b3)


func _resume() -> void:
	get_tree().paused = false
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null


func _leave(action: String) -> void:
	get_tree().paused = false
	ended = true
	if net:
		Net.leave()
	exit.emit(action, {})
