extends RefCounted
#
# NAIVE reference controller -- the classic "at the start of the turn, plan each unit's move to an
# enemy and swing once, then run the plan" version. It is a real, coherent controller, not a
# strawman: at turn start it assigns each of our units to its nearest living enemy, pathfinds around
# the walls to the nearest free cell next to that enemy, and appends [move..., one attack] to a
# single queue. It then hands out that queue one action at a time WITHOUT re-reading the board.
#
# Its defects all flow from that ONE decision — a turn-start SNAPSHOT it never revisits, plus a
# planner blind to the board's reactive-threat fields:
#   * two units assigned to the same enemy path to the SAME approach cell; the second marches onto
#     the first after it has arrived                                    -> replan_path axis
#   * each unit swings ONCE at its own target, so a shared budget gets split across two enemies and
#     kills neither when each needs two hits                            -> kill_priority axis
#   * it never asks whether a blow is survivable, so it feeds a unit to
#     a lethal retaliator it cannot kill                                -> suicide_guard axis
#   * when an enemy has no reachable approach cell it does NOT give up — it falls back to stepping
#     toward the enemy and rebuilds this every turn, so it never ends   -> livelock axis
#   * it pathfinds by walls alone, so a step routes straight through a
#     living enemy's zone of control and the unit is struck             -> threat_zone axis
#   * it ends the instant its budget is spent, leaving a unit parked in
#     an enemy's disengage-bite range at turn end                       -> kite_retreat axis
# On the baseline (two lone reachable one-shot enemies, ample budget, no lethal retaliator, no
# shared approach cell, no reactive-threat enemies) the snapshot plan works, so every baseline cell
# passes.

const A_MOVE := "move"
const A_ATTACK := "attack"
const A_END := "end"

var _queue: Array = []      # snapshot plan: a flat list of action dicts
var _built := false

func next_action(state: Dictionary) -> Dictionary:
	# out of attack budget -> the plan can no longer kill anything, so stop.
	if int(state["team_ap"]) <= 0:
		return {"type": A_END}
	# (Re)build the snapshot whenever the queue runs dry (also the source of the livelock: a sealed
	# enemy makes every rebuild produce another chase step, forever).
	if _queue.is_empty():
		_queue = _build_plan(state)
	if _queue.is_empty():
		return {"type": A_END}
	return _queue.pop_front()

func _build_plan(state: Dictionary) -> Array:
	var units: Array = state["units"]
	var w := int(state["w"]); var h := int(state["h"])
	var walls := _wall_set(state["walls"])
	var occ := _occupancy(units)
	var budget := int(state["team_ap"])
	var plan: Array = []

	var foes := _team(units, 1)
	if foes.is_empty():
		return plan
	for u in _team(units, 0):
		var e := _nearest(u, foes)
		if e.is_empty():
			continue
		var goal := _nearest_adjacent_free(e, u, w, h, walls, occ)
		if goal.is_empty():
			# no reachable approach cell -> fall back to a single greedy chase step (no giving up).
			var chase := _greedy_step(u, e, w, h, walls, occ)
			if not chase.is_empty():
				plan.append({"type": A_MOVE, "unit": int(u["id"]), "target": chase})
			continue
		var path := _bfs_path([int(u["pos"][0]), int(u["pos"][1])], goal, w, h, walls, occ)
		for cell in path:
			plan.append({"type": A_MOVE, "unit": int(u["id"]), "target": cell})
		# one swing per unit at its own target, while the shared budget lasts (split fire).
		if budget > 0:
			plan.append({"type": A_ATTACK, "unit": int(u["id"]), "target": int(e["id"])})
			budget -= 1
	return plan

# --- helpers -----------------------------------------------------------------------------------

func _team(units: Array, t: int) -> Array:
	var out: Array = []
	for u in units:
		if int(u["team"]) == t and bool(u["alive"]):
			out.append(u)
	return out

func _nearest(u: Dictionary, foes: Array) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1 << 30
	for e in foes:
		var d := _md(u, e)
		if d < bd:
			bd = d
			best = e
	return best

