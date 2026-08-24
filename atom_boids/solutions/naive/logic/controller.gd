extends RefCounted
#
# NAIVE reference controller -- the "obvious" two-force attempt; passes the small gentle baseline,
# FAILS the held-out scenarios.
#
# It does the two things that look sufficient: each unit SEEKS the anchor (easing as it arrives so
# it does not ram the point) and adds a proximity-scaled radial REPULSION from close neighbours to
# keep apart. It returns that velocity directly. This is a genuine hand-rolled attempt -- it just
# isn't a complete flock. What it lacks, which this task exposes:
#   * no ALIGNMENT and no velocity smoothing -> on sharp turns every unit snaps toward the anchor
#     independently, the group overshoots and oscillates rather than turning as one.
#   * no group COHESION and a seek that always points at ONE anchor point -> a large or compressed
#     flock all crowds the same spot; radial repulsion, which partly cancels in a dense interior,
#     cannot pack it without interpenetrating.
# On the small, gently-moving baseline the flock stays loose enough that neither bites.

const SEP_REACH := 34           # repel from neighbours within this distance
const SEP_STR := 150            # repulsion strength (linear ramp; strong near contact)
const ARRIVE_R := 58            # ease the seek within this distance of the anchor

func on_tick(state: Dictionary) -> Vector2:
	var here: Vector2 = state["self_pos"]
	var anchor: Vector2 = state["anchor_pos"]
	var max_speed: float = state["max_speed"]

	# seek the anchor, easing as it arrives
	var to_anchor := anchor - here
	var da := to_anchor.length()
	var seek := Vector2.ZERO
	if da > 1.0:
		var s: float = max_speed if da > ARRIVE_R else max_speed * da / ARRIVE_R
		seek = to_anchor.normalized() * s

	# proximity-scaled radial repulsion from close neighbours
	var push := Vector2.ZERO
	for nb in state["neighbors"]:
		var off: Vector2 = here - (nb["pos"] as Vector2)
		var d := off.length()
		if d > 0.01 and d < SEP_REACH:
			push += off.normalized() * (SEP_STR * (SEP_REACH - d) / SEP_REACH)

	var v := seek + push
	if v.length() > max_speed:
		v = v.normalized() * max_speed
	return v
