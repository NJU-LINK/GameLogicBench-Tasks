extends RefCounted
#
# NAIVE reference controller for atom_plan_orchestrator.
# Passes on BASELINE, fails on the hidden scenarios — an eager reactive controller that a plausible
# first attempt might write: it reads the goal board and reacts each tick, but lacks the disciplines
# the orchestrator needs:
#   * no commitment    — re-picks the argmax goal every tick, so priority_flip makes it thrash
#                        between keep_warm and keep_fed, completing neither  -> unjustified_switch
#   * bail weighing backwards — it does compute how much firepit work is left and compare it against
#                        the countdown, but draws the wrong conclusion from it: when the work will
#                        not fit it pushes on anyway ("running won't save me either"), and when it
#                        will fit it runs first and means to come back
#                                                                          -> commit_vs_bail
#   * no mid-chop re-check — a chop already under way is pushed to completion for its own wood, so
#                        when the tree closes mid-chop it keeps chopping thin air -> stale_plan
#   * no feasibility skip — commands the highest VALID goal even when its resource is sealed, so in
#                        sealed_goal it chops a vanished tree                -> infeasible_commit

func decide(state: Dictionary) -> Dictionary:
	var s: Dictionary = state["self"]
	var res: Dictionary = state["resources"]
	var threat = state["threat"]
	var cur := String(s["current_action"])

	# 1. Emergency: a threat is up and we are not sheltered. If the fire cannot be lit before the
	# threat lands, running is no help either -- push on. If it can, get to cover first and come
	# back to the firepit afterwards.
	if threat != null and not bool(s["in_cover"]):
		var on_firepit := cur == "chop_wood" or cur == "build_firepit" or bool(s["has_wood"])
		if on_firepit and _goal_valid(state, "keep_warm"):
			var tti := int(threat["time_to_impact"])
			var flee_d := int(res["flee_duration"])
			if _remaining_firepit(state) + flee_d > tti:
				return {"action": _firepit_next(state, res)}
		return {"action": "flee"}

	# 2. A chop already under way is worth finishing -- abandoning it throws away the ticks spent.
	if cur == "chop_wood" and _goal_valid(state, "keep_warm"):
		return {"action": "chop_wood"}

	# 3. Select: highest-priority VALID goal each tick (no commitment, no feasibility skip).
	var best := ""
	var best_pri := -1
	for goal in state["goals"]:
		if not bool(goal["valid"]):
			continue
		if goal["name"] == "stay_safe":
			continue
		if int(goal["priority"]) > best_pri:
			best_pri = int(goal["priority"])
			best = String(goal["name"])
	if best == "":
		return {"action": "idle"}
	return {"action": _plan_next(state, res, best)}

# --- helpers ---
func _goal_valid(state: Dictionary, name: String) -> bool:
	for g in state["goals"]:
		if g["name"] == name:
			return bool(g["valid"])
	return false

# Ticks still needed to light a firepit from the current progress.
func _remaining_firepit(state: Dictionary) -> int:
	var s: Dictionary = state["self"]
	var consts: Dictionary = state["consts"]
	var d_chop := int(consts["d_chop"])
	var d_build := int(consts["d_build"])
	var cur := String(s["current_action"])
	var prog := int(s["action_progress"])
	if cur == "build_firepit":
		return d_build - prog
	if bool(s["has_wood"]):
		return d_build
	if cur == "chop_wood":
		return (d_chop - prog) + d_build
	return d_chop + d_build

func _plan_next(state: Dictionary, res: Dictionary, goal: String) -> String:
	match goal:
		"keep_warm":
			return _firepit_next(state, res)
		"keep_fed":
			return "gather_food"
		"stay_safe":
			return "flee"
		_:
			return "idle"

func _firepit_next(state: Dictionary, res: Dictionary) -> String:
	# already building? keep building. else chop (get wood) before build; if wood in hand, build.
	if String(state["self"]["current_action"]) == "build_firepit":
		return "build_firepit"
	return "build_firepit" if bool(state["self"]["has_wood"]) else "chop_wood"
