extends RefCounted
#
# NAIVE reference controller for atom_move_slide_3d (red-team best-effort).
# Passes BASELINE (clear corridor); FAILS every obstacle scenario.
#
# It is a competent flat-ground mover: it heads straight for the goal each frame and stops on it.
# What it lacks is terrain response -- it never jumps and never steers around a blocker. So the
# moment the corridor puts anything in the way (a knee-high step it would have to jump, or a wall it
# would have to walk around) it drives into the obstacle and wedges there: move_and_slide kills its
# forward velocity and it sits pinned against the blocker until the budget runs out (never_arrived).
# This is the "wrote movement, forgot obstacles" incremental-engineering gap.

const ARRIVE_STOP := 0.6

func decide(state: Dictionary) -> Dictionary:
	var pos: Vector3 = state["self_pos"]
	var goal: Vector3 = state["goal_pos"]
	var to_goal := Vector3(goal.x - pos.x, 0.0, goal.z - pos.z)
	var dist := to_goal.length()
	if dist < ARRIVE_STOP:
		return {"move": Vector3.ZERO, "jump": false}
	return {"move": to_goal / dist, "jump": false}
