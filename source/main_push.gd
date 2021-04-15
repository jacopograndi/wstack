extends Node

onready var ground = $"../ground"
onready var walls = $"../walls"
onready var objects = $"../objects"
onready var controls = $"../controls"
onready var map_settings = $"../gui/map_settings"
onready var map_settings_generate = $"../gui/map_settings/Settings/Margin/V/Generate"
onready var map_settings_boxes = $"../gui/map_settings/Settings/Margin/V/H/VSliders/HSliderBoxes"
onready var map_settings_size = $"../gui/map_settings/Settings/Margin/V/H/VSliders/HSliderSize"
onready var map_settings_bias = $"../gui/map_settings/Settings/Margin/V/H/VSliders/HSliderBias"
onready var gui_newmap = $"../gui/NewMap"
onready var gui_youwin = $"../gui/YouWin"
onready var gui_youwin_newmap = $"../gui/YouWin/NewMap"
onready var gui_goals = $"../gui/Stats/Margin/H/VValues/Goals"
onready var gui_actions = $"../gui/Stats/Margin/H/VValues/Actions"
onready var gui_time = $"../gui/Stats/Margin/H/VValues/Time"
onready var gui = $"../gui"
onready var camera = $"../Camera2D"
var dir_to_vec_map
var dir_to_tile_map
var pusher_id
var box_id
var goal_box_id
var time = 0

var map_size = 6;
var map_boxes = 63;
var map_bias = 0.5;

var winwait = false

func _ready():
	dir_to_vec_map = [
		Vector2(1, 0),
		Vector2(0, -1), 
		Vector2(-1, 0), 
		Vector2(0, 1) ]
	dir_to_tile_map = [ 
		[false, false, false],
		[false, true, true], 
		[true, true, false],
		[true, false, true] ]
	pusher_id = objects.tile_set.find_tile_by_name("pusher");
	box_id = objects.tile_set.find_tile_by_name("box");
	goal_box_id = ground.tile_set.find_tile_by_name("goal_box");
	
	if get_tree().is_network_server():
		map_settings_generate.connect("pressed", self, "gen_map_settings")
		map_settings_boxes.connect("value_changed", self, "gen_map_set_boxes")
		map_settings_size.connect("value_changed", self, "gen_map_set_size")
		map_settings_bias.connect("value_changed", self, "gen_map_set_bias")
		gui_newmap.connect("pressed", self, "map_settings_show")
		gui_youwin_newmap.connect("pressed", self, "map_settings_show")
	else: 
		map_settings.hide()
		gui_newmap.hide()
	
func check_win ():
	var boxes = objects.get_used_cells_by_id(box_id);
	if boxes.size() == 0: return [0, 0]
	var num = 0
	for box in boxes:
		if ground.get_cellv(box) == goal_box_id:
			num += 1
	return [num, boxes.size()]

func _find_pushers ():
	return objects.get_used_cells_by_id(pusher_id);
	
func _swap_cell (tm, p0, p1):
	var id0 = tm.get_cellv(p0)
	var flip_x0 = tm.is_cell_x_flipped(p0.x, p0.y)
	var flip_y0 = tm.is_cell_y_flipped(p0.x, p0.y)
	var transpose0 = tm.is_cell_transposed(p0.x, p0.y)
	var id1 = tm.get_cellv(p1)
	var flip_x1 = tm.is_cell_x_flipped(p1.x, p1.y)
	var flip_y1 = tm.is_cell_y_flipped(p1.x, p1.y)
	var transpose1 = tm.is_cell_transposed(p1.x, p1.y)
	objects.set_cellv(p0, id1, flip_x1, flip_y1, transpose1)
	objects.set_cellv(p1, id0, flip_x0, flip_y0, transpose0)
	
func _move_cell (tm, p0, p1):
	_swap_cell(tm, p0, p1)
	
	var updated = []
	for contr in controls.get_children():
		if contr.gridpos == p0 and not(contr in updated): 
			contr.gridpos = p1
			updated += [contr]
		if contr.gridpos == p1 and not(contr in updated): 
			contr.gridpos = p0
			contr.gridpos = p0
			updated += [contr]
	
func _push (pos, dir, n):
	if n <= 0: return false
	if walls.get_cellv(pos+dir) != -1: 
		return false
	if objects.get_cellv(pos+dir) in [box_id, pusher_id]:
		if _push(pos+dir, dir, n-1):
			_move_cell(objects, pos, pos+dir);
			return false
	if objects.get_cellv(pos+dir) == -1:
		_move_cell(objects, pos, pos+dir);
		return true
	return false
	
func _move (dir, head, move, pos):
	var newpos = pos;
	_push(pos, dir, 200)
	if objects.get_cellv(pos) == -1:
		newpos += dir;
	if move:
		if objects.get_cellv(pos+head) != -1 and head != dir:
			_push(pos+head, dir, 200);
	return newpos

func _shoot (head, pos):
	for i in range(1, 200):
		if not _push(pos+head*i, head, 1): break
	return pos

func _swap (head, pos):
	if walls.get_cellv(pos+head) == -1: 
		_move_cell(objects, pos, pos+head)
		pos += head
	return pos


