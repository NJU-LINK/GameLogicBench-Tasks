extends RefCounted
#
# NAIVE reference controller -- the "it patrols, ship it" version. Each piece does the obvious
# thing that survives the previewed setup, and each carries the exact lazy shortcut its atom task
# calibrated:
#   * perception : judges visibility by DISTANCE ONLY — never casts a ray against the walls
#                  (atom_line_of_sight's naive). Fine while whatever cover hides is out of range
#                  anyway; hunts ghosts when an in-range intruder slips behind the block.
#   * selection  : bare per-frame argmax over the threats of its "visible" set — no hysteresis
#                  (atom_target_selection's naive). Fine while threat gaps are wide.
#   * movement   : walks STRAIGHT at wherever it wants to go — chase or home — trusting the open
#                  field (atom_move_navigation's spirit of "plan once, geometry won't surprise
#                  me"). Fine while nothing stands between; clips when a return leg crosses the
#                  block.
# The return logic itself is present and correct (heads home when its "visible" set is empty), so
# every failure is attributable to one of the three shortcuts above.

func on_tick(state: Dictionary) -> Dictionary:
	var here: Vector2 = state["self_pos"]
	var post: Vector2 = state["post_pos"]
	var vision: float = float(state["vision_range"])

	# distance-only "visibility"
	var visible: Array = []
	for ent in state["entities"]:
		if here.distance_to(ent["pos"]) <= vision:
			visible.append(ent)

	# bare argmax over the visible threats
	var best := {}
	for ent in visible:
		if best.is_empty() or float(ent["threat"]) > float(best["threat"]):
			best = ent

	if not best.is_empty():
		var tpos: Vector2 = best["pos"]
		if here.distance_to(tpos) > 70.0:
			return {"move": tpos - here, "chasing": int(best["id"])}
		return {"move": Vector2.ZERO, "chasing": int(best["id"])}

	# nobody "visible" -> straight line home
	if here.distance_to(post) > 6.0:
		return {"move": post - here, "chasing": -1}
	return {"move": Vector2.ZERO, "chasing": -1}
