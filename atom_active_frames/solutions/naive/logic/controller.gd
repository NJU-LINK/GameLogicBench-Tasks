extends RefCounted
#
# NAIVE reference controller — reacts when the target enters atk_range, then immediately declares
# the attack. This works on the baseline scenario (slow target; the active window opens while the
# target is still in range). On swift_pass the target moves so fast that, by the time the windup
# finishes, the target has already left atk_range — the active window catches nothing.
#
# The deliberate weakness: no lead-time calculation. The controller waits until it observes
# target_dist <= atk_range and only then declares the attack.

var _declared := false

func on_tick(state: Dictionary) -> Dictionary:
	if _declared:
		return {"attack": false}
	if int(state["attack_phase"]) != 0:
		return {"attack": false}

	var self_pos: Vector2 = state["self_pos"]
	var tpos: Vector2     = state["target_pos"]
	var atk_range: float  = float(state["atk_range"])

	if self_pos.distance_to(tpos) <= atk_range:
		_declared = true
		return {"attack": true}

	return {"attack": false}
