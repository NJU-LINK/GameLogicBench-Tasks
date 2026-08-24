extends RefCounted
#
# NAIVE reference controller -- the classic "it fights, ship it" version. Two of the three
# lifecycle disciplines are handled right:
#   * pacing : reads state.cooldown and waits it out plus a margin (cooldown FLOOR respected)
#   * stagger: re-reads state.hitstun_remaining every frame and holds while staggered (refresh-safe)
# Its defect: it treats every ready+in-reach frame as a green light. It swings when the rival is in
# reach RIGHT NOW rather than declaring the attack windup_frames before the rival arrives; it never
# reads the rival's neutral/commit state (rival_phase), never reads the rival's guard
# (rival_guarding), and never pre-loads the next swing for a tight link (link_window). On a world
# whose rival parks in reach for a long dwell, never punishes, and imposes no guard or link
# (baseline) that is exactly the right move and every cell passes. Elsewhere it walks into all four
# disciplines:
#   * active_frames : reacting on arrival means the windup only opens after the rival has already
#                     swept out of reach -> the swing whiffs.
#   * cancel : swings while the counter-puncher stands ready -> counterblow cancels the windup.
#   * guard  : swings at the planted, guarded rival the moment its clocks clear -> parried.
#   * combo  : waits the cooldown out then swings -> the follow-up lands windup frames too late,
#              overshooting the link window -> combo dropped.

const CD_MARGIN_F := 4          # extra frames beyond the stated cooldown (same as proper)

func setup(_state: Dictionary) -> void:
	pass

func on_tick(state: Dictionary) -> Dictionary:
	var here: Vector2 = state["self_pos"]
	var rival: Vector2 = state["rival_pos"]
	var atk_range: float = float(state["atk_range"])

	# stagger discipline (correct)
	if float(state["hitstun_remaining"]) > 0.0:
		return {"attack": false}

	# committed already
	if int(state["self_phase"]) != 0:
		return {"attack": false}

	# cooldown pacing (correct: reads the state clock)
	if float(state["cooldown_remaining"]) > 0.0:
		return {"attack": false}

	# in reach right now -> swing (no lead, never checks rival_phase)
	if here.distance_to(rival) <= atk_range - 2.0:
		return {"attack": true}
	return {"attack": false}