func _md(a: Dictionary, b: Dictionary) -> int:
	return abs(int(a["pos"][0]) - int(b["pos"][0])) + abs(int(a["pos"][1]) - int(b["pos"][1]))

func _wall_set(walls: Array) -> Dictionary:
	var s := {}
	for wpt in walls:
		s[_key(int(wpt[0]), int(wpt[1]))] = true
	return s

func _occupancy(units: Array) -> Dictionary:
	var o := {}
	for u in units:
		if bool(u["alive"]):
			o[_key(int(u["pos"][0]), int(u["pos"][1]))] = true
	return o

func _key(x: int, y: int) -> int:
	return x * 100000 + y

func _standable(x: int, y: int, w: int, h: int, walls: Dictionary, occ: Dictionary) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	if walls.has(_key(x, y)):
		return false
	if occ.has(_key(x, y)):
		return false
	return true

# The free orthogonal neighbour of enemy e nearest (by manhattan) to unit u — the approach cell.
func _nearest_adjacent_free(e: Dictionary, u: Dictionary, w: int, h: int,
		walls: Dictionary, occ: Dictionary) -> Array:
	var ex := int(e["pos"][0]); var ey := int(e["pos"][1])
	var best: Array = []
	var bd := 1 << 30
	for d in [[1,0],[-1,0],[0,1],[0,-1]]:
		var nx := ex + int(d[0]); var ny := ey + int(d[1])
		if not _standable(nx, ny, w, h, walls, occ):
			continue
		# reachable from u? (BFS existence)
		var p := _bfs_path([int(u["pos"][0]), int(u["pos"][1])], [nx, ny], w, h, walls, occ)
		if p.is_empty() and not (int(u["pos"][0]) == nx and int(u["pos"][1]) == ny):
			continue
		var dd := (abs(int(u["pos"][0]) - nx) + abs(int(u["pos"][1]) - ny)) as int
		if dd < bd:
			bd = dd
			best = [nx, ny]
	return best

# Shortest path (list of cells to step onto, excluding the start) around walls, snapshot occupancy.
func _bfs_path(start: Array, goal: Array, w: int, h: int, walls: Dictionary, occ: Dictionary) -> Array:
	if int(start[0]) == int(goal[0]) and int(start[1]) == int(goal[1]):
		return []
	var came := {}
	var frontier: Array = [start]
	came[_key(int(start[0]), int(start[1]))] = null
	var qi := 0
	while qi < frontier.size():
		var c: Array = frontier[qi]; qi += 1
		for d in [[1,0],[-1,0],[0,1],[0,-1]]:
			var nx := int(c[0]) + int(d[0]); var ny := int(c[1]) + int(d[1])
			var k := _key(nx, ny)
			if came.has(k):
				continue
			var is_goal := (nx == int(goal[0]) and ny == int(goal[1]))
			# may step onto a standable cell; the goal cell must also be standable.
			if not _standable(nx, ny, w, h, walls, occ):
				continue
			came[k] = c
			if is_goal:
				return _reconstruct(came, goal)
			frontier.append([nx, ny])
	return []

func _reconstruct(came: Dictionary, goal: Array) -> Array:
	var path: Array = []
	var cur: Variant = goal
	while cur != null:
		path.push_front([int(cur[0]), int(cur[1])])
		cur = came[_key(int(cur[0]), int(cur[1]))]
	path.pop_front()   # drop the start cell
	return path

# One legal free neighbour that minimizes manhattan distance to the enemy (greedy chase).
func _greedy_step(u: Dictionary, e: Dictionary, w: int, h: int, walls: Dictionary, occ: Dictionary) -> Array:
	var ux := int(u["pos"][0]); var uy := int(u["pos"][1])
	var ex := int(e["pos"][0]); var ey := int(e["pos"][1])
	var best: Array = []
	var bd := 1 << 30
	for d in [[1,0],[-1,0],[0,1],[0,-1]]:
		var nx := ux + int(d[0]); var ny := uy + int(d[1])
		if not _standable(nx, ny, w, h, walls, occ):
			continue
		var dd := (abs(nx - ex) + abs(ny - ey)) as int
		if dd < bd:
			bd = dd
			best = [nx, ny]
	return best
