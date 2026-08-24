extends RefCounted
#
# NAIVE reference controller for repo_damage_control — the "fight-only, lazy-dispatch" foil (ONE
# instance). Target: PASS baseline, FAIL every hidden axis on-axis. It is a coherent officer missing
# every strategic lever this task rewards:
#   * it NEVER seals a door (seal left empty) — so a fire it can't reach spreads freely      -> fire_control
#   * it CHASES fire: any crew near an active fire is marched into that room to fight it, with no
#     oxygen check — so it walks crew into failing air                                       -> crew_safety
#   * for crew with no fire to chase it does lazy slot dispatch: nearest open slot in the ordered
#     room, reserving only against crew it BELIEVES have arrived (a straight-line clock), never
#     counting capacity, locking a slot on believed-arrival and ignoring re-orders — the four
#     crew_slots defects flow from that one lazy model  -> over_capacity/slot_contention/door_delay/reassign
# On the baseline (one crew per room, no fire, doors open, room to spare) none of these bite.

const STEP := 120.0 / 60.0        # straight-line speed estimate (world units/tick); NOT gated on doors

var _target := {}                 # uid -> committed slot id (for the dispatch branch)
var _eta := {}                    # uid -> tick it "should" have arrived (straight-line)
var _done := {}                   # uid -> believes arrived (locks slot, ignores re-orders)
var _fire_commit := {}            # uid -> fire room it committed to marching into (keeps going in)

func on_tick(state: Dictionary) -> Dictionary:
	var tick: int = int(state["tick"])
	var orders: Dictionary = state["orders"]
	var rooms: Array = state["rooms"]

	# active fires, nearest-first per crew handled below
	var fire_rooms: Array = []
	for r in rooms:
		if float(r["fire"]) > 0.0:
			fire_rooms.append(int(r["id"]))
	fire_rooms.sort()

	# slots believed occupied = held by crew this controller thinks are done.
	var taken := {}
	for uid in _done:
		if bool(_done[uid]) and _target.has(uid):
			taken[int(_target[uid])] = true

	# fire rooms already claimed (by a crew already committed to marching in).
	var taken_fire := {}
	for uid in _fire_commit:
		taken_fire[int(_fire_commit[uid])] = true

	var crew_cmd := {}
	for u in state["units"]:
		var uid := int(u["id"])
		var here := float(u["x"])

		# already committed to a fire room: keep marching in (a dispatched crew doesn't turn back
		# just because the fire drops — it walks into the room and, if the air is failing, dies).
		if _fire_commit.has(uid):
			crew_cmd[uid] = _nearest_slot(rooms, int(_fire_commit[uid]), here)
			continue

		# already "arrived" (dispatch branch): hold, keep slot, ignore new orders.
		if bool(_done.get(uid, false)):
			crew_cmd[uid] = -1
			continue

		# 1) chase the nearest untaken fire (ignore oxygen) — the fight-only reflex; commit to it.
		var f_target := -1
		var f_slot := -1
		var f_best := INF
		for rid in fire_rooms:
			if taken_fire.has(rid):
				continue
			var slot := _nearest_slot(rooms, rid, here)
			if slot < 0:
				continue
			var d: float = absf(here - _slot_x(rooms, slot))
			if d < f_best:
				f_best = d
				f_target = rid
				f_slot = slot
		if f_target != -1:
			taken_fire[f_target] = true
			_fire_commit[uid] = f_target
			crew_cmd[uid] = f_slot            # march into the fire room (no o2 check, keep steering)
			continue

		# 2) no fire to chase -> lazy nearest-open-slot dispatch in the ordered room.
		if not orders.has(uid):
			crew_cmd[uid] = -1
			continue
		var rid := int(orders[uid])
		var room := _room(rooms, rid)
		if room.is_empty():
			crew_cmd[uid] = -1
			continue
		var best := -1
		var best_d := INF
		for s in room["slots"]:
			var sid := int(s["id"])
			if taken.has(sid):
				continue
			var d: float = absf(here - float(s["x"]))
			if d < best_d:
				best_d = d
				best = sid
		if best == -1:
			crew_cmd[uid] = -1
			continue
		if int(_target.get(uid, -999)) != best:
			_target[uid] = best
			_eta[uid] = tick + int(ceil(best_d / STEP))
		crew_cmd[uid] = best
		if tick >= int(_eta[uid]):
			_done[uid] = true             # believe parked -> lock slot, stop steering
			crew_cmd[uid] = -1
	return {"seal": {}, "crew": crew_cmd}

func _room(rooms: Array, rid: int) -> Dictionary:
	for r in rooms:
		if int(r["id"]) == rid:
			return r
	return {}

func _nearest_slot(rooms: Array, rid: int, x: float) -> int:
	var room := _room(rooms, rid)
	if room.is_empty():
		return -1
	var best := -1
	var best_d := INF
	for s in room["slots"]:
		var d: float = absf(x - float(s["x"]))
		if d < best_d:
			best_d = d
			best = int(s["id"])
	return best

func _slot_x(rooms: Array, sid: int) -> float:
	for r in rooms:
		for s in r["slots"]:
			if int(s["id"]) == sid:
				return float(s["x"])
	return 0.0
