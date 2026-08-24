extends RefCounted
#
# NAIVE reference: a strong-defence turtle. Every region recruits the cheapest unit to the
# garrison cap (maximise headcount) and simply holds. It NEVER develops (no industry /
# fortification / logistics), never researches technology, never repairs supply, never assigns
# generals, and never attacks. Reactive defence with zero strategic investment: it holds a
# gentle campaign where full infantry garrisons turn back the enemy, but it cannot repair a cut
# supply line, cannot storm a fortified objective, and cannot expand -- so it breaks wherever
# supply, quality, or tempo decides the war.


const GARRISON_CAP := 8


func plan_turn(state: Dictionary) -> Dictionary:
	var orders: Array = []
	var player := String(state.get("player", ""))
	var regions: Dictionary = state.get("regions", {})
	var ids: Array = regions.keys()
	ids.sort()
	for rid in ids:
		var r: Dictionary = regions[rid]
		if String(r.get("owner", "")) != player:
			continue
		var gsz: int = (r.get("garrison", []) as Array).size()
		for _i in range(GARRISON_CAP - gsz):
			orders.append({"kind": "recruit", "region": rid, "unit": "infantry"})
	return {"orders": orders}
