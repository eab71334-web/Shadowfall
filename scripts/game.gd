extends Node
# Autoload "Game": save data, weapons, levels, translations, sound effects.

signal coins_changed

const SAVE_PATH := "user://shadowfall_save.json"
const MAX_LEVEL := 12
const UP_MAX := 8

var lang := "ar"
var sound_on := true
var vibrate_on := true
var coins := 0
var owned: Array = ["fists"]
var equipped := "fists"
var upgrades := {"vit": 0, "pow": 0, "agi": 0}
var stars := {}
var current_level := 1
var autoplay := false
var pname := ""
var font: Font
var ui_theme: Theme

var _streams := {}
var _players: Array = []
var _pi := 0

var WEAPON_ORDER := ["fists", "dagger", "sword", "spear", "katana", "axe", "hammer"]

var WEAPONS := {
	"fists": {"en": "Bare Fists", "ar": "القبضة", "kind": "fist", "dmg": 9, "range": 50, "cd": 0.30, "price": 0, "kb": 120, "len": 0},
	"dagger": {"en": "Shadow Dagger", "ar": "خنجر الظل", "kind": "dagger", "dmg": 13, "range": 62, "cd": 0.24, "price": 150, "kb": 90, "len": 22},
	"sword": {"en": "Iron Sword", "ar": "سيف الحديد", "kind": "sword", "dmg": 20, "range": 84, "cd": 0.36, "price": 450, "kb": 160, "len": 46},
	"spear": {"en": "War Spear", "ar": "رمح الحرب", "kind": "spear", "dmg": 24, "range": 116, "cd": 0.48, "price": 900, "kb": 140, "len": 70},
	"katana": {"en": "Ghost Katana", "ar": "كاتانا الشبح", "kind": "katana", "dmg": 30, "range": 96, "cd": 0.30, "price": 1600, "kb": 180, "len": 54},
	"axe": {"en": "Blood Axe", "ar": "فأس الدم", "kind": "axe", "dmg": 46, "range": 88, "cd": 0.62, "price": 2400, "kb": 260, "len": 50},
	"hammer": {"en": "Titan Hammer", "ar": "مطرقة العملاق", "kind": "hammer", "dmg": 70, "range": 92, "cd": 0.85, "price": 3600, "kb": 420, "len": 48},
}

const LEVEL_NAMES := [
	["Dust Plains", "سهول الغبار"], ["Fallen Gate", "البوابة الساقطة"], ["Ashen Road", "طريق الرماد"],
	["Hollow Fort", "الحصن المهجور"], ["The Warlord", "سيد الحرب"], ["Crimson Dunes", "كثبان قرمزية"],
	["Broken Bridge", "الجسر المكسور"], ["Iron Valley", "وادي الحديد"], ["Night Siege", "حصار الليل"],
	["Black Citadel", "القلعة السوداء"], ["Last Stand", "الصمود الأخير"], ["Shadowfall", "سقوط الظلال"],
]

