extends Node

var rng = RandomNumberGenerator.new()
onready var ground = $"../ground"
onready var walls = $"../walls"
onready var objects = $"../objects"
onready var camera = $"../Camera2D"
var pusher_id;
var box_id;
var empty_id;
var goal_box_id;

var dir_to_vec_map = [
	Vector2(1, 0),
	Vector2(0, -1), 
	Vector2(-1, 0), 
	Vector2(0, 1) ]
	
var dir_to_tile_map = [ 
	[false, false, false],
	[false, true, true], 
	[true, true, false],
	[true, false, true] ]

# Called when the node enters the scene tree for the first time.
func _ready():
	pusher_id = objects.tile_set.find_tile_by_name("pusher");
	box_id = objects.tile_set.find_tile_by_name("box");
	empty_id = ground.tile_set.find_tile_by_name("empty");
	goal_box_id = ground.tile_set.find_tile_by_name("goal_box");
	rng.randomize()
	
	
func sum (l):
	var acc = 0;
	for e in l: acc += e
	return acc

func _get_squares_smaller_than (n):
	var squares = []
	for i in range(1, n):
		if i*i < n: squares += [i]
		else: return squares
	return [1]

func _largest_square_in (n):
	return _get_squares_smaller_than(n)[-1]

func _squares_left (squares):
	var acc = 0
	for r in squares: acc += r*r
	return acc

func _rects_intersect (rects, b):
	for a in rects:
		if a[0]+a[2]>=b[0] \
		and a[0]<=b[0]+b[2] \
		and a[1]+a[3]>=b[1] \
		and a[1]<=b[1]+b[3] :
			return true
	return false
	
func _get_vec_place (size):
	return Vector2(
			rng.randi_range(-size, size), 
			rng.randi_range(-size, size))
	
func _place_goals (squares, size):
	var rects = []
	var placed = 0
	var iters = 0
	while placed < squares.size():
		var vec = _get_vec_place(size)
		var rect = [ vec.x, vec.y, squares[placed], squares[placed] ]
		if not _rects_intersect(rects, rect):
			placed += 1
			rects += [rect]
		if iters > 10000: return rects
		iters += 1
	return rects
	
func _random_rects (n, size):
	var rects = []
	for _i in range(n):
		var vec = _get_vec_place(size)
		var rect = [ vec.x, vec.y, 
			rng.randi_range(1, size), 
			rng.randi_range(1, size) ]
		rects += [rect]
	return rects
	
func _rects_fill (tm, rects, id):
	for r in rects:
		for x in range(r[0], r[0]+r[2]):
			for y in range(r[1], r[1]+r[3]):
				tm.set_cell(x, y, id)

func _get_connected (tm, start):
	var visited = []
	var frontier = [start]
	var pos = Vector2()
	
	var i = 0;
	while true:
		#print(visited, " ", frontier)
		if frontier.size() == 0: break
		for d in range(4):
			pos = frontier[0]+dir_to_vec_map[d]
			if not(pos in visited) and not(pos in frontier):
				if tm.get_cellv(pos) != -1:
					frontier += [pos]
		visited.append(Vector2(frontier[0].x, frontier[0].y))
		frontier.pop_front()
		if i>10000: break
		i += 1;
		
	return visited

func _is_in_regions (regions, pos):
	for r in regions:
		if pos in r: return true
	return false
	
func _get_closest_region (regions, current):
	var mindist = 9999
	var minpair = null
	for r in regions:
		if r == current: continue
		for p in current:
			for q in r:
				var dist = p.distance_squared_to(q)
				if dist < 5: return [p, q]
				if dist < mindist: 
					mindist = dist
					minpair = [p, q]
	return minpair
	
func _connect (tm):
	var cells = tm.get_used_cells()
	var regions = []
	for pos in cells:
		if not _is_in_regions(regions, pos):
			regions.append(_get_connected(tm, pos))
	
	while regions.size() > 1:
		var pair = _get_closest_region(regions, regions[0])
		var p = pair[0]
		var q = pair[1]
		if q.x < p.x: 
			var t = p; 
			p = q; 
			q = t
		var middle = Vector2(q.x, p.y)
		for x in range(abs(q.x-p.x)+1):
			var pos = p+Vector2(x, 0);
			if tm.get_cellv(pos) == -1: 
				tm.set_cellv(pos, empty_id)
		for y in range(abs(middle.y-q.y)+1):
			var pos = middle+Vector2(0, y);
			if middle.y > q.y: pos = middle-Vector2(0, y);
			if tm.get_cellv(pos) == -1: 
				tm.set_cellv(pos, empty_id)
		regions.clear()
		
		cells = tm.get_used_cells()
		for pos in cells:
			if not _is_in_regions(regions, pos):
				regions.append(_get_connected(tm, pos))

func _place_boxes (n):
	var cells = ground.get_used_cells_by_id(empty_id)
	for _i in range(n):
		var pos = cells[rng.randi_range(0, cells.size()-1)]
		objects.set_cellv(pos, box_id);
		cells.erase(pos)
		if cells.size() < 8: break
		
