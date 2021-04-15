extends Control
var rng = RandomNumberGenerator.new()
onready var NewGameButton = $Menu/Margin/V/NewGame
onready var MultiplayerButton = $Menu/Margin/V/Multiplayer

func _ready():
	rng.randomize()
	NewGameButton.connect("pressed", self, "start_game")
	MultiplayerButton.connect("pressed", self, "start_lobby")

func start_lobby():
	var lobby = load("res://ui/lobby.tscn").instance()
	get_tree().get_root().add_child(lobby)
	$"../Title".visible = false
	self.hide()

func start_game():
	$"../Background".visible = false
	$"../Title".visible = false
	var host = NetworkedMultiplayerENet.new()
	host.create_server(42069, 32)
	get_tree().set_network_peer(host)
	
	var game = load("res://game.tscn").instance()
	get_tree().get_root().add_child(game)
	
	var controls_scene = load("res://controls.tscn")
	
	for p in [1]:
		var player = controls_scene.instance()

		player.color = Color.from_hsv(rng.randf_range(0, 1), 1, 1, 1)
		player.set_name(str(p)) # Use unique ID as node name.
		player.set_network_master(p) #set unique id as master.

		game.get_node("controls").add_child(player)

	var lobby = get_tree().get_root().get_node("Lobby")
	if lobby != null: lobby.hide()
	self.hide()
