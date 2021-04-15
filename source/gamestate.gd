extends Node

# Default game port. Can be any number between 1024 and 49151.
const DEFAULT_PORT = 42069

# Max number of players.
const MAX_PEERS = 32

# Name for my player.
var player_name = "The Nameless One"
var player_color = Color(1, 1, 1)

# Names for remote players in id:name format.
var colors = {}
var players = {}
var players_ready = []

# Signals to let lobby GUI know what's going on.
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)

# Callback from SceneTree.
func _player_connected(id):
	# Registration of a client beings here, tell the connected player that we are here.
	rpc_id(id, "register_player", player_name, player_color)


# Callback from SceneTree.
func _player_disconnected(id):
	if has_node("/root/game"): # Game is in progress.
		if get_tree().is_network_server():
			emit_signal("game_error", "Player " + players[id] + " disconnected")
			end_game()
	else: # Game is not in progress.
		# Unregister this player.
		unregister_player(id)


# Callback from SceneTree, only for clients (not server).
func _connected_ok():
	# We just connected to a server
	emit_signal("connection_succeeded")


# Callback from SceneTree, only for clients (not server).
func _server_disconnected():
	emit_signal("game_error", "Server disconnected")
	end_game()


# Callback from SceneTree, only for clients (not server).
func _connected_fail():
	get_tree().set_network_peer(null) # Remove peer
	emit_signal("connection_failed")


# Lobby management functions.

remote func register_player(new_player_name, new_player_color):
	var id = get_tree().get_rpc_sender_id()
	print(id)
	players[id] = new_player_name
	colors[id] = new_player_color
	emit_signal("player_list_changed")


func unregister_player(id):
	players.erase(id)
	colors.erase(id)
	emit_signal("player_list_changed")


remote func pre_start_game(allplayers, allcolors):
	# Change scene.
	var game = load("res://game.tscn").instance()
	get_tree().get_root().add_child(game)
	
	var controls_scene = load("res://controls.tscn")
	
	for p in allplayers:
		var player = controls_scene.instance()

		player.set_name(str(p)) # Use unique ID as node name.
		player.set_network_master(p) #set unique id as master.
		player.color = allcolors[p]

		game.get_node("controls").add_child(player)

	get_tree().get_root().get_node("LobbyLayer").get_node("Lobby").hide()
	get_tree().get_root().get_node("MainMenuLayer").get_node("Background").hide()

	if not get_tree().is_network_server():
		# Tell server we are ready to start.
		rpc_id(1, "ready_to_start", get_tree().get_network_unique_id())
	else:
		post_start_game()

remote func post_start_game():
	get_tree().set_pause(false) # Unpause and unleash the game!


remote func ready_to_start(id):
	assert(get_tree().is_network_server())

	if not id in players_ready:
		players_ready.append(id)

	if players_ready.size() == players.size():
		players_ready.clear()
		for p in players:
			rpc_id(p, "post_start_game")
		post_start_game()


func host_game(new_player_name, new_player_color):
	player_name = new_player_name
	player_color = new_player_color
	var host = NetworkedMultiplayerENet.new()
	host.create_server(DEFAULT_PORT, MAX_PEERS)
	get_tree().set_network_peer(host)


func join_game(ip, new_player_name, new_player_color):
	player_name = new_player_name
	player_color = new_player_color
	var client = NetworkedMultiplayerENet.new()
	client.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(client)


func get_player_list():
	return players.values()


func get_player_name():
	return player_name


func begin_game():
	assert(get_tree().is_network_server())

	var allplayers = players
	allplayers[1] = player_name
	colors[1] = player_color
	for p in players:
		rpc_id(p, "pre_start_game", allplayers, colors)
		
	pre_start_game(allplayers, colors)


func end_game():
	if has_node("/root/game"): # Game is in progress.
		# End it
		get_node("/root/game").queue_free()

	emit_signal("game_ended")
	players.clear()
	colors.clear()
	
	get_tree().get_root().get_node("LobbyLayer").get_node("Lobby").show()
	get_tree().get_root().get_node("MainMenuLayer").get_node("Background").show()


func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self,"_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
