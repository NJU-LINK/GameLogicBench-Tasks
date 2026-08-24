extends RefCounted
#
# NAIVE solution (red team, made as strong as possible everywhere EXCEPT the core discipline): its
# escape direction is real (it dashes toward the roomier side of the lane, so the slide clears the
# ball on an honest throw) and it only fires when the dash is ready. What it also does — and this
# is the flaw — is TRUST THE THROWER'S BODY: the instant the thrower squares up (a wind-up), it
# dashes immediately instead of waiting for the ball to actually leave the hand. On an honest throw
# that head start is free (the aim locked onto where it stood, and it has already slid clear). But
# when the wind-up is a feint, the dash is burned and the dodger is still on cooldown when the real
# throw's aim locks onto its now-displaced position — the ball is faster than it can ever recover.

func on_tick(state: Dictionary) -> Dictionary:
	var vel: Vector2 = state["ball_vel"]
	if vel.length_squared() > 1e-6:
		# ball already flying — if somehow still ready, dash clear
		if bool(state["dash_ready"]):
			return {"dash": _escape_dir(state)}
		return {"dash": 0}
	# the thrower is squared up: react NOW, do not wait for the ball to leave the hand
	if String(state["thrower_phase"]) == "windup" and bool(state["dash_ready"]):
		return {"dash": _escape_dir(state)}
	return {"dash": 0}

func _escape_dir(state: Dictionary) -> int:
	var lane_pos: Vector2 = state["lane_pos"]
	var lane_size: Vector2 = state["lane_size"]
	var y: float = (state["self_pos"] as Vector2).y
	var lane_cy := lane_pos.y + lane_size.y * 0.5
	return -1 if y >= lane_cy else 1
