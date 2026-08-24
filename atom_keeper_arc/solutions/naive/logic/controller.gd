extends RefCounted
#
# NAIVE solution (red team, made as strong as possible everywhere EXCEPT the core discipline):
# it does the obvious thing while the ball is being dribbled — square up to the ball at the deep
# edge of the box, mirroring its x so it is always directly between the ball and its own line —
# and once the ball is in flight it attacks the true shot line.
# What it also does — and this is the flaw — is TRUST the attacker's body: the moment the
# attacker squares up (a wind-up, aim readable from shooter_facing), it dives for the aimed shot
# line immediately instead of waiting for the ball to actually leave the foot. When a wind-up is
# genuine that head start is free saving; when the wind-up is pulled back and the strike goes the
# other way, the keeper has committed its whole body the wrong side and the ball is faster than
# it can ever recover.
# Its other shortcut is that the dive is a commitment: once it has read a wind-up and started
# moving for that line, it stays on that read for the rest of the attack rather than re-hedging
# every frame — a keeper that changes its mind mid-dive arrives nowhere.

var _committed := false
var _aim := Vector2.ZERO
var _aim_ball := Vector2.ZERO

func on_tick(state: Dictionary) -> Dictionary:
	var ball: Vector2 = state["ball_pos"]
	var vel: Vector2 = state["ball_vel"]
	var phase := String(state["shooter_phase"])
	if phase == "dribble":
		_committed = false          # the attack is over; back to reading the ball

	if vel.length_squared() > 1e-6:
		if not _committed:
			return {"move": _to_shot_line(state["self_pos"], ball, vel)}
		# already diving on the read we made -- hold that line
		return {"move": _to_shot_line(state["self_pos"], _aim_ball, _aim)}
	if phase == "windup" or _committed:
		# the attacker is squared up: shooter_facing is its aim — get on that line NOW and stay
		if not _committed:
			var aim: Vector2 = state["shooter_facing"]
			if aim.length_squared() <= 1e-6:
				return {"move": _to_mirror(state, ball)}
			_aim = aim
			_aim_ball = ball
			_committed = true
		return {"move": _to_shot_line(state["self_pos"], _aim_ball, _aim)}
	return {"move": _to_mirror(state, ball)}

# Closest point on the (anticipated or actual) shot ray to the keeper; head straight for it.
func _to_shot_line(kp: Vector2, ball: Vector2, dir: Vector2) -> Vector2:
	var d := dir.normalized()
	var s := maxf(0.0, (kp - ball).dot(d))
	return (ball + d * s) - kp

# Square to the ball's x, standing on the goal line.
func _to_mirror(state: Dictionary, ball: Vector2) -> Vector2:
	var box_pos: Vector2 = state["box_pos"]
	var box_size: Vector2 = state["box_size"]
	var target := Vector2(clampf(ball.x, box_pos.x, box_pos.x + box_size.x), box_pos.y)
	return target - state["self_pos"]
