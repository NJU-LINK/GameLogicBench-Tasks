extends RefCounted
#
# NAIVE reference controller for atom_jump_landing.
# Passes on BASELINE (small gap), FAILS on WIDE_GAPS (large gap, goal higher).
#
# Weakness: jumps immediately when is_on_floor (first available frame), from wherever
# it is (start center). For baseline the gap is small enough that center-launch reaches
# the goal. For wide_gaps the gap is larger (140-180) and the goal is higher, so a
# center-launch falls short — the proper controller walks to the right edge before jumping.
#
# This exposes the is_on_floor timing trap: the naive controller DOES gate on is_on_floor,
# but in the right way only accidentally (too early, wrong position). A deeper naive would
# be a pure timer that doesn't even gate — that fails even worse; this version shows the
# "partial gating" failure mode (correct gate, wrong position).
#
# Second shortcut: on arrival it only stops jumping, it never brakes — it keeps walking right
# across the goal platform. On a wide goal there is plenty of platform left to stand the landing
# out; on a narrow one it strolls off the far edge before the arrival dwell completes.

var _jumped := false

func decide(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var on_floor: bool = state["is_on_floor"]
	var goal_rect: Rect2 = state["goal_rect"]

	# Reached the goal platform (approximate check: x in range, is_on_floor) -- stop jumping.
	if on_floor and pos.x >= goal_rect.position.x and pos.x <= goal_rect.position.x + goal_rect.size.x:
		return {"move": 1.0, "jump": false}

	# Jump on the very first is_on_floor frame (no position optimization)
	var do_jump := on_floor and not _jumped
	if do_jump:
		_jumped = true

	return {"move": 1.0, "jump": do_jump}