const TR := {
	"play": ["PLAY", "ابدأ اللعب"], "levels": ["LEVELS", "المراحل"], "shop": ["SHOP", "المتجر"],
	"settings": ["SETTINGS", "الإعدادات"], "back": ["BACK", "رجوع"], "weapons": ["WEAPONS", "الأسلحة"],
	"upgrades": ["UPGRADES", "التطويرات"], "buy": ["BUY", "شراء"], "equip": ["EQUIP", "تجهيز"],
	"equipped": ["EQUIPPED", "مجهّز"], "level": ["LEVEL", "المرحلة"], "wave": ["WAVE", "الموجة"],
	"victory": ["VICTORY", "النصر"], "defeat": ["DEFEAT", "هزيمة"], "retry": ["RETRY", "إعادة"],
	"next": ["NEXT", "التالي"], "menu": ["MENU", "القائمة"], "resume": ["RESUME", "استمرار"],
	"paused": ["PAUSED", "إيقاف مؤقت"], "sound": ["Sound", "الصوت"], "vibration": ["Vibration", "الاهتزاز"],
	"language": ["Language", "اللغة"], "on": ["ON", "تشغيل"], "off": ["OFF", "إيقاف"],
	"vit": ["Vitality", "الحيوية"], "pow": ["Power", "القوة"], "agi": ["Agility", "الرشاقة"],
	"vit_d": ["+15% max health per level", "+15٪ صحة لكل مستوى"],
	"pow_d": ["+12% damage per level", "+12٪ ضرر لكل مستوى"],
	"agi_d": ["+5% speed per level", "+5٪ سرعة لكل مستوى"],
	"max": ["MAX", "الحد الأقصى"], "boss": ["BOSS", "زعيم"], "locked": ["LOCKED", "مقفل"],
	"dmg": ["Damage", "الضرر"], "range": ["Range", "المدى"], "rate": ["Speed", "السرعة"],
	"kills": ["Kills", "القتلى"], "reward": ["Coins", "العملات"],
	"wave_clear": ["WAVE CLEARED", "تم صد الموجة"],
	"tagline": ["Rise from the shadows", "انهض من بين الظلال"],
	"lan": ["LAN PLAY", "لعب جماعي"], "host": ["HOST ROOM", "إنشاء غرفة"], "join": ["JOIN ROOM", "الانضمام لغرفة"],
	"rooms": ["Rooms on your Wi-Fi", "الغرف على شبكتك"], "no_rooms": ["Searching for rooms...", "جاري البحث عن غرف..."],
	"ip_hint": ["Or type the host IP", "أو اكتب عنوان IP للمضيف"], "connect": ["CONNECT", "اتصال"], "start": ["START", "ابدأ"],
	"waiting": ["Waiting for the host to start...", "بانتظار المضيف ليبدأ..."], "players": ["Players", "اللاعبون"],
	"lan_hint": ["Both devices must be on the same Wi-Fi", "الجهازان لازم يكونان على نفس الواي فاي"],
	"your_ip": ["Your IP", "عنوان IP الخاص بك"], "failed": ["Could not connect", "تعذر الاتصال"],
	"lvl": ["Level", "المرحلة"], "lost_conn": ["Connection lost", "انقطع الاتصال"],
	"hits": ["HITS", "ضربة"], "finish": ["FINISH!", "القاضية!"],
	"reset": ["Reset progress", "مسح التقدم"], "reset_ok": ["Tap again to confirm", "اضغط مرة أخرى للتأكيد"],
}


func _ready() -> void:
	load_game()
	if pname == "":
		pname = "Player%d" % (randi() % 900 + 100)
	var f = load("res://assets/fonts/ui.ttf")
	font = f if f != null else ThemeDB.fallback_font
	ui_theme = Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 26
	_setup_sound()


func t(key: String) -> String:
	if not TR.has(key):
		return key
	return TR[key][1 if lang == "ar" else 0]


func wname(id: String) -> String:
	return WEAPONS[id]["ar" if lang == "ar" else "en"]


func level_name(n: int) -> String:
	return LEVEL_NAMES[n - 1][1 if lang == "ar" else 0]


func is_boss_level(n: int) -> bool:
	return n == 5 or n == 10 or n == 12


func world_of(n: int) -> int:
	return clampi(int((n - 1) / 4.0), 0, 2)


func is_unlocked(n: int) -> bool:
	return n == 1 or stars.has(str(n - 1))


func star_count(n: int) -> int:
	return int(stars.get(str(n), 0))


func build_waves(n: int) -> Array:
	var waves: Array = []
	var wcount := 3 + int(n / 3.0)
	for w in wcount:
		var wave: Array = []
		var c := 3 + int(n / 2.0) + w
		for i in c:
			var k := "grunt"
			if n >= 2 and i % 3 == 2:
				k = "runner"
			if n >= 4 and w >= 1 and i % 5 == 4:
				k = "brute"
			wave.append(k)
		waves.append(wave)
	if is_boss_level(n):
		waves[waves.size() - 1].append("boss")
	return waves


