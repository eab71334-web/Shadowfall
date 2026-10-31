extends Node

var ui_layer: CanvasLayer
var ui_root: Control
var current: Control
var menu_root: Node2D
var menu_backdrop: Backdrop
var battle: Battle
var arena: Arena
var radar: Control
var radar_a := 0.0
var lobby_body: Control
var shop_tab := "weapons"
var shop_scroll := 0
var reset_armed := false

var duel_a: Stickman
var duel_b: Stickman
var duel_t := 1.0
var duel_turn := 0


func _ready() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 2
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.theme = Game.ui_theme
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)
	Net.battle_start.connect(_on_net_start)
	Net.join_failed.connect(_on_join_failed)
	var uargs := OS.get_cmdline_user_args()
	for ua in uargs:
		var us: String = ua
		if us == "--arena-bots":
			Game.autoplay = true
			Game.sound_on = false
			start_arena(0)
			return
		if us == "--lan-host":
			_ci_lan_host()
			return
		if us.begins_with("--lan-join="):
			_ci_lan_join(us.substr(11))
			return
	if "--autoplay" in uargs or "autoplay" in uargs:
		Game.autoplay = true
		Game.sound_on = false
		Game.owned = ["fists", "sword"]
		Game.equipped = "sword"
		start_battle(1)
		return
	show_menu()


func _vsize() -> Vector2:
	return get_viewport().get_visible_rect().size


# ------------------------------------------------------------ helpers
func _new_screen() -> Control:
	if current:
		current.queue_free()
	current = Control.new()
	current.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(current)
	current.modulate.a = 0.0
	create_tween().tween_property(current, "modulate:a", 1.0, 0.18)
	return current


func _clear_menu_scene() -> void:
	if menu_root:
		menu_root.queue_free()
		menu_root = null
	duel_a = null
	duel_b = null


func _build_menu_scene() -> void:
	_clear_menu_scene()
	menu_root = Node2D.new()
	add_child(menu_root)
	menu_backdrop = Backdrop.new()
	menu_backdrop.world = 0
	menu_root.add_child(menu_backdrop)
	var gy := menu_backdrop.ground_y
	var vw := _vsize().x
	# fallen bodies like in the reference video
	for i in 7:
		var c := Stickman.new()
		c.weapon = Game.WEAPONS["fists"]
		c.facing = 1 if i % 2 == 0 else -1
		c.position = Vector2(randf_range(60.0, vw - 60.0), gy - randf() * 5.0)
		menu_root.add_child(c)
		c.make_corpse()
	duel_a = Stickman.new()
	duel_a.weapon = Game.WEAPONS["katana"]
	duel_a.s = 1.15
	duel_a.facing = 1
	duel_a.position = Vector2(vw * 0.40, gy)
	duel_b = Stickman.new()
	duel_b.weapon = Game.WEAPONS["sword"]
	duel_b.s = 1.15
	duel_b.facing = -1
	duel_b.position = Vector2(vw * 0.60, gy)
	menu_root.add_child(duel_a)
	menu_root.add_child(duel_b)


func _process(delta: float) -> void:
	if radar != null and is_instance_valid(radar):
		radar_a += delta * 3.0
		radar.queue_redraw()
	if duel_a == null or not is_instance_valid(duel_a):
		return
	duel_t -= delta
	if duel_t <= 0.0:
		duel_t = 1.25
		var atk := duel_a if duel_turn == 0 else duel_b
		var tgt := duel_b if duel_turn == 0 else duel_a
		var types := ["slash_down", "thrust", "slash_back", "kick"]
		var tp: String = types[randi() % types.size()]
		atk.play_attack(tp, float(Stickman.ATK[tp]["dur"]) * 1.2)
		duel_turn = 1 - duel_turn
		get_tree().create_timer(0.24).timeout.connect(func():
			if is_instance_valid(tgt):
				tgt.hurt())


func _menu_fighters(show_: bool) -> void:
	if menu_root == null:
		return
	for ch in menu_root.get_children():
		if ch is Stickman:
			ch.visible = show_


func _coin_pill() -> PanelContainer:
	var p := UIKit.panel(UIKit.PANEL, Color(1, 0.8, 0.3, 0.5))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	p.add_child(hb)
	hb.add_child(UIKit.coin_icon(30.0))
	var l := UIKit.label(str(Game.coins), 28, UIKit.GOLD)
	l.custom_minimum_size = Vector2(80, 0)
	hb.add_child(l)
	Game.coins_changed.connect(func():
		if is_instance_valid(l):
			l.text = str(Game.coins))
	return p


