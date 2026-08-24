extends RefCounted
#
# NAIVE reference controller for atom_platform_ride.
# Passes ALL BASELINE seeds, FAILS ALL SWIFT_FERRY seeds.
#
# Strategy: jump on the very first available is_on_floor frame (no waiting).
# Does NOT read state.moving_platform.
#
# On baseline (slow platform, gap 130-160, plat starts at mid-travel):
# The platform's mid-travel position is geometrically near the jump landing point.
# A frame-0 jump from start center lands directly on the platform → always passes.
#
# On swift_ferry (fast platform, starts at right end moving left):
# At jump time (frame 0), the platform is at the far right end. The jump landing
# falls short of the platform's left edge → always fell.

var _jumped := false
var _reached_goal := false

func decide(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var on_floor: bool = state["is_on_floor"]
	var goal_rect: Rect2 = state["goal_rect"]

	# Stop if on goal static platform (y > 340 filters out moving platform)
	if on_floor and pos.x >= goal_rect.position.x \
			and pos.x <= goal_rect.position.x + goal_rect.size.x \
			and pos.y > 340.0:
		_reached_goal = true
	if _reached_goal:
		return {"move": 0.0, "jump": false}

	# Jump on the very first is_on_floor frame (no position check, no timing)
	var do_jump := on_floor and not _jumped
	if do_jump:
		_jumped = true

	# After jump: move right. Before: move right too (walk to right edge for better reach)
	return {"move": 1.0, "jump": do_jump}