func stats() -> Dictionary:
	return {
		"hp": 100.0 * (1.0 + 0.15 * float(upgrades["vit"])),
		"dmg": 1.0 + 0.12 * float(upgrades["pow"]),
		"spd": 1.0 + 0.05 * float(upgrades["agi"]),
	}


func upgrade_cost(k: String) -> int:
	return int(120.0 * pow(1.6, float(upgrades[k])))


func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit()


func buy_weapon(id: String) -> bool:
	var price := int(WEAPONS[id]["price"])
	if owned.has(id) or coins < price:
		return false
	coins -= price
	owned.append(id)
	equipped = id
	save_game()
	coins_changed.emit()
	return true


func equip(id: String) -> void:
	if owned.has(id):
		equipped = id
		save_game()


func buy_upgrade(k: String) -> bool:
	if int(upgrades[k]) >= UP_MAX:
		return false
	var cost := upgrade_cost(k)
	if coins < cost:
		return false
	coins -= cost
	upgrades[k] = int(upgrades[k]) + 1
	save_game()
	coins_changed.emit()
	return true


func complete_level(n: int, st: int, reward: int) -> void:
	stars[str(n)] = maxi(star_count(n), st)
	add_coins(reward)
	save_game()


func reset_progress() -> void:
	coins = 0
	owned = ["fists"]
	equipped = "fists"
	upgrades = {"vit": 0, "pow": 0, "agi": 0}
	stars = {}
	save_game()
	coins_changed.emit()


func save_game() -> void:
	var d := {
		"coins": coins, "owned": owned, "equipped": equipped, "upgrades": upgrades,
		"stars": stars, "lang": lang, "sound": sound_on, "vib": vibrate_on,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = int(data.get("coins", 0))
	owned = data.get("owned", ["fists"])
	equipped = str(data.get("equipped", "fists"))
	lang = str(data.get("lang", "ar"))
	sound_on = bool(data.get("sound", true))
	vibrate_on = bool(data.get("vib", true))
	var up = data.get("upgrades", {})
	for k in upgrades.keys():
		upgrades[k] = int(up.get(k, 0))
	var st = data.get("stars", {})
	stars = {}
	for k in st.keys():
		stars[str(k)] = int(st[k])


# ---------------------------------------------------------------- sound
func _setup_sound() -> void:
	_streams["hit"] = _make_wav(0.14, "hit")
	_streams["swing"] = _make_wav(0.16, "swing")
	_streams["die"] = _make_wav(0.30, "die")
	_streams["coin"] = _make_wav(0.18, "coin")
	_streams["ui"] = _make_wav(0.07, "ui")
	_streams["boom"] = _make_wav(0.5, "boom")
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _make_wav(dur: float, kind: String) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var tt := float(i) / float(n)
		var env := pow(1.0 - tt, 2.0)
		var s := 0.0
		match kind:
			"hit":
				s = (rng.randf() * 2.0 - 1.0) * env * 0.7 + sin(float(i) * 0.06 * (1.0 - tt)) * env * 0.6
			"swing":
				lp = lp * 0.85 + (rng.randf() * 2.0 - 1.0) * 0.15
				s = lp * 3.0 * sin(tt * PI)
			"die":
				s = sin(float(i) * 0.03 * (1.0 - tt * 0.7)) * env * 0.8 + (rng.randf() * 2.0 - 1.0) * env * 0.25
			"coin":
				s = (sin(float(i) * 0.30) * 0.5 + sin(float(i) * 0.45) * 0.3) * env
			"boom":
				s = sin(float(i) * 0.012 * (1.0 - tt * 0.8)) * env + (rng.randf() * 2.0 - 1.0) * env * 0.35
			"ui":
				s = sin(float(i) * 0.25) * env * 0.5
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func sfx(sound: String, pitch := 1.0) -> void:
	if not sound_on or not _streams.has(sound) or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_pi]
	_pi = (_pi + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = -5.0
	p.play()


func vibrate(ms: int) -> void:
	if vibrate_on:
		Input.vibrate_handheld(ms)
