extends RefCounted
# [naive] two defects: constant reach bound + a route planned once (formal red-team solution)
#
# logic/controller.gd -- reference solution for the ledge field.
#
# Three things, in this order, every single frame:
#
#   1. REBUILD the reach graph from state.platforms. An ordered pair (S, P) is an edge when the
#      horizontal distance from S's launch limit to P's near edge is inside what one jump carries
#      for that height difference: reach(dh) = SPEED * (-JUMP_VELOCITY + sqrt(JUMP_VELOCITY^2 +
#      2*GRAVITY*dh)) / GRAVITY, and there is NO edge at all when that discriminant goes negative
#      (the target is higher than the jump can climb, at any distance). The relation is directed:
#      dropping down is cheap, climbing back is not.
#   2. SHORTEST ROUTE over that graph to goal_idx (breadth first). Rebuilding every frame is the
#      whole self-defence against stone that gives way: a route cached once can send the climber to
#      a launch point for a ledge that is no longer there.
#   3. EXECUTE the next edge: walk to the launch point the ballistic solve asks for
#      (launch_x = land_x - reach(dh) in the direction of travel), jump there, and steer in the air
#      so the flight lands on the aim point (SPEED applies in mid-air as well).

const SPEED := 200.0
const JUMP_VELOCITY := -400.0
const GRAVITY := 980.0
const CHAR_R := 12.0            # collision circle radius: centre-to-ground when standing
const OVERHANG := 3.3           # the climber keeps its floor a little past a ledge's edge
const EDGE_MARGIN := 20.0       # only trust an edge this far inside the reach bound
const AIM_FRAC := 0.30          # aim at the near third of the target ledge
const LAUNCH_TOL := 2.2         # close enough to the launch point to commit
const STAND_TOL := 3.0
const REST_INSET := 6.0         # come this far inside the goal ledge before standing still
const LIP := 3.5                # jump from this far inside the ledge's edge

var _plan: Array = []           # cached route (indices into _plan_plats)
var _plan_plats: Array = []     # the ledge set the cached route was computed against
var _aim_x := 1e9               # where the current flight is meant to land
var _air_dir := 0.0             # direction held for the whole flight

# How far one jump carries horizontally when it ends `dh` below the launch surface.
func _reach(dh: float) -> float:
	# DEFECT: the height difference is dropped, so the reach is one constant (163.26) for
	# every pair — it invents edges to ledges above and denies edges to ledges below.
	var disc: float = JUMP_VELOCITY * JUMP_VELOCITY + 2.0 * GRAVITY * 0.0
	if disc < 0.0:
		return -1.0
	return SPEED * ((-JUMP_VELOCITY + sqrt(disc)) / GRAVITY)

# Geometry of one ordered pair: which way the jump goes, how far, and the height difference.
func _pair(s: Rect2, p: Rect2) -> Dictionary:
	var dh: float = p.position.y - s.position.y
	if p.position.x > s.position.x + s.size.x:
		return {"dir": 1.0, "d": p.position.x - (s.position.x + s.size.x + OVERHANG), "dh": dh}
	if p.position.x + p.size.x < s.position.x:
		return {"dir": -1.0, "d": (s.position.x - OVERHANG) - (p.position.x + p.size.x), "dh": dh}
	return {"dir": 0.0, "d": 0.0, "dh": dh}      # spans overlap: not a jump

func _is_edge(s: Rect2, p: Rect2) -> bool:
	var g := _pair(s, p)
	if g["dir"] == 0.0:
		return false
	var r := _reach(g["dh"])
	return r >= 0.0 and float(g["d"]) <= r - EDGE_MARGIN

func _adjacency(plats: Array) -> Array:
	var a: Array = []
	for i in plats.size():
		a.append([])
	for i in plats.size():
		for j in plats.size():
			if i != j and _is_edge(plats[i], plats[j]):
				(a[i] as Array).append(j)
	return a

# Shortest route src -> goal over the DIRECTED graph, as a list of indices, or [] if none.
func _route(plats: Array, src: int, goal: int) -> Array:
	var adj := _adjacency(plats)
	var prev := {src: -1}
	var q: Array[int] = [src]
	while not q.is_empty():
		var c: int = q.pop_front()
		if c == goal:
			break
		for nx in (adj[c] as Array):
			if not prev.has(nx):
				prev[int(nx)] = c
				q.append(int(nx))
	if not prev.has(goal):
		return []
	var path: Array = [goal]
	var cur: int = goal
	while int(prev[cur]) != -1:
		cur = int(prev[cur])
		path.push_front(cur)
	return path

# The ledge the climber is standing on, or -1.
func _standing(plats: Array, pos: Vector2) -> int:
	for i in plats.size():
		var r: Rect2 = plats[i]
		if absf(pos.y - (r.position.y - CHAR_R)) <= STAND_TOL \
				and pos.x >= r.position.x - 13.0 and pos.x <= r.position.x + r.size.x + 13.0:
			return i
	return -1

# Which ledge to leave for next, planning from the live field.
func _next_hop(plats: Array, cur: int, goal: int) -> int:
	# DEFECT: the route is planned once and never revisited, so it keeps executing against
	# the field as it was at the start.
	if _plan.is_empty():
		_plan = _route(plats, cur, goal)
		_plan_plats = plats.duplicate()
	var k := _plan.find(cur)
	if k >= 0 and k + 1 < _plan.size():
		return int(_plan[k + 1])
	if _plan.size() > 1:
		return int(_plan[1])
	return -1

func decide(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var on_floor: bool = state["is_on_floor"]
	var plats: Array = state["platforms"]
	var goal: int = state["goal_idx"]
	var goal_rect: Rect2 = plats[goal]

	# DEFECT: in the air just hold the direction the jump started with — no correction.
	if not on_floor:
		return {"move": _air_dir, "jump": false}

	var cur := _standing(plats, pos)
	if cur < 0:
		return {"move": 0.0, "jump": false}

	# On the goal ledge: settle inside its span and stay put.
	if cur == goal:
		if pos.x > goal_rect.position.x + REST_INSET \
				and pos.x < goal_rect.position.x + goal_rect.size.x - REST_INSET:
			return {"move": 0.0, "jump": false}
		return {"move": (1.0 if goal_rect.get_center().x > pos.x else -1.0), "jump": false}

	var nxt := _next_hop(plats, cur, goal)
	if nxt < 0 or nxt >= _plan_plats.size():
		return {"move": 0.0, "jump": false}

	var from_rect: Rect2 = _plan_plats[cur] if cur < _plan_plats.size() else plats[cur]
	var to_rect: Rect2 = _plan_plats[nxt]
	var g := _pair(from_rect, to_rect)
	var dir: float = g["dir"]
	if dir == 0.0:
		return {"move": 0.0, "jump": false}

	# DEFECT: no ballistic launch solve — walk to the lip and jump there at full effort.
	var lip_x: float = (from_rect.position.x + from_rect.size.x - LIP if dir > 0.0
		else from_rect.position.x + LIP)
	if (dir > 0.0 and pos.x >= lip_x) or (dir < 0.0 and pos.x <= lip_x):
		_air_dir = dir
		return {"move": dir, "jump": true}
	return {"move": dir, "jump": false}
