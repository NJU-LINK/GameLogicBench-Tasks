extends RefCounted
#
# NAIVE reference controller -- passes while the world stays as it was at t=0, FAILS when it
# changes mid-run.
#
# Hand-rolled pathing: at setup() it rasterizes the level into a coarse grid (a cell is blocked if
# an agent-sized-plus-margin circle at its center collides), runs a plain grid BFS from start to
# goal ONCE, and caches the waypoint list. decide() just walks the cached waypoints in order.
# The hand-rolled weakness the task exposes: it plans ONCE and never re-plans. When the door
# closes mid-run, its cached path still aims through the (now solid) door -> it drives into the
# wall (clipping) or never arrives (timeout).

const CELL := 16.0
const MARGIN := 6.0   # keep-away from walls beyond the body radius when rasterizing

var _waypoints: PackedVector2Array = PackedVector2Array()
var _idx := 0

func setup(state: Dictionary) -> void:
	var world = state["world"]
	var start: Vector2 = state["self_pos"]
	var goal: Vector2 = state["goal_pos"]
	var radius: float = state["radius"]
	var space = world.get_world_2d().direct_space_state
	var cols := int(720.0 / CELL)
	var rows := int(520.0 / CELL)

	var shape := CircleShape2D.new()
	shape.radius = radius + MARGIN
	var blocked := []
	for c in range(cols):
		var col := []
		for r in range(rows):
			var p := Vector2((c + 0.5) * CELL, (r + 0.5) * CELL)
			var sq := PhysicsShapeQueryParameters2D.new()
			sq.shape = shape
			sq.transform = Transform2D(0.0, p)
			col.append(space.intersect_shape(sq, 1).size() > 0)
		blocked.append(col)

	var sc := Vector2i(int(start.x / CELL), int(start.y / CELL))
	var gc := Vector2i(int(goal.x / CELL), int(goal.y / CELL))
	_waypoints = _bfs(blocked, cols, rows, sc, gc)
	_idx = 0

func _bfs(blocked, cols, rows, sc: Vector2i, gc: Vector2i) -> PackedVector2Array:
	var came := {}
	var q: Array[Vector2i] = [sc]
	came[sc] = sc
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var found := false
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur == gc:
			found = true
			break
		for d in dirs:
			var n: Vector2i = cur + d
			if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				continue
			if came.has(n) or blocked[n.x][n.y]:
				continue
			came[n] = cur
			q.push_back(n)
	var pts := PackedVector2Array()
	if not found:
		return pts
	var node := gc
	while node != sc:
		pts.append(Vector2((node.x + 0.5) * CELL, (node.y + 0.5) * CELL))
		node = came[node]
	pts.reverse()
	return pts

func decide(state: Dictionary) -> Vector2:
	var here: Vector2 = state["self_pos"]
	if _idx >= _waypoints.size():
		return state["goal_pos"] - here
	var target: Vector2 = _waypoints[_idx]
	if here.distance_to(target) < CELL * 0.5:
		_idx += 1
		return Vector2.ZERO if _idx >= _waypoints.size() else (_waypoints[_idx] - here)
	return target - here
