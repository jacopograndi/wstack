extends Node

puppet var direction = -1;
puppet var move = false;
puppet var shoot = false;
puppet var stand = false;
puppet var run = true;
puppet var swap = false;
puppet var checksum = 0;
puppet var mapchecksum = 0;

var actions = 0

var gridpos = Vector2(0, 0)
var cooldown = 0
var heading = 0

var color = Color(1,1,1)

onready var ground = $"../../ground";
onready var walls = $"../../walls";
onready var objects = $"../../objects";

func _ready():
	cooldown = 0

func _process(delta):
	if is_network_master():
		direction = -1;
		stand = false
		move = false
		swap = false
		shoot = false
		if Input.is_action_pressed("ui_right"): direction = 0;
		if Input.is_action_pressed("ui_up"): direction = 1;
		if Input.is_action_pressed("ui_left"): direction = 2;
		if Input.is_action_pressed("ui_down"): direction = 3;
		if Input.is_action_pressed("ui_run"): stand = true;
		if Input.is_action_pressed("ui_grab"): move = true;
		if Input.is_action_pressed("ui_swap"): swap = true;
		if Input.is_action_just_pressed("ui_select"): shoot = true;
		if Input.is_action_just_pressed("ui_cancel") and false: 
			gamestate.end_game()
		
		rset_unreliable("direction", direction);
		rset_unreliable("stand", stand);
		rset_unreliable("move", move);
		rset_unreliable("swap", swap);
		rset_unreliable("shoot", shoot);
		rset_unreliable("run", run);
		
		if get_tree().is_network_server() and false:
			if Input.is_action_just_pressed("ui_focus_next"): 
				$"../../main".gen_map_settings()
		
		# desync check
		checksum = 0
		var objs = objects.get_used_cells()
		for pos in objs:
			checksum += objects.get_cellv(pos) * pos.length_squared()
		rset_unreliable("checksum", checksum);
		
		# map desync check
		mapchecksum = 0
		var gr = ground.get_used_cells()
		for pos in gr:
			mapchecksum += ground.get_cellv(pos) * pos.length_squared()
		var wl = walls.get_used_cells()
		for pos in wl:
			mapchecksum += walls.get_cellv(pos) * pos.length_squared()
		rset_unreliable("mapchecksum", mapchecksum);
