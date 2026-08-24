extends RefCounted
#
# NAIVE reference controller -- passes the gentle baseline, FAILS every hidden cell on its armed
# axis.
#
# Two lazy shortcuts, both the shape a hurried escort takes:
#   * NAV      : it plans ONCE. setup() rasterizes the level into a coarse grid and BFS's a route to
#                the goal, then decide() just walks the cached waypoints. When a door closes mid-run
#                the cached route still aims through the (now solid) door -> the LEADER drives into
#                the wall (clipping / move_navigation).
#   * ESCORT   : it ignores the straggler entirely -- it beelines for the goal at full speed and
#                never looks back. On the open baseline the straggler trails harmlessly on the same
#                straight line; but the moment the leader rounds a corner, the straggler -- walking
#                straight at the far-ahead leader -- has a wall fall on the tether and is dragged
#                into it (tether_snapped / tether).
#
# baseline: cached straight route is valid + the straggler trails in-line -> both arrive -> PASS.

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
	var cols := int(640.0 / CELL) + 2
	var rows := int(480.0 / CELL) + 2

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