func _top_bar(parent: Control, title: String, back_cb: Callable) -> void:
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hb.offset_left = 28
	hb.offset_right = -28
	hb.offset_top = 20
	hb.offset_bottom = 88
	hb.add_theme_constant_override("separation", 16)
	parent.add_child(hb)
	var b := UIKit.button(Game.t("back"), Vector2(170, 62), false, 24)
	b.pressed.connect(back_cb)
	hb.add_child(b)
	var tl := UIKit.label(title, 42)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(tl)
	hb.add_child(_coin_pill())


# ------------------------------------------------------------ menu
func show_menu() -> void:
	if Net.active:
		Net.leave()
	_build_menu_scene()
	var s := _new_screen()
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 22
	vb.add_theme_constant_override("separation", 4)
	s.add_child(vb)
	var title := UIKit.label("SHADOWFALL", 88)
	title.add_theme_constant_override("outline_size", 9)
	vb.add_child(title)
	vb.add_child(UIKit.label("سقوط الظلال", 34, Color(1, 0.9, 0.8)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	vb.add_child(sp)
	var r1 := HBoxContainer.new()
	r1.alignment = BoxContainer.ALIGNMENT_CENTER
	r1.add_theme_constant_override("separation", 16)
	vb.add_child(r1)
	var bp := UIKit.button(Game.t("play"), Vector2(300, 76), true, 32)
	bp.pressed.connect(show_levels)
	r1.add_child(bp)
	var ba := UIKit.button(Game.t("arena"), Vector2(300, 76), true, 32)
	ba.pressed.connect(show_arena_setup)
	r1.add_child(ba)
	var r2 := HBoxContainer.new()
	r2.alignment = BoxContainer.ALIGNMENT_CENTER
	r2.add_theme_constant_override("separation", 14)
	vb.add_child(r2)
	var bs := UIKit.button(Game.t("shop"), Vector2(200, 62), false, 24)
	bs.pressed.connect(show_shop)
	r2.add_child(bs)
	var bl := UIKit.button(Game.t("lan"), Vector2(200, 62), false, 24)
	bl.pressed.connect(show_lan)
	r2.add_child(bl)
	var bt := UIKit.button(Game.t("settings"), Vector2(200, 62), false, 24)
	bt.pressed.connect(show_settings)
	r2.add_child(bt)
	var pill := _coin_pill()
	pill.position = Vector2(_vsize().x - 200, 18)
	s.add_child(pill)


# ------------------------------------------------------------ levels
func show_levels() -> void:
	_menu_fighters(false)
	var s := _new_screen()
	_top_bar(s, Game.t("levels"), show_menu)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 90
	s.add_child(cc)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	cc.add_child(grid)
	for n in range(1, Game.MAX_LEVEL + 1):
		var unlocked := Game.is_unlocked(n)
		var txt := ""
		if unlocked:
			var sc := Game.star_count(n)
			txt = "%d\n%s\n%s" % [n, Game.level_name(n), "★".repeat(sc) + "☆".repeat(3 - sc)]
		else:
			txt = "%d\n%s" % [n, Game.t("locked")]
		var b := UIKit.button(txt, Vector2(190, 160), Game.is_boss_level(n), 22)
		b.disabled = not unlocked
		if Game.is_boss_level(n) and unlocked:
			b.text += "\n" + Game.t("boss")
		var lvl := n
		b.pressed.connect(func(): start_battle(lvl))
		grid.add_child(b)


# ------------------------------------------------------------ shop
func show_shop() -> void:
	_menu_fighters(false)
	var s := _new_screen()
	_top_bar(s, Game.t("shop"), show_menu)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_top = 96
	tabs.offset_bottom = 156
	tabs.add_theme_constant_override("separation", 14)
	s.add_child(tabs)
	var tw := UIKit.button(Game.t("weapons"), Vector2(240, 56), shop_tab == "weapons", 24)
	tw.pressed.connect(func():
		shop_tab = "weapons"
		shop_scroll = 0
		show_shop())
	tabs.add_child(tw)
	var tu := UIKit.button(Game.t("upgrades"), Vector2(240, 56), shop_tab == "upgrades", 24)
	tu.pressed.connect(func():
		shop_tab = "upgrades"
		show_shop())
	tabs.add_child(tu)
	if shop_tab == "weapons":
		_shop_weapons(s)
	else:
		_shop_upgrades(s)


func _stat_row(name_: String, value: float, maxv: float) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var l := UIKit.label(name_, 17, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(72, 0)
	hb.add_child(l)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(110, 10)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.show_percentage = false
	pb.max_value = maxv
	pb.value = value
	pb.add_theme_stylebox_override("background", UIKit.box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 5, 0))
	pb.add_theme_stylebox_override("fill", UIKit.box(Color(1, 1, 1, 0.9), Color(0, 0, 0, 0), 5, 0))
	hb.add_child(pb)
	return hb


func _shop_weapons(s: Control) -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = 170
	sc.offset_bottom = -16
	sc.offset_left = 20
	sc.offset_right = -20
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.add_child(sc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	sc.add_child(row)
	for id in Game.WEAPON_ORDER:
		var w: Dictionary = Game.WEAPONS[id]
		var card := UIKit.panel(UIKit.CARD)
		row.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		card.add_child(vb)
		var prev := Control.new()
		prev.custom_minimum_size = Vector2(220, 150)
		prev.clip_contents = true
		var bg := ColorRect.new()
		bg.color = Color(0.55, 0.36, 0.33)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prev.add_child(bg)
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.9)
		line.position = Vector2(0, 132)
		line.size = Vector2(220, 2)
		prev.add_child(line)
		var st := Stickman.new()
		st.weapon = w
		st.position = Vector2(100, 132)
		st.s = 1.0
		prev.add_child(st)
		vb.add_child(prev)
		vb.add_child(UIKit.label(Game.wname(id), 24))
		vb.add_child(_stat_row(Game.t("dmg"), float(w["dmg"]), 70.0))
		vb.add_child(_stat_row(Game.t("range"), float(w["range"]), 120.0))
		vb.add_child(_stat_row(Game.t("rate"), 1.0 / float(w["cd"]), 4.2))
		var wid: String = id
		var btn: Button
		if Game.equipped == id:
			btn = UIKit.button(Game.t("equipped"), Vector2(200, 56), false, 22)
			btn.disabled = true
		elif Game.owned.has(id):
			btn = UIKit.button(Game.t("equip"), Vector2(200, 56), true, 22)
			btn.pressed.connect(func():
				Game.equip(wid)
				_reload_shop())
		else:
			btn = UIKit.button("%s  %d" % [Game.t("buy"), int(w["price"])], Vector2(200, 56), true, 22)
			btn.disabled = Game.coins < int(w["price"])
			btn.pressed.connect(func():
				Game.buy_weapon(wid)
				Game.sfx("coin")
				_reload_shop())
		vb.add_child(btn)
	shop_scroll_node = sc
	sc.scroll_horizontal = shop_scroll
	sc.get_h_scroll_bar().value_changed.connect(func(v): shop_scroll = int(v))


var shop_scroll_node: ScrollContainer


func _reload_shop() -> void:
	show_shop()


func _shop_upgrades(s: Control) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 150
	s.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	cc.add_child(vb)
	for k in ["vit", "pow", "agi"]:
		var p := UIKit.panel(UIKit.CARD)
		p.custom_minimum_size = Vector2(920, 0)
		vb.add_child(p)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 20)
		p.add_child(hb)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(info)
		info.add_child(UIKit.label(Game.t(k), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		info.add_child(UIKit.label(Game.t(k + "_d"), 19, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT))
		var lvl := int(Game.upgrades[k])
		info.add_child(UIKit.label("●".repeat(lvl) + "○".repeat(Game.UP_MAX - lvl), 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
		var btn: Button
		if lvl >= Game.UP_MAX:
			btn = UIKit.button(Game.t("max"), Vector2(220, 64), false, 24)
			btn.disabled = true
		else:
			var cost := Game.upgrade_cost(k)
			btn = UIKit.button("%s  %d" % [Game.t("buy"), cost], Vector2(220, 64), true, 24)
			btn.disabled = Game.coins < cost
			var key: String = k
			btn.pressed.connect(func():
				Game.buy_upgrade(key)
				Game.sfx("coin")
				show_shop())
		hb.add_child(btn)


# ------------------------------------------------------------ settings
func show_settings() -> void:
	_menu_fighters(false)
	reset_armed = false
	var s := _new_screen()
	_top_bar(s, Game.t("settings"), show_menu)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 80
	s.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	cc.add_child(vb)
	_setting_row(vb, Game.t("language"), "العربية" if Game.lang == "ar" else "English", func():
		Game.lang = "en" if Game.lang == "ar" else "ar"
		Game.save_game()
		show_settings())
	_setting_row(vb, Game.t("sound"), Game.t("on") if Game.sound_on else Game.t("off"), func():
		Game.sound_on = not Game.sound_on
		Game.save_game()
		show_settings())
	_setting_row(vb, Game.t("vibration"), Game.t("on") if Game.vibrate_on else Game.t("off"), func():
		Game.vibrate_on = not Game.vibrate_on
		Game.save_game()
		show_settings())
	var rb := UIKit.button(Game.t("reset_ok") if reset_armed else Game.t("reset"), Vector2(560, 64), false, 24)
	rb.pressed.connect(func():
		if reset_armed:
			Game.reset_progress()
			show_settings()
		else:
			reset_armed = true
			rb.text = Game.t("reset_ok"))
	vb.add_child(rb)


func _setting_row(parent: Control, title: String, value: String, cb: Callable) -> void:
	var p := UIKit.panel(UIKit.CARD)
	p.custom_minimum_size = Vector2(560, 0)
	parent.add_child(p)
	var hb := HBoxContainer.new()
	p.add_child(hb)
	var l := UIKit.label(title, 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(l)
	var b := UIKit.button(value, Vector2(200, 56), true, 24)
	b.pressed.connect(cb)
	hb.add_child(b)


# ------------------------------------------------------------ battle flow
func start_battle(n: int) -> void:
	Game.current_level = n
	_clear_menu_scene()
	if current:
		current.queue_free()
		current = null
	battle = Battle.new()
	battle.name = "Battle"
	battle.level_n = n
	battle.exit.connect(_on_battle_exit)
	add_child(battle)


func _on_battle_exit(action: String, data: Dictionary) -> void:
	if battle:
		battle.name = "BattleOld"
		battle.queue_free()
		battle = null
	get_tree().paused = false
	match action:
		"retry":
			start_battle(Game.current_level)
		"menu":
			show_menu()
		"win":
			Game.complete_level(int(data["level"]), int(data["stars"]), int(data["coins"]))
			show_result(true, data)
		"lose":
			Game.add_coins(int(float(data["coins"]) * 0.5))
			Game.save_game()
			show_result(false, data)


func show_result(win: bool, data: Dictionary) -> void:
	_build_menu_scene()
	var s := _new_screen()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(cc)
	var p := UIKit.panel(UIKit.PANEL, Color(1, 0.8, 0.3, 0.45) if win else Color(1, 0.3, 0.3, 0.45))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(520, 0)
	p.add_child(vb)
	vb.add_child(UIKit.label(Game.t("victory") if win else Game.t("defeat"), 64, UIKit.GOLD if win else Color(1, 0.4, 0.4)))
	if win:
		var sc := int(data["stars"])
		vb.add_child(UIKit.label("★".repeat(sc) + "☆".repeat(3 - sc), 60, UIKit.GOLD))
	vb.add_child(UIKit.label("%s: %d" % [Game.t("kills"), int(data["kills"])], 28))
	var reward := int(data["coins"]) if win else int(float(data["coins"]) * 0.5)
	vb.add_child(UIKit.label("%s: +%d" % [Game.t("reward"), reward], 28, UIKit.GOLD))
	var lvl := int(data["level"])
	if Net.active:
		var bm2 := UIKit.button(Game.t("menu"), Vector2(400, 66), true, 28)
		bm2.pressed.connect(func():
			Net.leave()
			show_menu())
		vb.add_child(bm2)
		return
	if win and lvl < Game.MAX_LEVEL:
		var bn := UIKit.button(Game.t("next"), Vector2(400, 66), true, 28)
		bn.pressed.connect(func(): start_battle(lvl + 1))
		vb.add_child(bn)
	var br := UIKit.button(Game.t("retry"), Vector2(400, 60), false, 26)
	br.pressed.connect(func(): start_battle(lvl))
	vb.add_child(br)
	var bm := UIKit.button(Game.t("menu"), Vector2(400, 60), false, 26)
	bm.pressed.connect(show_menu)
	vb.add_child(bm)


# ------------------------------------------------------------ arena setup (offline)
var setup_bots := 3
var setup_rounds := 3
var setup_map := -1


func show_arena_setup() -> void:
	_menu_fighters(false)
	var s := _new_screen()
	_top_bar(s, Game.t("arena"), show_menu)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 80
	s.add_child(cc)
	var p := UIKit.panel(Color(0.06, 0.07, 0.15, 0.94), Color(1, 0.35, 0.25, 0.7))
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(760, 0)
	p.add_child(vb)
	vb.add_child(_setup_row(Game.t("bots"), [1, 2, 3], setup_bots, func(v): setup_bots = v))
	vb.add_child(_setup_row(Game.t("first_to"), [3, 5], setup_rounds, func(v): setup_rounds = v))
	var mr := HBoxContainer.new()
	mr.alignment = BoxContainer.ALIGNMENT_CENTER
	mr.add_theme_constant_override("separation", 12)
	vb.add_child(mr)
	var ml := UIKit.label(Game.t("map_random") if setup_map < 0 else Game.t("map%d" % setup_map), 28)
	ml.custom_minimum_size = Vector2(300, 0)
	var bm := UIKit.button("<", Vector2(64, 54), false, 28)
	var bp := UIKit.button(">", Vector2(64, 54), false, 28)
	bm.pressed.connect(func():
		setup_map = setup_map - 1 if setup_map >= 0 else 5
		show_arena_setup())
	bp.pressed.connect(func():
		setup_map = setup_map + 1 if setup_map < 5 else -1
		show_arena_setup())
	mr.add_child(UIKit.label(Game.t("map"), 26, Color(1, 1, 1, 0.75)))
	mr.add_child(bm)
	mr.add_child(ml)
	mr.add_child(bp)
	vb.add_child(UIKit.label(Game.t("howto"), 19, Color(1, 1, 1, 0.6)))
	var bs := UIKit.button(Game.t("start"), Vector2(420, 76), true, 32)
	bs.pressed.connect(func(): start_arena(setup_map, setup_bots, setup_rounds))
	vb.add_child(bs)


func _setup_row(title: String, opts: Array, cur: int, setter: Callable) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	var tl := UIKit.label(title, 26, Color(1, 1, 1, 0.75))
	tl.custom_minimum_size = Vector2(220, 0)
	hb.add_child(tl)
	for o in opts:
		var v: int = o
		var b := UIKit.button(str(v), Vector2(110, 54), v == cur, 26)
		b.pressed.connect(func():
			setter.call(v)
			show_arena_setup())
		hb.add_child(b)
	return hb


# ------------------------------------------------------------ arena flow
func start_arena(map_start := 0, bots := 3, rounds := 3) -> void:
	_clear_menu_scene()
	if current:
		current.queue_free()
		current = null
	arena = Arena.new()
	arena.name = "Arena"
	arena.map_start = map_start
	arena.bots_n = bots
	arena.win_target = rounds
	arena.exit.connect(_on_arena_exit)
	add_child(arena)


func _on_arena_exit(action: String, data: Dictionary) -> void:
	if arena:
		arena.name = "ArenaOld"
		arena.queue_free()
		arena = null
	get_tree().paused = false
	if action == "arena_end":
		show_arena_result(data)
	else:
		show_menu()


func show_arena_result(data: Dictionary) -> void:
	_build_menu_scene()
	_menu_fighters(false)
	var s := _new_screen()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(cc)
	var wc: Color = Arena.COLORS[int(data["widx"])]
	var p := UIKit.panel(UIKit.PANEL, wc)
	cc.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(560, 0)
	p.add_child(vb)
	vb.add_child(UIKit.label(Game.t("winner"), 40, Color(1, 1, 1, 0.8)))
	vb.add_child(UIKit.label(str(data["winner"]), 64, wc))
	var names: Array = data["names"]
	var wins: Array = data["wins"]
	var cols: Array = data["cols"]
	for i in names.size():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(26, 26)
		var dc: Color = Arena.COLORS[int(cols[i])]
		dot.draw.connect(func(): dot.draw_circle(Vector2(13, 13), 12, dc))
		row.add_child(dot)
		row.add_child(UIKit.label("%s   %s" % [str(names[i]), "●".repeat(int(wins[i]))], 26))
		vb.add_child(row)
	if not Net.active:
		var br := UIKit.button(Game.t("rematch"), Vector2(400, 66), true, 28)
		br.pressed.connect(show_arena_setup)
		vb.add_child(br)
	var bm := UIKit.button(Game.t("menu"), Vector2(400, 60), false, 26)
	bm.pressed.connect(func():
		Net.leave()
		show_menu())
	vb.add_child(bm)


# ------------------------------------------------------------ LAN
var lan_list: VBoxContainer
var lan_ip_edit: LineEdit
var lan_msg: Label
var lan_level := 1
var ci_started := false


func _on_net_start(mode: String, param: int) -> void:
	if mode == "arena":
		start_arena(param)
	else:
		start_battle(maxi(1, param))


func _on_join_failed() -> void:
	if lan_msg != null and is_instance_valid(lan_msg):
		lan_msg.text = Game.t("failed")


func _card_box(accent: Color, a: float, pressed := false) -> StyleBoxFlat:
	var sb := UIKit.box(Color(0.06, 0.07, 0.15, 0.94) if not pressed else Color(0.1, 0.11, 0.22, 0.98), Color(accent.r, accent.g, accent.b, a), 22, 3)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	return sb


func _draw_icon(ic: Control, icon: String, accent: Color) -> void:
	if icon == "host":
		ic.draw_circle(Vector2(50, 84), 7, accent)
		for i in 3:
			ic.draw_arc(Vector2(50, 84), 18.0 + float(i) * 16.0, -2.3, -0.84, 18, Color(accent.r, accent.g, accent.b, 1.0 - float(i) * 0.25), 5.0, true)
	else:
		ic.draw_arc(Vector2(42, 42), 26.0, 0.0, TAU, 32, accent, 6.0, true)
		ic.draw_line(Vector2(62, 62), Vector2(90, 90), accent, 9.0, true)


func _lan_card(title: String, sub: String, icon: String, accent: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(460, 290)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _card_box(accent, 0.7))
	b.add_theme_stylebox_override("hover", _card_box(accent, 1.0))
	b.add_theme_stylebox_override("pressed", _card_box(accent, 1.0, true))
	var ic := Control.new()
	ic.position = Vector2(180, 26)
	ic.size = Vector2(100, 100)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func(): _draw_icon(ic, icon, accent))
	b.add_child(ic)
	var tl := UIKit.label(title, 38)
	tl.position = Vector2(0, 140)
	tl.size = Vector2(460, 56)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tl)
	var sl := UIKit.label(sub, 21, Color(1, 1, 1, 0.65))
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.position = Vector2(34, 202)
	sl.size = Vector2(392, 70)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sl)
	return b


func show_lan() -> void:
	_menu_fighters(false)
	Net.leave()
	radar = null
	var s := _new_screen()
	_top_bar(s, Game.t("lan"), show_menu)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 70
	s.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	cc.add_child(vb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	vb.add_child(row)
	var ch := _lan_card(Game.t("host"), Game.t("host_sub"), "host", Color(0.35, 0.75, 1.0))
	ch.pressed.connect(func():
		if Net.host_room():
			show_lobby()
		else:
			show_lan())
	row.add_child(ch)
	var cj := _lan_card(Game.t("join"), Game.t("join_sub"), "join", Color(1.0, 0.85, 0.2))
	cj.pressed.connect(show_join)
	row.add_child(cj)
	var nr := HBoxContainer.new()
	nr.alignment = BoxContainer.ALIGNMENT_CENTER
	nr.add_theme_constant_override("separation", 14)
	vb.add_child(nr)
	nr.add_child(UIKit.label(Game.t("your_name"), 24, Color(1, 1, 1, 0.8)))
	var ne := LineEdit.new()
	ne.text = Game.pname
	ne.max_length = 14
	ne.custom_minimum_size = Vector2(300, 56)
	ne.add_theme_font_size_override("font_size", 26)
	ne.text_changed.connect(func(t: String):
		Game.pname = t.strip_edges() if t.strip_edges() != "" else "Player")
	nr.add_child(ne)
	vb.add_child(UIKit.label(Game.t("lan_hint"), 20, Color(1, 1, 1, 0.6)))


func show_join() -> void:
	_menu_fighters(false)
	Net.start_discovery()
	var s := _new_screen()
	_top_bar(s, Game.t("join"), func():
		Net.stop_discovery()
		radar = null
		show_lan())
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 90
	s.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(820, 0)
	cc.add_child(vb)
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 16)
	vb.add_child(hdr)
	radar = Control.new()
	radar.custom_minimum_size = Vector2(56, 56)
	radar.draw.connect(func():
		var c := Vector2(28, 28)
		radar.draw_arc(c, 24.0, 0.0, TAU, 28, Color(1, 0.85, 0.2, 0.35), 2.0, true)
		radar.draw_arc(c, 13.0, 0.0, TAU, 20, Color(1, 0.85, 0.2, 0.35), 2.0, true)
		radar.draw_line(c, c + Vector2.from_angle(radar_a) * 24.0, Color(1, 0.85, 0.2, 0.95), 3.0, true)
		radar.draw_circle(c, 3.0, Color(1, 0.85, 0.2)))
	hdr.add_child(radar)
	var rl := UIKit.label(Game.t("rooms"), 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	rl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr.add_child(rl)
	lan_list = VBoxContainer.new()
	lan_list.add_theme_constant_override("separation", 10)
	vb.add_child(lan_list)
	vb.add_child(UIKit.label(Game.t("ip_hint"), 22, Color(1, 1, 1, 0.7)))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	lan_ip_edit = LineEdit.new()
	lan_ip_edit.placeholder_text = "192.168.1.5"
	lan_ip_edit.custom_minimum_size = Vector2(500, 62)
	lan_ip_edit.add_theme_font_size_override("font_size", 28)
	hb.add_child(lan_ip_edit)
	var bc := UIKit.button(Game.t("connect"), Vector2(250, 62), true, 26)
	bc.pressed.connect(func(): _join_ip(lan_ip_edit.text))
	hb.add_child(bc)
	lan_msg = UIKit.label("", 22, Color(1, 0.5, 0.5))
	vb.add_child(lan_msg)
	if not Net.rooms_changed.is_connected(_refresh_rooms):
		Net.rooms_changed.connect(_refresh_rooms)
	_refresh_rooms()


func _refresh_rooms() -> void:
	if lan_list == null or not is_instance_valid(lan_list):
		return
	for ch in lan_list.get_children():
		ch.queue_free()
	if Net.rooms.is_empty():
		lan_list.add_child(UIKit.label(Game.t("no_rooms"), 24, Color(1, 1, 1, 0.6)))
		return
	for ip in Net.rooms.keys():
		var r: Dictionary = Net.rooms[ip]
		var card := UIKit.panel(Color(0.06, 0.07, 0.15, 0.94), Color(0.35, 0.75, 1.0, 0.7))
		lan_list.add_child(card)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 18)
		card.add_child(hb)
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(40, 40)
		dot.draw.connect(func():
			dot.draw_circle(Vector2(20, 20), 16, Color(0.35, 0.75, 1.0))
			dot.draw_circle(Vector2(20, 20), 6, Color(1, 1, 1, 0.9)))
		hb.add_child(dot)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label(str(r["name"]), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		info.add_child(UIKit.label(str(ip), 18, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_LEFT))
		hb.add_child(info)
		var cnt := int(r["count"])
		var pd := Control.new()
		pd.custom_minimum_size = Vector2(120, 40)
		pd.draw.connect(func():
			for k in 4:
				pd.draw_circle(Vector2(14.0 + float(k) * 28.0, 20), 9, Arena.COLORS[k] if k < cnt else Color(1, 1, 1, 0.15)))
		hb.add_child(pd)
		var bj := UIKit.button(Game.t("join"), Vector2(180, 54), true, 22)
		var ipc: String = ip
		bj.pressed.connect(func(): _join_ip(ipc))
		hb.add_child(bj)


func _join_ip(ip: String) -> void:
	if ip.strip_edges() == "":
		return
	if lan_msg != null and is_instance_valid(lan_msg):
		lan_msg.text = "..."
	if Net.join_room(ip):
		Net.stop_discovery()
		radar = null
		show_lobby()
	elif lan_msg != null and is_instance_valid(lan_msg):
		lan_msg.text = Game.t("failed")


func show_lobby() -> void:
	_menu_fighters(false)
	radar = null
	var s := _new_screen()
	_top_bar(s, Game.t("lan"), func():
		Net.leave()
		show_lan())
	lobby_body = Control.new()
	lobby_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_body.offset_top = 90
	s.add_child(lobby_body)
	if not Net.players_changed.is_connected(_fill_lobby):
		Net.players_changed.connect(_fill_lobby)
	_fill_lobby()


func _top_unlocked() -> int:
	var top := 1
	for n in range(1, Game.MAX_LEVEL + 1):
		if Game.is_unlocked(n):
			top = n
	return top


func _fill_lobby() -> void:
	if lobby_body == null or not is_instance_valid(lobby_body):
		return
	for ch in lobby_body.get_children():
		ch.queue_free()
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_body.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	cc.add_child(vb)
	# header chips
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 14)
	vb.add_child(chips)
	var ip_chip := UIKit.panel(Color(0.06, 0.07, 0.15, 0.94), Color(1, 0.85, 0.2, 0.6))
	var host_ip := Net.local_ip() if Net.is_host else ""
	ip_chip.add_child(UIKit.label(("%s: %s" % [Game.t("your_ip"), host_ip]) if Net.is_host else Game.t("lan_hint"), 22, UIKit.GOLD))
	chips.add_child(ip_chip)
	var mode_chip := UIKit.panel(Color(0.06, 0.07, 0.15, 0.94), Color(0.35, 0.75, 1.0, 0.6))
	mode_chip.add_child(UIKit.label("%s: %s" % [Game.t("mode"), Game.t("pvp") if Net.mode == "arena" else Game.t("coop")], 22, Color(0.7, 0.9, 1.0)))
	chips.add_child(mode_chip)
	# slots
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 16)
	vb.add_child(slots)
	var ids: Array = Net.players.keys()
	ids.sort()
	for i in 4:
		var col: Color = Arena.COLORS[i]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(250, 280)
		card.add_theme_stylebox_override("panel", _card_box(col, 0.85 if i < ids.size() else 0.25))
		slots.add_child(card)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 6)
		card.add_child(inner)
		var prev := Control.new()
		prev.custom_minimum_size = Vector2(218, 170)
		prev.clip_contents = true
		inner.add_child(prev)
		var floor_line := ColorRect.new()
		floor_line.color = Color(1, 1, 1, 0.25)
		floor_line.position = Vector2(20, 150)
		floor_line.size = Vector2(178, 2)
		prev.add_child(floor_line)
		if i < ids.size():
			var info: Dictionary = Net.players[ids[i]]
			var st := Stickman.new()
			st.thin = true
			st.col = col
			st.weapon = Game.WEAPONS["fists"]
			st.position = Vector2(109, 150)
			st.s = 1.25
			prev.add_child(st)
			inner.add_child(UIKit.label(str(info["name"]), 26, col))
			var tag := Game.t("host_tag") if ids[i] == 1 else "Player %d" % (i + 1)
			if ids[i] == multiplayer.get_unique_id():
				tag = Game.t("you")
			inner.add_child(UIKit.label(tag, 18, Color(1, 1, 1, 0.6)))
		else:
			var q := UIKit.label("?", 80, Color(1, 1, 1, 0.12))
			q.position = Vector2(0, 30)
			q.size = Vector2(218, 100)
			prev.add_child(q)
			inner.add_child(UIKit.label(Game.t("slot_wait"), 20, Color(1, 1, 1, 0.45)))
	# host controls
	if Net.is_host:
		var seg := HBoxContainer.new()
		seg.alignment = BoxContainer.ALIGNMENT_CENTER
		seg.add_theme_constant_override("separation", 12)
		vb.add_child(seg)
		var bc := UIKit.button(Game.t("coop"), Vector2(220, 56), Net.mode == "coop", 22)
		bc.pressed.connect(func(): Net.set_cfg("coop", clampi(lan_level, 1, _top_unlocked())))
		seg.add_child(bc)
		var ba := UIKit.button(Game.t("pvp"), Vector2(220, 56), Net.mode == "arena", 22)
		ba.pressed.connect(func(): Net.set_cfg("arena", 0))
		seg.add_child(ba)
		var sel := HBoxContainer.new()
		sel.alignment = BoxContainer.ALIGNMENT_CENTER
		sel.add_theme_constant_override("separation", 12)
		vb.add_child(sel)
		var lbl_txt := ""
		if Net.mode == "arena":
			lbl_txt = "%s: %s" % [Game.t("map"), Game.t("map%d" % Net.param)]
		else:
			lbl_txt = "%s %d" % [Game.t("lvl"), maxi(1, Net.param)]
		var lv := UIKit.label(lbl_txt, 26)
		lv.custom_minimum_size = Vector2(300, 0)
		var bm := UIKit.button("<", Vector2(64, 54), false, 28)
		bm.pressed.connect(func(): _lan_step(-1))
		var bp := UIKit.button(">", Vector2(64, 54), false, 28)
		bp.pressed.connect(func(): _lan_step(1))
		sel.add_child(bm)
		sel.add_child(lv)
		sel.add_child(bp)
		var bs := UIKit.button(Game.t("start"), Vector2(420, 70), true, 32)
		bs.disabled = Net.mode == "arena" and Net.players.size() < 2
		bs.pressed.connect(func(): Net.start_match())
		vb.add_child(bs)
		if bs.disabled:
			vb.add_child(UIKit.label(Game.t("need2"), 20, Color(1, 0.6, 0.5)))
	else:
		vb.add_child(UIKit.label(Game.t("waiting"), 26, Color(1, 1, 1, 0.8)))


func _lan_step(d: int) -> void:
	if Net.mode == "arena":
		Net.set_cfg("arena", posmod(Net.param + d, 6))
	else:
		lan_level = clampi(maxi(1, Net.param) + d, 1, _top_unlocked())
		Net.set_cfg("coop", lan_level)


# ------------------------------------------------------------ CI helpers (used by the Actions LAN test)
func _ci_lan_host() -> void:
	Game.autoplay = true
	Game.sound_on = false
	Game.owned = ["fists", "sword"]
	Game.equipped = "sword"
	Game.pname = "HostBot"
	Net.host_room()
	if "--arena" in OS.get_cmdline_user_args():
		Net.set_cfg("arena", 0)
	Net.players_changed.connect(func():
		if Net.players.size() >= 2 and not ci_started:
			ci_started = true
			get_tree().create_timer(1.0).timeout.connect(func(): Net.start_match()))


func _ci_lan_join(ip: String) -> void:
	Game.autoplay = true
	Game.sound_on = false
	Game.owned = ["fists", "katana"]
	Game.equipped = "katana"
	Game.pname = "ClientBot"
	Net.join_room(ip)
