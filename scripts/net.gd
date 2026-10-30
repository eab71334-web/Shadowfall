extends Node
# Autoload "Net": LAN co-op over ENet. One device hosts a room, others join.
# Discovery: host broadcasts its room over UDP, joiners listen. Manual IP also works.

signal rooms_changed
signal players_changed
signal join_failed
signal disconnected
signal player_left(id: int)
signal battle_start(level: int)

const PORT := 47778
const DISC_PORT := 47777
const MAGIC := "SHADOWFALL1"

var active := false
var is_host := false
var room_name := ""
var players := {}   # peer_id -> {"name","weapon","hp","dmg","spd"}
var rooms := {}     # ip -> {"name","count","t"}

var _peer: ENetMultiplayerPeer
var _tx: PacketPeerUDP
var _rx: PacketPeerUDP
var _bt := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)


func my_info() -> Dictionary:
	var st: Dictionary = Game.stats()
	return {"name": Game.pname, "weapon": Game.equipped, "hp": float(st["hp"]), "dmg": float(st["dmg"]), "spd": float(st["spd"])}


func local_ip() -> String:
	for a in IP.get_local_addresses():
		var s: String = a
		if s.begins_with("192.168.") or s.begins_with("10."):
			return s
		if s.begins_with("172."):
			var parts := s.split(".")
			if parts.size() > 1 and int(parts[1]) >= 16 and int(parts[1]) <= 31:
				return s
	return "?"


# ------------------------------------------------------------ host
func host_room() -> bool:
	leave()
	_peer = ENetMultiplayerPeer.new()
	if _peer.create_server(PORT, 3) != OK:
		_peer = null
		return false
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = true
	room_name = Game.pname
	players = {1: my_info()}
	_tx = PacketPeerUDP.new()
	_tx.set_broadcast_enabled(true)
	players_changed.emit()
	return true


func _broadcast() -> void:
	var msg := (MAGIC + "|" + room_name + "|" + str(players.size())).to_utf8_buffer()
	var targets: Array = ["255.255.255.255"]
	for a in IP.get_local_addresses():
		var s: String = a
		if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			var p := s.split(".")
			if p.size() == 4:
				targets.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	for t in targets:
		_tx.set_dest_address(t, DISC_PORT)
		_tx.put_packet(msg)


# ------------------------------------------------------------ join
func start_discovery() -> void:
	stop_discovery()
	rooms = {}
	_rx = PacketPeerUDP.new()
	if _rx.bind(DISC_PORT, "*") != OK:
		_rx = null


func stop_discovery() -> void:
	if _rx:
		_rx.close()
		_rx = null


func join_room(ip: String) -> bool:
	leave()
	_peer = ENetMultiplayerPeer.new()
	if _peer.create_client(ip.strip_edges(), PORT) != OK:
		_peer = null
		return false
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = false
	return true


func leave() -> void:
	stop_discovery()
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	_tx = null
	active = false
	is_host = false
	players = {}


func _process(delta: float) -> void:
	if is_host and _tx:
		_bt -= delta
		if _bt <= 0.0:
			_bt = 1.0
			_broadcast()
	if _rx:
		var changed := false
		while _rx.get_available_packet_count() > 0:
			var pkt := _rx.get_packet().get_string_from_utf8()
			var ip := _rx.get_packet_ip()
			var parts := pkt.split("|")
			if parts.size() >= 3 and parts[0] == MAGIC:
				rooms[ip] = {"name": parts[1], "count": int(parts[2]), "t": Time.get_ticks_msec()}
				changed = true
		var now := Time.get_ticks_msec()
		for ip in rooms.keys():
			if now - int(rooms[ip]["t"]) > 4000:
				rooms.erase(ip)
				changed = true
		if changed:
			rooms_changed.emit()


# ------------------------------------------------------------ connection events
func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if is_host:
		players.erase(id)
		_sync_players()
		player_left.emit(id)


func _on_connected() -> void:
	rpc_id(1, "_sv_hello", my_info())


func _on_failed() -> void:
	leave()
	join_failed.emit()


func _on_server_lost() -> void:
	leave()
	disconnected.emit()


@rpc("any_peer", "reliable")
func _sv_hello(info: Dictionary) -> void:
	if not is_host:
		return
	players[multiplayer.get_remote_sender_id()] = info
	_sync_players()


func _sync_players() -> void:
	rpc("_cl_players", players)
	players_changed.emit()


@rpc("authority", "reliable")
func _cl_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()


func start_battle(level: int) -> void:
	if not is_host:
		return
	stop_discovery()
	_tx = null
	rpc("_cl_start", level, players)
	battle_start.emit(level)


@rpc("authority", "reliable")
func _cl_start(level: int, p: Dictionary) -> void:
	players = p
	battle_start.emit(level)
