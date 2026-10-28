extends Node2D
class_name Battle

signal exit(action: String, data: Dictionary)

const ENEMY := {
	"grunt": {"hp": 38.0, "dmg": 7.0, "spd": 105.0, "reach": 54.0, "cd": 1.5, "s": 1.0, "weapon": "dagger", "coins": 4},
	"runner": {"hp": 24.0, "dmg": 5.0, "spd": 195.0, "reach": 46.0, "cd": 1.0, "s": 0.92, "weapon": "fists", "coins": 5},
	"brute": {"hp": 140.0, "dmg": 16.0, "spd": 68.0, "reach": 74.0, "cd": 2.1, "s": 1.28, "weapon": "hammer", "coins": 14},
	"boss": {"hp": 650.0, "dmg": 22.0, "spd": 92.0, "reach": 96.0, "cd": 1.5, "s": 1.5, "weapon": "katana", "coins": 80},
}

var level_n := 1
var W := 1280.0
var H := 600.0
var ground_y := 468.0
var backdrop: Backdrop
var player: Stickman
var enemies: Array = []
var corpses: Array = []
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
var dash_cd := 0.0
var shake := 0.0
var hitstop := 0.0
var ended := false
var banner_tween: Tween


func _ready() -> void:
	var sz := get_viewport_rect().size
	W = sz.x
	H = sz.y
	backdrop = Backdrop.new()
	backdrop.world = Game.world_of(level_n)
	add_child(backdrop)
	ground_y = backdrop.ground_y
	var st: Dictionary = Game.stats()
	player = _make_fighter(true, "player")
	player.position = Vector2(W * 0.5, ground_y)
	player.max_hp = float(st["hp"])
	player.hp = player.max_hp
	fx = Effects.new()
	fx.z_index = 10
	add_child(fx)
	waves = Game.build_waves(level_n)
	_build_hud()
	var sub := ""
	if level_n == 1:
		sub = "تواضعنا لهم فظنو انهم اقوياء :"
	_banner("%s %d  -  %s" % [Game.t("level"), level_n, Game.level_name(level_n)], sub, 1.8)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_menu == null and not ended:
		_toggle_pause()


# ------------------------------------------------------------------ setup
func _make_fighter(is_p: bool, k: String) -> Stickman:
	var f := Stickman.new()
	f.is_player = is_p
	f.kind = k
	if is_p:
		f.weapon = Game.WEAPONS[Game.equipped]
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
	e.max_hp = float(d["hp"]) * (1.0 + 0.16 * lv)
	e.hp = e.max_hp
	e.dmg = float(d["dmg"]) * (1.0 + 0.09 * lv)
	e.spd = float(d["spd"]) * (1.0 + 0.012 * lv)
	e.reach = float(d["reach"])
	e.atk_cd = randf_range(0.4, 1.2)
	enemies.append(e)
	if k == "boss":
		_banner("BOSS", "", 1.2)


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
	var dr := clampf(1.0 - dash_cd / 0.9, 0.0, 1.0)
	bar.draw_rect(Rect2(x, y + 26, w * 0.55, 6), Color(0, 0, 0, 0.5))
	bar.draw_rect(Rect2(x, y + 26, w * 0.55 * dr, 6), Color(1, 1, 1, 0.85))
	# wave + coins
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


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	var dt := delta
	if hitstop > 0.0:
		hitstop -= delta
		dt = delta * 0.08
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
			end_t -= delta
			if end_t <= 0.0:
				_end(true)
		"lost":
			end_t -= delta
			if end_t <= 0.0:
				_end(false)
	_update_player(dt)
	_update_enemies(dt)
	_update_corpses(dt)
	if shake > 0.0:
		shake = maxf(0.0, shake - 30.0 * delta)
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		position = Vector2.ZERO
	dash_cd = maxf(0.0, dash_cd - dt)
	bar.queue_redraw()


func _next_wave() -> void:
	queue = waves[wave_idx].duplicate()
	wave_idx += 1
	spawn_t = 0.6
	state = "fight"
	_banner("%s %d / %d" % [Game.t("wave"), wave_idx, waves.size()], "", 1.0)


