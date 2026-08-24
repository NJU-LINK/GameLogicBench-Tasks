extends RefCounted
#
# NAIVE reference controller for atom_move_navigation_3d (red-team best-effort).
# Passes BASELINE (one clear platform); FAILS every split-ground scenario.
#
# It is a competent flat-ground mover: it heads straight for the goal each frame. What it lacks is any
# awareness of the world's connectivity -- it never consults the navigation map, so it cannot know
# that the ground is split and that the only crossing is over a connector off to the side. The moment
# the layout puts a chasm between it and the goal, it walks straight off the walkable region into the
# gap (left_region) -- the "wrote movement, forgot the level topology" incremental-engineering gap.

func decide(state: Dictionary) -> Vector3:
	var pos: Vector3 = state["self_pos"]
	var goal: Vector3 = state["goal_pos"]
	return goal - pos
