extends RefCounted
#
# NAIVE reference controller -- "dispatch each crew to the nearest open slot; once it's parked,
# it's parked". A real, coherent dispatcher, not a strawman: every tick it sends each ordered crew
# member toward the NEAREST slot in its room that isn't already taken by a crew member IT BELIEVES
# has arrived, and it estimates arrival with a straight-line clock. Its defects all flow from that
# one lazy model:
#   * it reserves a slot only against crew it thinks are DONE, not against peers still in transit —
#     so two crew ordered in at the same instant both chase the same nearest slot   -> slot_contention
#   * it never counts a room's CAPACITY — it just keeps filling nearest slots         -> over_capacity
#   * it decides a crew member has "arrived" when its straight-line time is up and then stops
#     steering it, ignoring the door-open delay that is still holding it in a corridor -> door_delay
#   * once it marks a crew member arrived it LOCKS that slot and ignores any new order — the old
#     slot is never released                                                          -> reassign
# On the baseline (one crew per room, doors open, room to spare) none of these bite: distinct rooms,
# no capacity pressure, no door wait, no re-order — so every baseline cell passes.

const STEP := 120.0 / 60.0        # straight-line speed estimate (world units / tick); NOT gated on doors

var _target := {}                 # uid -> committed slot id
var _eta := {}                    # uid -> tick by which it "should" have arrived (straight-line)
var _done := {}                   # uid -> believes it has arrived (locks the slot, ignores re-orders)

func assign(state: Dictionary) -> Dictionary:
	var tick: int = int(state["tick"])
	var orders: Dictionary = state["orders"]
	var rooms: Array = state["rooms"]

	# slots believed occupied = those held by crew this controller thinks are done.
	var taken := {}
	for uid in _done:
		if bool(_done[uid]) and _target.has(uid):
			taken[int(_target[uid])] = true

	var out := {}
	for u in state["units"]:
		var uid := int(u["id"])

		# already "arrived": hold in place, keep the slot, ignore any new order.
		if bool(_done.get(uid, false)):
			out[uid] = -1
			continue

		if not orders.has(uid):
			out[uid] = -1
			continue

		var rid := int(orders[uid])
		var room := _room(rooms, rid)
		if room.is_empty():
			out[uid] = -1
			continue

		# nearest slot in the room that isn't held by a crew member we think is done.
		var here := float(u["x"])
		var best := -1
		var best_d := INF
		var best_x := 0.0
		for s in room["slots"]:
			var sid := int(s["id"])
			if taken.has(sid):
				continue
			var d: float = absf(here - float(s["x"]))
			if d < best_d:
				best_d = d
				best = sid
				best_x = float(s["x"])
		if best == -1:
			out[uid] = -1
			continue

		# (re)commit the target; reset the straight-line clock when the target changes.
		if int(_target.get(uid, -999)) != best:
			_target[uid] = best
			_eta[uid] = tick + int(ceil(best_d / STEP))
		out[uid] = best

		# straight-line clock elapsed -> believe we're parked (locks the slot from here on).
		if tick >= int(_eta[uid]):
			_done[uid] = true
			out[uid] = -1
	return out

func _room(rooms: Array, rid: int) -> Dictionary:
	for r in rooms:
		if int(r["id"]) == rid:
			return r
	return {}
