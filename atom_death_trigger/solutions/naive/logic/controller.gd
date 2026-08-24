extends RefCounted
#
# NAIVE reference controller -- passes in the previewed setup, FAILS when "nearly dead" and "dead"
# stop coinciding.
#
# It fights CORRECTLY (nearest live target, range margin, paces strikes against the stated
# cooldown) and it even handles the death sequence it saw in the preview correctly. Its one
# hand-rolled weakness -- the exact thing this task exposes -- is the death TEST: instead of
# treating exactly self_hp == 0 as death, it treats "critically low HP" (self_hp < LOW_HP_DEATH)
# as its dying moment: it fires its one-time death_ack and shuts down there. In the previewed
# setup the boss's HP steps 30 -> 20 -> 10 -> 0, so "below 10" first becomes true at the moment of
# actual death -- the guess is coincidentally right and the run passes. When the world instead
# parks the boss at a LOW-but-alive HP for a stretch of the fight, the guess fires while the boss
# is still alive -> death_ack_premature.

const LOW_HP_DEATH := 10.0             # "this low = as good as dead" guess; NOT the real rule
const COOLDOWN_MARGIN := 4.0 / 60.0    # seconds of extra wait beyond the stated cooldown
const RANGE_MARGIN := 8.0              # strike from this far inside attack_range

var _cooldown := 0.8
var _range := 60.0
var _time_since_hit := 1e9             # large so the first attack is allowed immediately
var _acked := false

func setup(state: Dictionary) -> void:
	_cooldown = float(state["cooldown"])
	_range = float(state["attack_range"])

func on_tick(state: Dictionary) -> Dictionary:
	# "Dying" by its own low-HP guess -> announce once and shut down.
	if float(state["self_hp"]) < LOW_HP_DEATH:
		if not _acked:
			_acked = true
			return {"move": Vector2.ZERO, "attack": false, "death_ack": true}
		return {"move": Vector2.ZERO, "attack": false}

	_time_since_hit += float(state["dt"])
	var here: Vector2 = state["self_pos"]

	var tgt := _nearest_alive(state["targets"], here)
	if tgt.is_empty():
		return {"move": Vector2.ZERO, "attack": false}

	var tpos: Vector2 = tgt["pos"]
	var d: float = here.distance_to(tpos)

	if d > _range - RANGE_MARGIN:
		return {"move": tpos - here, "attack": false}

	if _time_since_hit >= _cooldown + COOLDOWN_MARGIN:
		_time_since_hit = 0.0
		return {"move": Vector2.ZERO, "attack": int(tgt["id"])}
	return {"move": Vector2.ZERO, "attack": false}

func _nearest_alive(targets: Array, here: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for tgt in targets:
		if float(tgt["hp"]) <= 0.0:
			continue
		var d: float = here.distance_to(tgt["pos"])
		if d < best_d:
			best_d = d
			best = tgt
	return best
