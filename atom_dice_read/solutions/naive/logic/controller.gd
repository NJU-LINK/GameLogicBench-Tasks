extends RefCounted
#
# NAIVE reference solution for atom_dice_read (red-team best-effort hand-rolled). Stronger than a
# textbook one-liner — it checks BOTH velocity bands, debounces, and reads faces with the correct
# orientation transform — but it carries two classic incremental-engineering defects:
#   * frame counting: the per-die debounce holds K FRAMES, not seconds of world time, so its real
#     duration silently shrinks when the physics ticks faster;
#   * per-die latch: once a die has held still for K frames it is marked settled FOREVER and never
#     re-checked — "that one's done" — so the report fires as soon as the LAST die's counter
#     completes, even if an earlier die has meanwhile been bumped back into motion, and a die that
#     merely paused (balanced mid-topple) is latched during the pause.
# Faces are read fresh at the report frame with the correct normal·UP rule.

const K := 12                                # frames a die must hold still to be latched settled

var _hold: Dictionary = {}                   # die id -> consecutive in-band frames
var _latched: Dictionary = {}                # die id -> true once it has held K frames

func on_tick(state: Dictionary) -> Dictionary:
	var dice: Array = state.get("dice", [])
	var v_eps: float = float(state.get("v_eps", 0.08))
	var w_eps: float = float(state.get("w_eps", 0.20))

	var all_latched := true
	for d in dice:
		var id := int(d["id"])
		if bool(_latched.get(id, false)):
			continue
		var lv: Vector3 = d["linear_velocity"]
		var av: Vector3 = d["angular_velocity"]
		if lv.length() < v_eps and av.length() < w_eps:
			_hold[id] = int(_hold.get(id, 0)) + 1
			if int(_hold[id]) >= K:
				_latched[id] = true
			else:
				all_latched = false
		else:
			_hold[id] = 0
			all_latched = false

	if not all_latched:
		return {"settled": false}

	var faces: Dictionary = {}
	for d in dice:
		faces[int(d["id"])] = _read_face(d["basis"], state.get("face_normals", []))
	return {"settled": true, "faces": faces}

func _read_face(basis: Basis, face_normals: Array) -> int:
	var best_val := 1
	var best_dot := -INF
	for f in face_normals:
		var world_n: Vector3 = (basis as Basis) * (f["normal"] as Vector3)
		var d := world_n.dot(Vector3.UP)
		if d > best_dot:
			best_dot = d
			best_val = int(f["value"])
	return best_val
