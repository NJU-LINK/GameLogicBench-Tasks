extends RefCounted
#
# NAIVE reference controller -- the classic reactive pusher. It is a real, coherent controller,
# not a strawman: every tick it re-reads the whole board, picks the unfinished crate closest to
# its nearest matching zone, walks around walls and crates to the push side, and makes the push
# that REDUCES the crate's distance to that zone right now.
#
# Its defects all flow from that ONE decision -- judging every push by the distance it gains,
# never by what it makes unreachable:
#   * it happily makes a distance-gaining push into a corner pocket from which the crate can
#     never be pushed again                                                  -> deadlock_guard
#   * when no distance-reducing push exists (the pattern demands pushing the crate AWAY from its
#     zone first), it has nothing to do and idles until the budget dies     -> detour_plan
#   * it handles crates nearest-job-first and parks them where they land, so a parked crate walls
#     off a later crate's only corridor and the next push freezes them both -> box_coupling
#   * (with kinds crossed it still matches kinds -- but its cousins that read "nearest zone"
#     without the kind check die on the same boards through typed_order)
# On the baseline (straight separate lanes, no pockets, no shared corridor) greedy pushing is
# simply correct, so every baseline cell passes.

const DIRS := {
	"up": [0, -1],
	"down": [0, 1],
	"left": [-1, 0],
	"right": [1, 0],
}

func on_tick(state: Dictionary) -> String:
	var walls := _wall_set(state)
	var w := int(state["w"])
	var h := int(state["h"])
	var crates: Array = state["boxes"]
	var zones: Array = state["zones"]
	var occ := _occupancy(crates)

	# rank unfinished crates: manhattan distance to the nearest free matching zone, then id.
	var order: Array = []
	for b in crates:
		if _placed(b, zones):
			continue
		var tz := _nearest_zone(b, zones, occ)
		if tz.is_empty():
			continue
		order.append({"b": b, "z": tz,
			"key": [_md(b["pos"], tz["pos"]), int(b["id"])]})
	order.sort_custom(func(p, q): return _less(p["key"], q["key"]))

	for job in order:
		var step := _push_job(state, walls, occ, w, h, job["b"], job["z"])
		if step != "":
			return step
	return "wait"

# Try to advance ONE crate toward ONE zone: push it now if the worker stands on the push side of
# a distance-reducing direction; otherwise walk toward such a push-side cell.
func _push_job(state: Dictionary, walls: Dictionary, occ: Dictionary, w: int, h: int,
		b: Dictionary, z: Dictionary) -> String:
	var bx := int(b["pos"][0])
	var by := int(b["pos"][1])
	var px := int(state["player"][0])
	var py := int(state["player"][1])

	# distance-reducing push directions, biggest axis gap first (march down the long axis).
	var cand: Array = []
	var dx := int(z["pos"][0]) - bx
	var dy := int(z["pos"][1]) - by
	var xd := "right" if dx > 0 else "left"
	var yd := "down" if dy > 0 else "up"
	if abs(dx) >= abs(dy):
		if dx != 0: cand.append(xd)
		if dy != 0: cand.append(yd)
	else:
		if dy != 0: cand.append(yd)
		if dx != 0: cand.append(xd)

	for dname in cand:
		var d: Array = DIRS[dname]
		var tx := bx + int(d[0])
		var ty := by + int(d[1])
		var sx := bx - int(d[0])
		var sy := by - int(d[1])
		if _solid(walls, occ, tx, ty, w, h):
			continue          # the receiving cell is blocked right now -> not this direction
		if px == sx and py == sy:
			return dname       # in position: push (no questions asked)
		var step := _walk_step(walls, occ, [px, py], [sx, sy], [bx, by], w, h)
		if step != "":
			return step
	return ""

# --- helpers -----------------------------------------------------------------------------------

func _nearest_zone(b: Dictionary, zones: Array, occ: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var bd := 1 << 30
	for z in zones:
		if int(z["kind"]) != int(b["kind"]):
			continue
		var zk := _key(int(z["pos"][0]), int(z["pos"][1]))
		if occ.has(zk) and not (int(z["pos"][0]) == int(b["pos"][0]) and int(z["pos"][1]) == int(b["pos"][1])):
			continue          # another crate already sits there
		var d := _md(b["pos"], z["pos"])
		if d < bd:
			bd = d
			best = z
	return best

func _md(a: Array, b: Array) -> int:
	return abs(int(a[0]) - int(b[0])) + abs(int(a[1]) - int(b[1]))

func _placed(b: Dictionary, zones: Array) -> bool:
	for z in zones:
		if int(z["pos"][0]) == int(b["pos"][0]) and int(z["pos"][1]) == int(b["pos"][1]) \
				and int(z["kind"]) == int(b["kind"]):
			return true
	return false

func _wall_set(state: Dictionary) -> Dictionary:
	var s := {}
	for wpt in state["walls"]:
		s[_key(int(wpt[0]), int(wpt[1]))] = true
	return s

func _occupancy(crates: Array) -> Dictionary:
	var o := {}
	for c in crates:
		o[_key(int(c["pos"][0]), int(c["pos"][1]))] = true
	return o

func _key(x: int, y: int) -> int:
	return x * 100 + y

func _solid(walls: Dictionary, occ: Dictionary, x: int, y: int, w: int, h: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return true
	var k := _key(x, y)
	return walls.has(k) or occ.has(k)

# One walking step from `from` toward `to`, around walls and every crate (the crate being pushed
# is a solid obstacle for walking too). "" when unreachable.
func _walk_step(walls: Dictionary, occ: Dictionary, from: Array, to: Array, bpos: Array,
		w: int, h: int) -> String:
	var start := _key(int(from[0]), int(from[1]))
	var goal := _key(int(to[0]), int(to[1]))
	if start == goal:
		return ""
	if _solid(walls, occ, int(to[0]), int(to[1]), w, h):
		return ""
	var came := {}
	came[start] = ""
	var q: Array = [from]
	var qi := 0
	while qi < q.size():
		var c: Array = q[qi]
		qi += 1
		var ck := _key(int(c[0]), int(c[1]))
		for dname in DIRS:
			var d: Array = DIRS[dname]
			var nx := int(c[0]) + int(d[0])
			var ny := int(c[1]) + int(d[1])
			var k := _key(nx, ny)
			if came.has(k):
				continue
			if _solid(walls, occ, nx, ny, w, h):
				continue
			came[k] = dname if String(came[ck]) == "" else came[ck]
			if k == goal:
				return came[k]
			q.append([nx, ny])
	return ""

func _less(a: Array, b: Array) -> bool:
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false
