extends RefCounted
#
# NAIVE solution (red team, made as strong as possible except for BOTH core disciplines). It attacks
# the true pass line once the ball is in flight, but it carries two lazy shortcuts at once:
#   * positioning: it CHASES THE BALL — parks under the ball's x at the deep edge, never accounting
#     for where the two receivers actually are or which is dangerous;
#   * commit: instead of waiting for the ball to leave the foot it waits for the wind-up to LOOK
#     SERIOUS — after half a second squared up it decides the aim must be real and dives onto the
#     aimed line ("nobody holds a fake for half a second").
# On the gentle baseline both are free; under the hidden drills either one alone concedes — the chase
# loses the wide lane (lane_cover), the patient bite is stranded by a long pump-fake (keeper_arc).

const PATIENCE := 30                      # frames of squared-up wind-up before we "know" it is real

var _wu_frames := 0

func on_tick(state: Dictionary) -> Dictionary:
	var ball: Vector2 = state["ball_pos"]
	var vel: Vector2 = state["ball_vel"]
	if vel.length_squared() > 1e-6:
		_wu_frames = 0
		return {"move": _to_line(state["self_pos"], ball, vel)}
	if String(state["passer_phase"]) == "windup":
		_wu_frames += 1
	else:
		_wu_frames = 0                    # a pull-back resets the clock
	if _wu_frames >= PATIENCE:
		var aim: Vector2 = state["passer_facing"]
		if aim.length_squared() > 1e-6:
			return {"move": _to_line(state["self_pos"], ball, aim)}   # bite the long aim
	return {"move": _chase_ball(state, ball)}

func _to_line(kp: Vector2, ball: Vector2, dir: Vector2) -> Vector2:
	var d := dir.normalized()
	var s := maxf(0.0, (kp - ball).dot(d))
	return (ball + d * s) - kp

# Mirror the ball's x at the box's deep edge (no receiver awareness at all).
func _chase_ball(state: Dictionary, ball: Vector2) -> Vector2:
	var box_pos: Vector2 = state["box_pos"]
	var box_size: Vector2 = state["box_size"]
	var deep_y := box_pos.y + box_size.y
	var tx := clampf(ball.x, box_pos.x, box_pos.x + box_size.x)
	return Vector2(tx, deep_y) - state["self_pos"]