func _update_fight(dt: float) -> void:
	spawn_t -= dt
	if queue.size() > 0 and spawn_t <= 0.0 and enemies.size() < 6:
		_spawn(queue.pop_front())
		spawn_t = 0.9 + randf() * 0.8
	elif queue.is_empty() and enemies.is_empty() and not player.dead:
		if wave_idx >= waves.size():
			state = "won"
			end_t = 1.8
			hitstop = 0.3
			_banner(Game.t("victory"), "", 1.4)
		else:
			state = "clear"
			clear_t = 1.8
			player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.12)
			_banner(Game.t("wave_clear"), "", 1.0)


func _update_player(dt: float) -> void:
	var p := player
	if p.dead:
		return
	var st: Dictionary = Game.stats()
	var axis := controls.axis()
	p.position.x += p.kbv * dt
	p.kbv = move_toward(p.kbv, 0.0, 1500.0 * dt)
	if p.dash_t > 0.0:
		p.dash_t -= dt
		p.position.x += float(p.facing) * 720.0 * dt
		p.vx = float(p.facing) * 720.0
	else:
		var target := axis * 235.0 * float(st["spd"])
		if p.is_attacking():
			target *= 0.35
		p.vx = move_toward(p.vx, target, 2400.0 * dt)
		p.position.x += p.vx * dt
		if axis != 0.0 and not p.is_attacking():
			p.facing = 1 if axis > 0.0 else -1
	p.position.x = clampf(p.position.x, 28.0, W - 28.0)
	if controls.consume("jump") and p.on_ground:
		p.vy = -640.0
		p.on_ground = false
		Game.sfx("swing", 1.5)
	if not p.on_ground:
		p.vy += 1900.0 * dt
		p.position.y += p.vy * dt
		if p.position.y >= ground_y:
			p.position.y = ground_y
			p.vy = 0.0
			p.on_ground = true
	if controls.consume("dash") and dash_cd <= 0.0 and p.dash_t <= 0.0:
		p.dash_t = 0.18
		dash_cd = 0.9
		if axis != 0.0:
			p.facing = 1 if axis > 0.0 else -1
		fx.ring(p.position + Vector2(0, -40), 70.0)
	if (controls.is_held("attack") or controls.consume("attack")) and not p.is_attacking() and p.dash_t <= 0.0:
		_player_attack()
	if p.is_attacking() and not p.hit_done and p.attack_progress() >= 0.38:
		p.hit_done = true
		_player_strike()


func _nearest_enemy(x: float, max_d: float):
	var best = null
	var bd := max_d
	for e in enemies:
		var d := absf(e.position.x - x)
		if d < bd:
			bd = d
			best = e
	return best


func _player_attack() -> void:
	var p := player
	var w: Dictionary = p.weapon
	var ne = _nearest_enemy(p.position.x, 190.0)
	if ne != null:
		p.facing = 1 if ne.position.x > p.position.x else -1
	p.play_attack(float(w["cd"]) + 0.1)
	p.vx *= 0.3
	p.position.x += float(p.facing) * 6.0
	Game.sfx("swing", randf_range(0.9, 1.1))


func _player_strike() -> void:
	var p := player
	var w: Dictionary = p.weapon
	var st: Dictionary = Game.stats()
	var rng := float(w["range"])
	for e in enemies.duplicate():
		var dx: float = (e.position.x - p.position.x) * float(p.facing)
		if dx > -14.0 and dx < rng + 14.0 * e.s and absf(e.position.y - p.position.y) < 80.0:
			var d := float(w["dmg"]) * float(st["dmg"]) * randf_range(0.9, 1.1)
			var crit := randf() < 0.12
			if crit:
				d *= 1.7
			_damage_enemy(e, d, p.facing, float(w["kb"]), crit)


func _damage_enemy(e, amount: float, dir: int, kb: float, crit: bool) -> void:
	e.hp -= amount
	e.hurt()
	e.kbv = float(dir) * kb * 2.2
	e.show_bar = 2.0
	e.atk_t = -1.0
	e.atk_cd = maxf(e.atk_cd, 0.5)
	var hp_: Vector2 = e.position + Vector2(float(dir) * 14.0, -50.0 * e.s)
	fx.flash(hp_, 52.0 if crit else 36.0)
	fx.sparks(hp_, dir, 10 if crit else 6)
	fx.text(e.position + Vector2(0, -105.0 * e.s), str(int(amount)), UIKit.GOLD if crit else Color.WHITE, 34 if crit else 26)
	shake = maxf(shake, 3.0 + kb * 0.012)
	hitstop = 0.1 if kb > 250.0 else (0.08 if crit else 0.05)
	Game.sfx("hit", randf_range(0.9, 1.15))
	Game.vibrate(15)
	if e.hp <= 0.0:
		_kill_enemy(e, dir)


