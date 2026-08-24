extends RefCounted
#
# NAIVE reference controller -- the "it grapples, ship it" version. It throws whenever the
# opponent is in reach and it MASHES tech (presses tech every frame it is grabbed, on the intuition
# that pressing harder escapes faster). On a passive opponent (baseline) both behaviours are exactly
# right: it walks up, throws on cadence, wins.
#
# THREE latent defects, each dormant until its scenario arms it:
#   * it never reads opp_phase before throwing -> against a CONTESTER (same_frame) every throw
#     collides with the opponent's throw on the same frame and TRADES; the quota is never met.
#   * it throws a LIVE opponent -> against an opponent that techs a grab it can still defend
#     (grab_tech) every grab is teched out and no throw ever lands (grab_denied).
#   * it MASHES tech -> against a GRAPPLER (grab_lockout) the first press burns the lockout, so when
#     the real tech window arrives it is still locked and it gets thrown, repeatedly, over budget.

func setup(_state: Dictionary) -> void:
	pass

func on_tick(state: Dictionary) -> Dictionary:
	if int(state["self_stagger_remaining"]) > 0:
		return {"action": "none"}

	# grabbed: mash tech every frame (the defect).
	if bool(state["grabbed"]):
		return {"action": "tech"}

	if int(state["self_phase"]) != 0:
		return {"action": "none"}

	# throw whenever the opponent is in reach -- never checks whether it can be contested.
	var self_pos: Vector2 = state["self_pos"]
	var opp_pos: Vector2 = state["opp_pos"]
	if self_pos.distance_to(opp_pos) <= float(state["throw_range"]):
		return {"action": "throw"}
	return {"action": "none"}
