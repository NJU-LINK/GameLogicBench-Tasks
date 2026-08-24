extends RefCounted
#
# NAIVE reference controller -- the "see it, chase it; lose it, go home" version. It reads the world
# correctly every frame — it even casts sight rays, so it never hunts a ghost — and it chases and
# closes cleanly. Its ONE lazy shortcut is the search phase: the instant its quarry drops out of
# sight, it treats the pursuit as over and turns straight back for the post. It keeps NO memory of
# where the quarry was and makes NO distinction between "slipped behind cover, still right there"
# and "gone for good". Fine on the open baseline watch, where a quarry is only ever lost by running
# out of range and heading home IS the right call — but when the quarry ducks behind cover in range,
# the guard abandons the search at the wall's edge instead of committing to the last-known spot.
#
#   * perception : correct — vision_range AND a sight ray against the walls (atom_line_of_sight).
#   * movement   : walks STRAIGHT at wherever it wants to go (chase or home), trusting the open
#                  field (atom_move_navigation's "plan once, geometry won't surprise me").
#   * search     : ABSENT — no last-known memory, no commit; lose sight -> straight home.

func on_tick(state: Dictionary) -> Dictionary:
	var here: Vector2 = state["self_pos"]
	var post: Vector2 = state["post_pos"]
	var vision: float = float(state["vision_range"])
	var world: Node2D = state["world"]
	var space := world.get_world_2d().direct_space_state

	# correct raycast visibility (never a ghost chase)
	var visible: Array = []
	for ent in state["entities"]:
		var p: Vector2 = ent["pos"]
		if here.distance_to(p) > vision:
			continue
		var q := PhysicsRayQueryParameters2D.create(here, p)
		if space.intersect_ray(q).is_empty():
			visible.append(ent)

	# chase the nearest one we can see
	var quarry := {}
	for ent in visible:
		if quarry.is_empty() or here.distance_to(ent["pos"]) < here.distance_to(quarry["pos"]):
			quarry = ent

	if not quarry.is_empty():
		var tpos: Vector2 = quarry["pos"]
		if here.distance_to(tpos) > 70.0:
			return {"move": tpos - here, "chasing": int(quarry["id"])}
		return {"move": Vector2.ZERO, "chasing": int(quarry["id"])}

	# nobody visible -> straight line home (no search, no memory)
	if here.distance_to(post) > 6.0:
		return {"move": post - here, "chasing": -1}
	return {"move": Vector2.ZERO, "chasing": -1}
