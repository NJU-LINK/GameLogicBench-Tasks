extends RefCounted
#
# NAIVE solution (red team, made as strong as possible everywhere EXCEPT the disciplines under
# test): units are placed legally by the same radial search as the proper solution, capacity is
# tracked against the live queue, and cancels are honored. Its two flaws are the classic ones a
# manager that only ever saw the sparse preview would ship:
#   (1) build progress is counted in FRAMES, not accumulated in world SECONDS — indistinguishable
#       from the reference at tick_scale 1.0, but under a stretched timestep the frame count lags
#       the world clock and releases land late (slow_tick).
#   (2) each order this frame is judged against the frame's STARTING funds — there is no running
#       ledger mirror, so within a single frame a later order does not see the money an earlier
#       accept spent (same_frame_spend -> overdraft) nor the money a cancel just refunded
#       (refund_reuse -> wrongful reject). With one order per frame (baseline / slow_tick) this is
#       invisible.
# (The per-item parallel countdown is legacy and no longer arms a scored axis — serial-vs-parallel
# is a trap frontier implementations pass, so the queue never stacks in a way that exposes it.)

var _timers: Array = []       # [{kind, frames_left}] — ALL tick every frame (parallel build)

func on_tick(state: Dictionary) -> Dictionary:
	var accept: Array = []
	var produce: Array = []
	var catalog: Dictionary = state["catalog"]

	# --- 1. tick every countdown in parallel; release whatever hits zero ---
	var placed_now: Array = []
	var still: Array = []
	for tm in _timers:
		tm["frames_left"] = int(tm["frames_left"]) - 1
		if int(tm["frames_left"]) <= 0:
			var pos := _find_spot(state, placed_now)
			produce.append({"kind": tm["kind"], "pos": pos})
			placed_now.append({"pos": pos})
		else:
			still.append(tm)
	_timers = still

	# --- 2. answer this frame's orders against the frame's STARTING funds (no running mirror) ---
	var funds := int(state["funds"])
	var orders: Array = state["orders"]
	for i in orders.size():
		var o: Dictionary = orders[i]
		if String(o["op"]) == "enqueue":
			var kind := String(o["kind"])
			var price := int(catalog[kind]["price"])
			if _timers.size() < int(state["queue_cap"]) and funds >= price:
				accept.append(i)
				_timers.append({"kind": kind,
					"frames_left": int(catalog[kind]["build_frames"])})
		else:   # cancel_head
			if not _timers.is_empty():
				accept.append(i)
				_timers.pop_front()

	return {"accept": accept, "produce": produce}

# Same legal-spot search as an honest manager would use.
func _find_spot(state: Dictionary, placed_now: Array) -> Vector2:
	var fpos: Vector2 = state["factory_pos"]
	var fhalf: Vector2 = state["factory_half"]
	var r := float(state["unit_radius"])
	var ring: float = fhalf.length() + r + 6.0
	while ring < 240.0:
		var n := int(maxf(8.0, TAU * ring / (2.4 * r)))
		for i in n:
			var ang := TAU * float(i) / float(n)
			var p := fpos + Vector2(cos(ang), sin(ang)) * ring
			if _spot_ok(p, state, placed_now, fpos, fhalf, r):
				return p
		ring += 2.2 * r
	return fpos + Vector2(fhalf.x + r + 6.0, 0.0)

func _spot_ok(p: Vector2, state: Dictionary, placed_now: Array, fpos: Vector2,
		fhalf: Vector2, r: float) -> bool:
	if p.x < r or p.y < r or p.x > float(state["world_w"]) - r \
			or p.y > float(state["world_h"]) - r:
		return false
	var rel := p - fpos
	if absf(rel.x) < fhalf.x + r and absf(rel.y) < fhalf.y + r:
		return false
	for u in state["units"]:
		if p.distance_to(u["pos"]) < 2.0 * r + 0.5:
			return false
	for u in placed_now:
		if p.distance_to(u["pos"]) < 2.0 * r + 0.5:
			return false
	return true
