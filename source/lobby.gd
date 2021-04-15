extends Control

onready var NameInput = $Connect/Margin/V/H/V2/Name
onready var ErrorLabel = $Connect/Margin/V/ErrorLabel
onready var IPAddressInput = $Connect/Margin/V/H/V2/IPAddress
onready var PlayerColor = $Connect/Margin/V/H/Color
onready var HostButton = $Connect/Margin/V/H/V3/Host
onready var JoinButton = $Connect/Margin/V/H/V3/Join
onready var PlayerList = $Players/Margin/V/List
onready var PlayerStart = $Players/Margin/V/Start

func _ready():
	gamestate.connect("connection_failed", self, "_on_connection_failed")
	gamestate.connect("connection_succeeded", self, "_on_connection_success")
	gamestate.connect("player_list_changed", self, "refresh_lobby")
	gamestate.connect("game_ended", self, "_on_game_ended")
	gamestate.connect("game_error", self, "_on_game_error")
	# Set the player name according to the system username. Fallback to the path.
	if OS.has_environment("USERNAME"):
		NameInput.text = OS.get_environment("USERNAME")
	else:
		var desktop_path = OS.get_system_dir(0).replace("\\", "/").split("/")
		NameInput.text = desktop_path[desktop_path.size() - 2]


func _on_host_pressed():
	if NameInput.text == "":
		ErrorLabel.text = "Invalid name!"
		return

	$Connect.hide()
	$Players.show()
	ErrorLabel.text = ""

	var player_name = NameInput.text
	var player_color = PlayerColor.color
	gamestate.host_game(player_name, player_color)
	refresh_lobby()


func _on_join_pressed():
	if NameInput.text == "":
		ErrorLabel.text = "Invalid name!"
		return

	var ip = IPAddressInput.text
	if not ip.is_valid_ip_address():
		ErrorLabel.text = "Invalid IP address!"
		return

	ErrorLabel.text = ""
	HostButton.disabled = true
	JoinButton.disabled = true

	var player_name = NameInput.text
	var player_color = PlayerColor.color
	gamestate.join_game(ip, player_name, player_color)


func _on_connection_success():
	$Connect.hide()
	$Players.show()


func _on_connection_failed():
	HostButton.disabled = false
	JoinButton.disabled = false
	ErrorLabel.set_text("Connection failed.")


func _on_game_ended():
	show()
	$Connect.show()
	$Players.hide()
	HostButton.disabled = false
	JoinButton.disabled = false


func _on_game_error(errtxt):
	$ErrorDialog.dialog_text = errtxt
	$ErrorDialog.popup_centered_minsize()
	HostButton.disabled = false
	JoinButton.disabled = false


func refresh_lobby():
	var players = gamestate.get_player_list()
	players.sort()
	PlayerList.clear()
	PlayerList.add_item(gamestate.get_player_name() + " (You)")
	for p in players:
		PlayerList.add_item(p)

	PlayerStart.disabled = not get_tree().is_network_server()


func _on_start_pressed():
	gamestate.begin_game()
