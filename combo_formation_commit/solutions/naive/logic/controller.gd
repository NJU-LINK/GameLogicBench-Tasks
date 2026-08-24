extends RefCounted
#
# NAIVE reference solution — the strongest static template that never reads the opposing roster:
# one line down the zone's forward column, every unit shoulder to shoulder in id order, laid out
# identically for every opponent. Everyone is a front-liner; the archers stand on the contact
# column too, so nothing is held in reserve and every body contributes its damage immediately.
#
# It is good enough against a token frontal fight (baseline: two lone knights die to seven bodies
# from any layout). It never looks at what it is facing, so:
#   * a real melee mass walks straight into the archers standing on the contact column;
#   * divers reach the fragile units with nothing sealing them;
#   * splash casters find one packed column and bleed the whole line with collateral.

func plan_formation(state: Dictionary) -> Dictionary:
	var zone: Dictionary = state["deploy_zone"]
	var xf := int(zone["x_max"])          # front column
	var y := int(zone["y_min"])

	var f := {}
	for u in state["allies"]:
		f[int(u["id"])] = [xf, y]
		y += 1
	return f
