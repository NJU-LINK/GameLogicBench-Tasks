extends RefCounted
#
# NAIVE solution — the threat-first commander with a rule-of-thumb war chest. Every tick it reads the
# threat picture, tops each still-threatened region up to its wave's power and orders the single
# conduit earliest-deadline-first. On top of that it keeps one piece of economic doctrine: when the
# threat board looks LIGHT there is room in the conduit to put a profitable cut tail back on the
# network first, and when it looks HEAVY every gold piece goes to garrisons.
#
# Three shortcuts, every one of them free on the previewed campaign (one strongpoint, one late wave,
# an intact supply line):
#   1. SUPPLY. It never reads the supply map at all: it funds garrisons for cut regions too, and a
#      garrison funded for a cut region is never delivered.
#   2. INVESTMENT. "Invest when the bill is small" is a doctrine keyed to the demand side alone — it
#      never projects the funding schedule, so it invests exactly when a small bill is racing an
#      early wave (the repair squats the conduit head) and refuses exactly when a heavy bill can only
#      be met behind the income the repair would have bought.
#   3. ATTRIBUTION. Its investment candidate is just the cheapest broken line away from the fighting;
#      it never asks which repair actually reopens a tail.

const LIGHT_BILL := 3                    # garrison units at or below which the board looks "light"

func on_tick(state: Dictionary) -> Dictionary:
	var needs: Array = []                    # [{fund_by, cost, id}]
	for p in state["regions"]:
		if bool(p["razed"]):
			continue
		var w := _wave_of(state, int(p["id"]))
		if w.is_empty():
			continue
		var g := _garrison_for(state, int(p["id"]))
		if g.is_empty():
			continue
		var have := _have_garrison(state, int(p["id"]))
		var missing: int = maxi(0, int(w["power"]) - have)
		var n := int(ceil(float(missing) / float(g["value"]))) if missing > 0 else 0
		var fund_by: int = int(w["arrival"]) - int(g["build"])
		for _i in range(n):
			needs.append({"fund_by": fund_by, "cost": int(g["cost"]), "id": String(g["id"])})
	needs.sort_custom(func(a, b):
		if int(a["fund_by"]) != int(b["fund_by"]):
			return int(a["fund_by"]) < int(b["fund_by"])
		return int(a["cost"]) < int(b["cost"]))
	var queue: Array = []
	# a light board: buy the income first, at the head of the conduit, so the saving starts now.
	if needs.size() <= LIGHT_BILL:
		var inv := _income_relink(state)
		if inv != "":
			queue.append(inv)
	for nreq in needs:
		queue.append(String(nreq["id"]))
	return {"queue": queue}

# the cheapest broken line on offer that touches no threatened region — "a quiet tail, pure income".
func _income_relink(state: Dictionary) -> String:
	var threatened := {}
	for w in state["waves"]:
		threatened[int(w["target"])] = true
	var best := ""
	var best_cost := 1 << 30
	for c in state["catalog"]:
		if String(c["system"]) != "relink":
			continue
		var eid := int(c["edge"])
		if not _edge_broken(state, eid) or _relink_pending(state, eid):
			continue
		var quiet := true
		for e in state["edges"]:
			if int(e["id"]) != eid:
				continue
			if threatened.has(int(e["a"])) or threatened.has(int(e["b"])):
				quiet = false
		if quiet and int(c["cost"]) < best_cost:
			best_cost = int(c["cost"])
			best = String(c["id"])
	return best

func _relink_pending(state: Dictionary, eid: int) -> bool:
	for u in state["pending"]:
		if String(u["system"]) == "relink" and int(u["edge"]) == eid:
			return true
	return false

func _edge_broken(state: Dictionary, eid: int) -> bool:
	for e in state["edges"]:
		if int(e["id"]) == eid:
			return bool(e["broken"])
	return false

func _wave_of(state: Dictionary, rid: int) -> Dictionary:
	for w in state["waves"]:
		if int(w["target"]) == rid:
			return w
	return {}

# cheapest defense unit targeting this region.
func _garrison_for(state: Dictionary, rid: int) -> Dictionary:
	var best := {}
	for c in state["catalog"]:
		if String(c["system"]) != "defense" or int(c["target"]) != rid:
			continue
		if best.is_empty() or int(c["cost"]) < int(best["cost"]):
			best = c
	return best

# garrison delivered at the region plus garrison values still in the build pipeline for it.
func _have_garrison(state: Dictionary, rid: int) -> int:
	var cur := 0
	for p in state["regions"]:
		if int(p["id"]) == rid:
			cur = int(p["garrison"])
	var pend := 0
	for u in state["pending"]:
		if String(u["system"]) == "defense" and int(u["target"]) == rid:
			pend += int(u["value"])
	return cur + pend
