extends Node

var ui_layer: CanvasLayer
var ui_root: Control
var current: Control
var menu_root: Node2D
var menu_backdrop: Backdrop
var battle: Battle
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
	if "autoplay" in OS.get_cmdline_user_args():
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
	duel_a.s = 1.3
	duel_a.facing = 1
	duel_a.position = Vector2(vw * 0.40, gy)
	duel_b = Stickman.new()
	duel_b.weapon = Game.WEAPONS["sword"]
	duel_b.s = 1.3
	duel_b.facing = -1
	duel_b.position = Vector2(vw * 0.60, gy)
	menu_root.add_child(duel_a)
	menu_root.add_child(duel_b)


func _process(delta: float) -> void:
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
	_build_menu_scene()
	var s := _new_screen()
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 40
	vb.add_theme_constant_override("separation", 6)
	s.add_child(vb)
	var title := UIKit.label("SHADOWFALL", 104)
	title.add_theme_constant_override("outline_size", 10)
	vb.add_child(title)
	vb.add_child(UIKit.label("سقوط الظلال", 40, Color(1, 0.9, 0.8)))
	vb.add_child(UIKit.label(Game.t("tagline"), 24, Color(1, 1, 1, 0.75)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	vb.add_child(sp)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 18)
	vb.add_child(hb)
	var bp := UIKit.button(Game.t("play"), Vector2(320, 84), true, 36)
	bp.pressed.connect(show_levels)
	hb.add_child(bp)
	var bs := UIKit.button(Game.t("shop"), Vector2(230, 84), false, 30)
	bs.pressed.connect(show_shop)
	hb.add_child(bs)
	var bt := UIKit.button(Game.t("settings"), Vector2(230, 84), false, 30)
	bt.pressed.connect(show_settings)
	hb.add_child(bt)
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
	battle.level_n = n
	battle.exit.connect(_on_battle_exit)
	add_child(battle)


func _on_battle_exit(action: String, data: Dictionary) -> void:
	if battle:
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
