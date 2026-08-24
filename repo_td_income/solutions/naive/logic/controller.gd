extends RefCounted
#
# NAIVE reference solution (red team, made as strong as possible EXCEPT for three disciplines it
# lacks — the axes under test). It looks sensible and clears the gentle baseline, but:
#
#   FIRE (reactive, no in-flight ledger): every ready tower shoots the living LIGHT enemy with the
#     LOWEST CURRENT hp (ties -> nearest goal, then lowest id). It never subtracts the damage
#     already in flight, so several towers pile one tick's volley on the same target (leaks a dense
#     wave -> volley_split) and it keeps re-firing at a target already carrying lethal bolts
#     (overkill blows the ammo budget -> flight_debt). Ammo is bought for the CURRENT-hp demand
#     (same blind spot), which is exactly what funds the overkill.
#   PRODUCTION (parallel per-frame countdowns): every accepted shell gets its OWN countdown ticking
#     in FRAMES, all at once. With one shell queued this matches a serial factory, but a stacked
#     queue collapses the release times toward each item's own build time (early_release) and a
#     stretched timestep lags the world clock (late_release).
#   GOLD (build-leaning): it accepts every siege order it can afford (never weighing the front's
#     ammo need against it) and buys ammo with whatever gold is left — so when the front is the real
#     threat it has under-funded ammo (front leaks, arm_or_build).
#   AMMO HOARDING: while any light walks the lane it also keeps the magazine topped to four rounds
#     regardless of demand ("never be caught dry"). On the gentle baseline the purse is loose enough
#     that this costs nothing, but on a tight purse the hoard is spent before the siege orders arrive
#     and the heavies walk through (arm_or_build again, from the other side).

var _timers: Array = []           # [{kind, frames_left}] — ALL tick every frame (parallel build)

func on_tick(state: Dictionary) -> Dictionary:
	var enemies: Array = state["enemies"]
	var catalog: Dictionary = state["catalog"]
	var atk := int(state["towers"][0]["atk"])

	# --- FIRE: reactive lowest-CURRENT-hp light target (no in-flight accounting) ---
	var fire := {}
	for tower in state["towers"]:
		if int(tower["cd_remaining"]) != 0:
			continue
		var lo := int(tower["cover_lo"])
		var hi := int(tower["cover_hi"])
		var best := {}
		for e in enemies:
			if int(e["armor"]) != 0:
				continue
			if int(e["pos"]) < lo or int(e["pos"]) > hi:
				continue
			if best.is_empty() or int(e["hp"]) < int(best["hp"]) \
					or (int(e["hp"]) == int(best["hp"]) and int(e["pos"]) > int(best["pos"])) \
					or (int(e["hp"]) == int(best["hp"]) and int(e["pos"]) == int(best["pos"]) \
						and int(e["id"]) < int(best["id"])):
				best = e
		if not best.is_empty():
			fire[int(tower["id"])] = int(best["id"])

	# --- PRODUCTION: parallel per-frame countdowns; release whatever hits zero ---
	var produce: Array = []
	var placed_now: Array = []
	var still: Array = []
	for tm in _timers:
		tm["frames_left"] = int(tm["frames_left"]) - 1
		if int(tm["frames_left"]) <= 0:
			produce.append({"kind": tm["kind"], "pos": _find_spot(state, placed_now)})
			placed_now.append({"pos": produce[produce.size() - 1]["pos"]})
		else:
			still.append(tm)
	_timers = still

	# --- GOLD: build-leaning — accept every affordable siege order, buy ammo with the remainder ---
	var accept: Array = []
	var gold := int(state["gold"])
	var orders: Array = state["orders"]
	for i in orders.size():
		var o: Dictionary = orders[i]
		if String(o["op"]) == "enqueue":
			var kind := String(o["kind"])
			var price := int(catalog[kind]["price"])
			if _timers.size() < int(state["queue_cap"]) and gold >= price:
				accept.append(i)
				gold -= price
				_timers.append({"kind": kind, "frames_left": int(catalog[kind]["build_frames"])})
		else:   # cancel_head
			if not _timers.is_empty():
				accept.append(i)
				gold += int(catalog[String(_timers[0]["kind"])]["price"])
				_timers.pop_front()

	# --- AMMO: cover the CURRENT-hp demand of visible lights with the gold left after siege ---
	var demand := 0
	var lights_present := false
	for e in enemies:
		if int(e["armor"]) == 0:
			lights_present = true
			demand += int(ceil(float(e["hp"]) / float(atk)))
	var buy_ammo: int = max(0, demand - int(state["ammo"]))
	# never be caught dry: while lights walk, keep four rounds in the magazine
	if lights_present:
		buy_ammo = max(buy_ammo, 4 - int(state["ammo"]))
	var affordable := gold / int(state["ammo_price"])
	buy_ammo = min(buy_ammo, affordable)

	return {"fire": fire, "buy_ammo": buy_ammo, "accept": accept, "produce": produce}

func _find_spot(state: Dictionary, placed_now: Array) -> Vector2:
	var fpos: Vector2 = state["factory_pos"]
	var fhalf: Vector2 = state["factory_half"]
	var r := float(state["unit_radius"])
	var ring: float = fhalf.length() + r + 6.0
	while ring < 200.0:
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
	if p.x < r or p.y < r or p.x > float(state["world_w"]) - r or p.y > float(state["world_h"]) - r:
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
