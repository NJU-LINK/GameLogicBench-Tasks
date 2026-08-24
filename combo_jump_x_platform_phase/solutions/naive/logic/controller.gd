extends RefCounted
#
# NAIVE reference controller for combo_jump_x_platform_phase.
#
# Two defects, both of the "it looked reasonable" kind:
#   * LAUNCH POINT: it launches from the middle of the start platform ("plenty of runway") instead
#     of walking out to the right edge, so the ballistic reach is short by the width of half a
#     platform.
#   * PHASE: instead of a flight-time lookahead it uses a coarse rhythm — "wait until the ferry is
#     heading my way, then go" — and commits the irreversible jump on that frame, with no
#     prediction of where the ferry will actually be when the flight ends.
# In the air it steers onto the ferry's live position and rides / steps off like the proper one.

const SPEED := 200.0
const JUMP_VEL := -400.0
const GRAVITY := 980.0
const DT := 1.0 / 60.0
const CHAR_R := 12.0

enum Phase { WALK, AIRBORNE, RIDE, STEPOFF, DONE }

var _phase: int = Phase.WALK

func _toward(from_x: float, to_x: float) -> float:
	var dd := to_x - from_x
	if absf(dd) < 3.0:
		return 0.0
	return 1.0 if dd > 0.0 else -1.0

func decide(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var on_floor: bool = state["is_on_floor"]
	var goal: Rect2 = state["goal_rect"]
	var platforms: Array = state["platforms"]
	var mp: Dictionary = state["moving_platform"]
	var plat_rect: Rect2 = mp["rect"]
	var plat_vel: Vector2 = mp["velocity"]
	var c := plat_rect.position.x + plat_rect.size.x * 0.5

	var start_rect: Rect2 = platforms[0]
	for p in platforms:
		var r: Rect2 = p
		if r.position.y < start_rect.position.y:
			start_rect = r

	if on_floor and pos.x >= goal.position.x and pos.x <= goal.position.x + goal.size.x \
			and absf(pos.y - (goal.position.y - CHAR_R)) <= 16.0:
		_phase = Phase.DONE
		return {"move": 0.0, "jump": false}
	if _phase == Phase.DONE:
		return {"move": 0.0, "jump": false}

	# DEFECT: launch from the middle of the start platform, not its right edge.
	var launch_target := start_rect.position.x + start_rect.size.x * 0.5

	match _phase:
		Phase.WALK:
			if not on_floor:
				return {"move": 0.0, "jump": false}
			if absf(pos.x - launch_target) > 3.0:
				return {"move": _toward(pos.x, launch_target), "jump": false}
			# DEFECT: coarse rhythm — go as soon as the ferry is heading my way, with no
			# prediction of where it will be when the flight ends.
			if plat_vel.x >= 0.0:
				return {"move": 0.0, "jump": false}
			_phase = Phase.AIRBORNE
			return {"move": 1.0, "jump": true}

		Phase.AIRBORNE:
			if on_floor:
				if pos.x >= plat_rect.position.x - 6.0 and pos.x <= plat_rect.position.x + plat_rect.size.x + 6.0 \
						and pos.y < goal.position.y - CHAR_R - 2.0:
					_phase = Phase.RIDE
					return {"move": 0.0, "jump": false}
				if pos.x >= goal.position.x and pos.x <= goal.position.x + goal.size.x:
					_phase = Phase.DONE
					return {"move": 0.0, "jump": false}
				return {"move": 0.0, "jump": false}
			return {"move": _toward(pos.x, c), "jump": false}

		Phase.RIDE:
			if not on_floor:
				_phase = Phase.AIRBORNE
				return {"move": 0.0, "jump": false}
			var plat_right_edge := plat_rect.position.x + plat_rect.size.x
			if plat_right_edge >= goal.position.x + 8.0:
				_phase = Phase.STEPOFF
				return {"move": 1.0, "jump": false}
			return {"move": _toward(pos.x, c), "jump": false}

		Phase.STEPOFF:
			if on_floor and pos.x >= goal.position.x and pos.x <= goal.position.x + goal.size.x \
					and pos.y > goal.position.y - CHAR_R - 6.0:
				_phase = Phase.DONE
				return {"move": 0.0, "jump": false}
			if on_floor and pos.x < goal.position.x - 20.0:
				_phase = Phase.RIDE
				return {"move": 0.0, "jump": false}
			return {"move": 1.0, "jump": false}

	return {"move": 0.0, "jump": false}