func _process(delta):
	if get_tree().is_network_server():
		check_objs_desync()
		check_map_desync()
	#else: return
	
	time += delta
	var goals = check_win()
	if goals[0] == goals[1] and not winwait and goals[1] > 0:
		winwait = true
		gui_youwin.popup()

	for contr in controls.get_children():
		var direction = contr.direction;
		var move = contr.move;
		var shoot = contr.shoot;
		var stand = contr.stand;
		var run = contr.run;
		var swap = contr.swap;
		contr.cooldown += delta;
		
		var head = dir_to_vec_map[contr.heading]
		
		if contr.cooldown > 0.12 + int(run)*0.04*3:
			if direction != -1:
				var dir = dir_to_vec_map[direction];
				if not move: contr.heading = direction
				if swap:
					contr.gridpos = _swap(head, contr.gridpos)
					contr.actions += 1
					contr.cooldown = 0;
				elif not stand:
					contr.gridpos = _move(dir, head, move, contr.gridpos);
					contr.actions += 1
					contr.cooldown = 0;
		
		if shoot: 
			contr.gridpos = _shoot(head, contr.gridpos)
			contr.actions += 1
		
		
		objects.set_cellv(contr.gridpos, pusher_id, 
				dir_to_tile_map[contr.heading][0],
				dir_to_tile_map[contr.heading][1],
				dir_to_tile_map[contr.heading][2]);
		
		contr.position = objects.map_to_world(contr.gridpos) + Vector2(12, 12)
		contr.rotation_degrees = -contr.heading*90
		contr.get_child(0).modulate = contr.color
		
		if contr.is_network_master():
			gui_goals.text = str(goals[0]) + "/" + str(goals[1])
			gui_actions.text = str(contr.actions)
			gui_time.text = "%.1f" % time

master func check_objs_desync():
	var correct_checksum = 0
	var players = []
	for contr in controls.get_children():
		if contr.name == "1": 
			correct_checksum = contr.checksum
		players.append([contr.name, contr.gridpos, contr.heading])
		
	var map_objs = []
	var objs = objects.get_used_cells()
	for obj in objs:
		map_objs.append([obj, objects.get_cellv(obj)])
	
	for contr in controls.get_children():
		if contr.name != "1" and correct_checksum != contr.checksum:
			print(contr.name + " desync!" + " (" + str(correct_checksum) +", "+ str(contr.checksum) + ")")
			rpc_id(int(contr.name), "refresh_objs", map_objs, players)

puppet func refresh_objs (map_objs, players):
	objects.clear()
	
	for obj in map_objs:
		var pos = obj[0]
		var id = obj[1]
		objects.set_cellv(pos, id)
		
	for player in players:
		var name = player[0]
		var pos = player[1]
		var heading = player[2]
		for contr in controls.get_children():
			if contr.name == name:
				contr.gridpos = pos
				contr.heading = heading
				objects.set_cellv(contr.gridpos, pusher_id, 
					dir_to_tile_map[contr.heading][0],
					dir_to_tile_map[contr.heading][1],
					dir_to_tile_map[contr.heading][2]);

master func check_map_desync():
	var correct_checksum = controls.get_node("1").mapchecksum
		
	var map_walls = []
	var walls_cell = walls.get_used_cells()
	for pos in walls_cell:
		map_walls.append([pos, walls.get_cellv(pos), 
			walls.is_cell_x_flipped(pos.x, pos.y),
			walls.is_cell_y_flipped(pos.x, pos.y),
			walls.is_cell_transposed(pos.x, pos.y)])
	var map_ground = []
	var ground_cells = ground.get_used_cells()
	for pos in ground_cells:
		map_ground.append([pos, ground.get_cellv(pos)])
	
	for contr in controls.get_children():
		if contr.name != "1" and correct_checksum != contr.mapchecksum:
			print(contr.name + " map desync!" + " (" + str(correct_checksum) +", "+ str(contr.mapchecksum) + ")")
			rpc_id(int(contr.name), "refresh_map", map_ground, map_walls)

puppet func refresh_map (map_ground, map_walls):
	ground.clear()
	walls.clear()
	
	for obj in map_ground:
		ground.set_cellv(obj[0], obj[1])
	for wall in map_walls:
		walls.set_cellv(wall[0], wall[1], wall[2], wall[3], wall[4])
	
	var minv = Vector2(9999, 9999)
	var maxv = Vector2(-9999, -9999)
	var cells = walls.get_used_cells()
	for cell in cells:
		var worldpos = walls.map_to_world(cell);
		if worldpos.x > maxv.x: maxv.x = worldpos.x
		if worldpos.x < minv.x: minv.x = worldpos.x
		if worldpos.y > maxv.y: maxv.y = worldpos.y
		if worldpos.y < minv.y: minv.y = worldpos.y
	camera.position = (maxv+minv)/2;

func map_settings_show(): map_settings.show()

func gen_map_set_boxes(value): map_boxes = value
func gen_map_set_size(value): map_size = value
func gen_map_set_bias(value): map_bias = value
	
func gen_map_settings():
	var size = map_size
	var boxes = map_boxes
	gen_map(size, boxes);
	map_settings.hide()

func gen_map(size, goals):
	var player_n = $"../controls".get_child_count()
	$"../generate_map".gen(size, goals, player_n, map_bias)
	
	var pushers = $"../objects".get_used_cells_by_id(pusher_id)
	for i in range(controls.get_children().size()):
		var contr = controls.get_child(i)
		contr.gridpos = pushers[i]
	time = 0
	winwait = false