func _kill_enemy(e, dir: int) -> void:
	enemies.erase(e)
	e.die()
	e.kbv = float(dir) * 260.0
	e.z_index = -1
	e.position.y = ground_y - randf() * 5.0
	corpses.append(e)
	if corpses.size() > 36:
		var old = corpses.pop_front()
		old.queue_free()
	kills += 1
	var c := int(ENEMY[e.kind]["coins"])
	coins_earned += c
	fx.text(e.position + Vector2(0, -75), "+%d" % c, UIKit.GOLD, 26)
	fx.flash(e.position + Vector2(0, -45.0 * e.s), 70.0, 0.3)
	Game.sfx("die", randf_range(0.9, 1.1))
	if e.kind == "boss":
		hitstop = 0.4
		shake = 10.0


func _update_enemies(dt: float) -> void:
	var p := player
	for e in enemies:
		e.atk_cd -= dt
		e.position.x += e.kbv * dt
		e.kbv = move_toward(e.kbv, 0.0, 1500.0 * dt)
		e.position.x = clampf(e.position.x, -60.0, W + 60.0)
		if e.hurt_t > 0.0 or p.dead:
			e.vx = 0.0
			continue
		var dist: float = p.position.x - e.position.x
		if not e.is_attacking():
			e.facing = 1 if dist > 0.0 else -1
		if e.is_attacking():
			e.vx = 0.0
			if not e.hit_done and e.attack_progress() >= 0.45:
				e.hit_done = true
				_enemy_strike(e)
		elif absf(dist) > e.reach * 0.8:
			e.vx = float(e.facing) * e.spd
			e.position.x += e.vx * dt
		else:
			e.vx = 0.0
			if e.atk_cd <= 0.0:
				e.play_attack(0.4 if e.kind == "runner" else 0.55)
				e.atk_cd = float(ENEMY[e.kind]["cd"]) * randf_range(0.9, 1.2)
		for o in enemies:
			if o != e and absf(o.position.x - e.position.x) < 26.0:
				var sg := signf(e.position.x - o.position.x)
				if sg == 0.0:
					sg = 1.0 if randf() > 0.5 else -1.0
				e.position.x += sg * 60.0 * dt


func _update_corpses(dt: float) -> void:
	for c in corpses:
		if absf(c.kbv) > 1.0:
			c.position.x = clampf(c.position.x + c.kbv * dt, 10.0, W - 10.0)
			c.kbv = move_toward(c.kbv, 0.0, 700.0 * dt)


func _enemy_strike(e) -> void:
	var p := player
	if p.dead or p.dash_t > 0.0:
		return
	var dx: float = (p.position.x - e.position.x) * float(e.facing)
	if dx > -10.0 and dx < e.reach + 18.0 and absf(p.position.y - e.position.y) < 70.0:
		_damage_player(e.dmg, e.facing)


func _damage_player(amount: float, dir: int) -> void:
	var p := player
	p.hp -= amount
	p.hurt()
	p.kbv = float(dir) * 240.0
	fx.flash(p.position + Vector2(float(-dir) * 6.0, -50), 40.0)
	fx.sparks(p.position + Vector2(0, -50), dir, 5)
	fx.text(p.position + Vector2(0, -105), str(int(amount)), Color(1, 0.4, 0.4), 26)
	shake = maxf(shake, 6.0)
	Game.sfx("hit", 0.7)
	Game.vibrate(40)
	if p.hp <= 0.0:
		p.hp = 0.0
		p.die()
		p.kbv = float(dir) * 200.0
		state = "lost"
		end_t = 1.8
		hitstop = 0.25
		_banner(Game.t("defeat"), "", 1.5)


func _end(win: bool) -> void:
	if ended:
		return
	ended = true
	var ratio := player.hp / player.max_hp
	var stars_n := 1
	if win:
		if ratio > 0.6:
			stars_n = 3
		elif ratio > 0.3:
			stars_n = 2
	var reward := coins_earned
	if win:
		reward += 25 * level_n
	exit.emit("win" if win else "lose", {"stars": stars_n, "coins": reward, "kills": kills, "level": level_n})


# ------------------------------------------------------------------ pause
func _toggle_pause() -> void:
	if pause_menu != null:
		_resume()
		return
	if ended:
		return
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
	exit.emit(action, {})