func _place_pushers (n):
	var cells = ground.get_used_cells_by_id(empty_id)
	for pos in cells:
		if objects.get_cellv(pos) != -1:
			cells.erase(pos)
	for _i in range(n):
		var pos = cells[rng.randi_range(0, cells.size()-1)]
		objects.set_cellv(pos, pusher_id);

func _wall_rule_rotate (rule):
	# anticlockwise 90 deg
	var rot = [ "   ", "   ", "   " ]
	for y in range(rule.size()):
		for x in range(rule[y].length()):
			rot[rule.size()-1-y][x] = rule[x][y]
	return rot

func _wall_rules_rotate (rules):
	var rotated = []
	for rule in rules:
		var rot = rule
		for _d in range(4):
			if not(rot in rotated): rotated.append(rot)
			rot = _wall_rule_rotate(rot);
	return rotated
	
func _apply_rules (rules, pos):
	for key in rules.keys():
		for i in range(0, rules[key].size()):
			var rule = rules[key][i]
			var ok = true
			for x in range(3):
				for y in range(3):
					var off = pos+Vector2(x-1, y-1)
					if rule[y][x] == ">":
						if not(ground.get_cellv(off) != -1): ok = false
					if rule[y][x] == "X":
						if not(ground.get_cellv(off) == -1): ok = false
					if not ok: break
				if not ok: break
			if ok: 
				var rot = i
				var id = walls.tile_set.find_tile_by_name(key)
				var flip_x = dir_to_tile_map[rot][0]
				var flip_y = dir_to_tile_map[rot][1]
				var transpose = dir_to_tile_map[rot][2]
				walls.set_cellv(pos, id, flip_x, flip_y, transpose);
				return

func _place_walls ():
	var rules = {
		"wall corner": 
		[[ " > ", 
		   "XX>", 
		   " X " ]],
		"wall straight": 
		[[ " X ", 
		   "XXX", 
		   " > " ]],
		"wall corner inner": 
		[[ "XXX", 
		   "XXX", 
		   ">XX" ]],
		"wall dot":
		 [[ " > ", 
			">X>", 
			" > " ]],
		"wall corridor":
		 [[ " > ", 
			"XXX", 
			" > " ]],
		"wall end":
		 [[ " > ", 
			">XX", 
			" > " ]],
		"wall cross":
		 [[ ">X>", 
			"XXX", 
			">X>" ]],
		"wall threeway":
		 [[ "XX>", 
			"XXX", 
			">X>" ]],
		"wall T void":
		 [[ "XX>", 
			"XXX", 
			"XX>" ]],
		"wall T diagonal":
		 [[ " X>", 
			"XXX", 
			">X " ]],
		"wall T":
		 [[ " > ", 
			"XXX", 
			">X>" ]],
	}
	
	for key in rules.keys():
		rules[key] = _wall_rules_rotate(rules[key])
	
	var rect = ground.get_used_rect()
	
	for x in range(rect.position.x-1, rect.position.x+rect.size.x+1):
		for y in range(rect.position.y-1, rect.position.y+rect.size.y+1):
			_apply_rules(rules, Vector2(x, y))
	
func _clear_all():
	ground.clear()
	walls.clear()
	objects.clear()

	
func get_biased_range(n, size_bias):
	# 1 is only biggest
	# 0.5 is unbiased
	# 0 is only smallest
	var bias_small = size_bias*2
	var bias_big = (size_bias-0.5)*2
	var value = rng.randf()
	if size_bias < 0.5: value = pow(value, bias_small*3)
	if size_bias > 0.5: value = pow(value, bias_big*30)
	if value == 1: value = 0.999999
	return floor(value*n)
	
func _get_squares (n, size_bias):
	var S = _get_squares_smaller_than(n);
	if S.size() > 1: 
		S.erase(1) # better maps, no 1x1 goals
	var sel = []
	while _squares_left(sel) < n:
		var index = S[ get_biased_range(S.size(), size_bias) ]
		sel += [ index ]
		var delist = []
		for s in S:
			if s*s > n-_squares_left(sel): delist += [s]
		for d in delist: S.erase(d)
		if S.size() == 0: S += [1] # fix oob
	return sel

func gen (size, n, player_n, size_bias):
	_clear_all();
	
	var squares = _get_squares(n, size_bias);
	
	var rects = _place_goals(squares, size)
	var n_bigrooms = 7+size+(size*size)/20
	var rooms = _random_rects(n_bigrooms, size);
	rooms += _random_rects(size*2, size/2);
	_rects_fill(ground, rooms, empty_id)
	_rects_fill(ground, rects, goal_box_id)
	
	_connect(ground);
	
	var goals = ground.get_used_cells_by_id(goal_box_id)
	_place_boxes(goals.size())
	_place_pushers(player_n)
	_place_walls()
	
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
