extends RefCounted
#
# NAIVE solution: reactive dock-seeking with proportional slowdown and P-only pointing.
#
# It steers the velocity straight at the DOCK POINT (distance-proportional speed, gsai-arrive
# style) and points the nose at the dock normal with a plain proportional loop the whole flight.
# No hull-clearance phase, no braking-distance law, no spin-damping D term (it leans on the
# ship's reaction-wheel damper). This is the "every frame, re-read state and head for the goal"
# default: it docks on baseline-like setups where the geometry and the hardware are forgiving,
# and breaks one composed link at a time under each armed scenario:
#   * far_side / hug_wall : the straight chase line meets the hull -> hull_contact [clearance]
#   * hot_inbound         : proportional slowdown starts braking far too late under the lowered
#                           thrust cap -> hot_contact [inertial_arrive]
#   * tumble_start        : the damper is out and the P-only loop rings; the nose is still
#                           swinging at capture -> bad_attitude [attitude]

const SLOW_RADIUS := 120.0

func on_tick(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var vel: Vector2 = state["vel"]
	var dock: Vector2 = state["dock_pos"]
	var n: Vector2 = state["dock_normal"]
	var a_max: float = float(state["a_max"])
	var v_max: float = float(state["v_max"])
	var dt: float = float(state["dt"])

	var to_dock := dock - pos
	var d := to_dock.length()
	var desired_speed := v_max * clampf(d / SLOW_RADIUS, 0.0, 1.0)
	var desired_vel := Vector2.ZERO
	if d > 0.001:
		desired_vel = to_dock / d * desired_speed
	var thrust := ((desired_vel - vel) / dt).limit_length(a_max)

	# P-only pointing, no spin-damping D term (relies on the reaction-wheel damper)
	var herr := wrapf(n.angle() - float(state["heading"]), -PI, PI)
	var turn: float = clampf(herr * 8.0, -float(state["alpha_max"]), float(state["alpha_max"]))

	return {"thrust": thrust, "turn": turn}
