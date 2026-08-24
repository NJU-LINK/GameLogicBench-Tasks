extends RefCounted
#
# NAIVE reference controller -- passes while unit paths do not cross, FAILS when they must
# interpenetrate.
#
# It does the "obvious" things: each unit steers straight at its goal and adds a simple repulsion
# from nearby units (classic boids-style separation) to try to keep apart. This is a genuine
# hand-rolled avoidance attempt -- it just isn't reciprocal. Its weakness, which this task exposes:
# when two units are head-on, the repulsion points straight back along the line joining them (no
# sideways component), so it only slows the closing -- it cannot decide which side to pass on. Under
# the seek force the units are driven together until their bodies overlap. On the public layout,
# where no paths cross, the repulsion never triggers and every unit reaches its goal.

const ARRIVE_EPS := 8.0
const SLOWDOWN := 50.0
const SEPARATION := 2.5           # repel from neighbours within this many radii

func setup(_state: Dictionary) -> void:
	pass

func on_tick(state: Dictionary) -> Vector2:
	var here: Vector2 = state["self_pos"]
	var goal: Vector2 = state["goal_pos"]
	var radius: float = state["radius"]
	var max_speed: float = state["max_speed"]

	var to_goal := goal - here
	var dist := to_goal.length()
	var seek := Vector2.ZERO
	if dist > ARRIVE_EPS:
		var speed: float = max_speed if dist > SLOWDOWN else max(max_speed * dist / SLOWDOWN, 20.0)
		seek = to_goal.normalized() * speed

	var push := Vector2.ZERO
	var reach := SEPARATION * radius
	for nb in state["neighbors"]:
		var off: Vector2 = here - (nb["pos"] as Vector2)
		var d := off.length()
		if d > 0.01 and d < reach:
			push += off.normalized() * (max_speed * (reach - d) / reach)

	var v := seek + push
	if v.length() > max_speed:
		v = v.normalized() * max_speed
	return v
