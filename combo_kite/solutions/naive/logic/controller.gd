extends RefCounted
#
# NAIVE reference controller -- the classic "it moves, ship it" pile of if-else. Each piece does
# the OBVIOUS thing that survives the baseline orchestration, and each piece carries the exact lazy
# shortcut its atom task calibrated:
#   * lock     : bare per-frame argmax over threat — no hysteresis (flips under ripple)
#   * movement : STRAIGHT-LINE toward the target — no nav query (clips obstacles when present)
#   * strikes  : paced at the HARDCODED 48-frame preview pace — ignores state.cooldown
#                (correct on baseline where cooldown=48; violates when hidden scenario changes it)
#   * kite     : no retreat at all — stands still after firing (kite loop never executed)
# In the gentle baseline orchestration (no obstacles, slow 1-chaser, cooldown=48) every shortcut
# coincidentally complies; hidden scenarios each arm one defect:
#   * move_navigation: a pillar / closing door blocks the straight-line path -> clipping/route_severed
#   * target_selection: AIM-1 ripple causes lock flip-flop -> target_thrash
#   * lunge: no retreat -> the struck chaser is still inside reach at the deadline -> lunged
#   * lunge_x_lock: no retreat AND bare argmax -> lunged / target_thrash (both armed axes)
#   * door_x_pace: hardcoded 48f pace after the forced detour -> cooldown_violation
# (the standalone kite / attack_cooldown death cells were retired 2026-07-27; those shortcuts now
#  surface on the lunge and door_x_pace cells respectively.)

const PREVIEW_COOLDOWN := 47.0 / 60.0  # hardcoded preview pace (ignores state.cooldown)
                                        # fires at 47f gap, just above baseline tolerance (48-2=46)
                                        # but below hidden cooldown tolerance (54-2=52)
const RANGE_MARGIN := 10.0

var _range := 120.0
var _time_since_hit := 1e9

func setup(state: Dictionary) -> void:
	_range = float(state["attack_range"])

func on_tick(state: Dictionary) -> Dictionary:
	_time_since_hit += float(state["dt"])
	var chasers: Array = state["chasers"]
	var here: Vector2 = state["self_pos"]

	# bare argmax lock, recomputed every frame (no hysteresis)
	var best := -1
	var best_t := -INF
	var cur := {}
	for ch in chasers:
		if float(ch["threat"]) > best_t:
			best_t = float(ch["threat"])
			best = int(ch["id"])
			cur = ch
	if best == -1:
		return {"move": Vector2.ZERO, "attack": false}

	var tpos: Vector2 = cur["pos"]
	var d: float = here.distance_to(tpos)

	# in range -> fire at hardcoded 47-frame pace (correct on baseline cd=48, violates on cd 54..90)
	if d <= _range - RANGE_MARGIN:
		if _time_since_hit >= PREVIEW_COOLDOWN:
			_time_since_hit = 0.0
			return {"move": Vector2.ZERO, "attack": true, "target": best}
		return {"move": Vector2.ZERO, "attack": false, "target": best}

	# walk STRAIGHT toward the target — no nav query
	return {"move": tpos - here, "attack": false, "target": best}
