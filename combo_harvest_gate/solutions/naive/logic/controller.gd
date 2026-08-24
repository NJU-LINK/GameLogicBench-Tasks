extends RefCounted
#
# NAIVE solution for combo_harvest_gate — the broadly-wrong attempt. One instance runs per worker.
#
# The haul loop is there (approach a stocked mine, collect one unit at a time, return to the
# command center when full, deposit, repeat), but three things are wrong:
#   * PASSIVE SHOVE : the collect clock advances whenever the worker is within a mine's reach by
#     DISTANCE, never checking `state.pushed` — it "harvests through" a shove.
#   * MIGRATION     : the mine roster is filtered to pit 0, so a worker never re-targets when its
#     pit runs dry.
#   * CREW          : only worker 0 is ever driven; the rest of the crew stands still.

const APPROACH_EPS := 2.0
const COMMIT_EPS := 0.001

var _clock := 0.0

func on_tick(state: Dictionary) -> Dictionary:
	# DEFECT: only the first worker is ever driven; the rest of the crew is never dispatched.
	if int(state["self_id"]) != 0:
		return {"move": Vector2.ZERO, "commit": false, "deposit": false}

	var pos: Vector2 = state["self_pos"]
	var load: int = int(state["self_load"])
	var cap: int = int(state["capacity"])
	var speed: float = float(state["max_speed"])
	var dt: float = float(state["dt"])
	var collect_time: float = float(state["collect_time"])

	var mine := _nearest_stocked(state)

	if load >= cap or (mine.is_empty() and load > 0):
		return _go_deposit(state)
	if mine.is_empty():
		return {"move": Vector2.ZERO, "commit": false, "deposit": false}

	var reach: float = float(mine["collect_range"])
	var d := pos.distance_to(mine["pos"])

	if d <= reach - APPROACH_EPS:
		var commit := false
		# DEFECT: the clock advances regardless of state.pushed — a shove does not suspend it.
		_clock += dt
		if _clock >= collect_time - COMMIT_EPS:
			commit = true
			_clock -= collect_time
		return {"move": Vector2.ZERO, "commit": commit, "deposit": false}

	return {"move": _seek(pos, mine["pos"], speed), "commit": false, "deposit": false}

func _go_deposit(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var cc: Vector2 = state["cc_pos"]
	var cc_range: float = float(state["cc_range"])
	var speed: float = float(state["max_speed"])
	if pos.distance_to(cc) <= cc_range:
		return {"move": Vector2.ZERO, "commit": false, "deposit": true}
	return {"move": _seek(pos, cc, speed), "commit": false, "deposit": false}

func _seek(from: Vector2, to: Vector2, speed: float) -> Vector2:
	var dir := to - from
	if dir.length() < 0.001:
		return Vector2.ZERO
	return dir.normalized() * speed

func _nearest_stocked(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var best := {}
	var best_d := INF
	for m in state["mines"]:
		# DEFECT: only the first pit is ever a candidate — no migration when it runs dry.
		if int(m["id"]) != 0:
			continue
		if int(m["stock"]) <= 0:
			continue
		var d: float = pos.distance_to(m["pos"])
		if d < best_d:
			best_d = d
			best = m
	return best
