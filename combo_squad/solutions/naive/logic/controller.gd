extends RefCounted
#
# NAIVE reference controller -- "it marches, ship it". Each piece does the obvious thing that
# survives the previewed setup, and each carries the exact lazy shortcut its atom task calibrated:
#   * plan   : reads its battle station ONCE at setup and marches to that cached goal (the obvious
#              "I know where I'm going" shortcut). Fine while the station never moves; parks at the
#              stale spot the moment the order is amended mid-march.
#   * march  : walks STRAIGHT at its station with a simple symmetric repulsion off nearby
#              squadmates (atom_group_avoidance's naive, verbatim spirit). Fine in parallel
#              lanes; deadlocks or overlaps when lanes cross.
#   * lock   : bare per-frame argmax over enemy threats — no hysteresis, no cross-unit
#              coordination (atom_target_selection's naive). Fine while one enemy is clearly the
#              hottest and each is covered by two units; piles the whole squad onto one target
#              when several units can reach the same enemy.
#   * strike : paced against a HARD-CODED 30-frame cadence — the cadence that works in the
#              previewed setup — instead of reading state.cooldown
#              (atom_attack_cooldown's naive). Fine while the world's cooldown is 30.

const HARDCODED_COOLDOWN := 30.0 / 60.0   # tuned to the preview; NOT read from state
const RANGE_MARGIN := 8.0
const REPULSE_DIST := 34.0                # start pushing off a squadmate inside this
const REPULSE_W := 0.9

var _time_since_hit := 1e9
var _station := Vector2.ZERO              # cached ONCE at setup -- never re-read

func setup(state: Dictionary) -> void:
	_station = state["station_pos"]

func on_tick(state: Dictionary) -> Dictionary:
	_time_since_hit += float(state["dt"])
	var here: Vector2 = state["self_pos"]
	var station: Vector2 = _station
	var speed: float = float(state["max_speed"])

	# bare argmax lock
	var best := {}
	for en in state["enemies"]:
		if float(en["hp"]) <= 0.0:
			continue
		if best.is_empty() or float(en["threat"]) > float(best["threat"]):
			best = en
	var lock: int = int(best["id"]) if not best.is_empty() else -1

	# march: straight at the station + symmetric repulsion
	if here.distance_to(station) > 4.0:
		var desired := (station - here).normalized()
		var push := Vector2.ZERO
		for nb in state["neighbors"]:
			var away: Vector2 = here - nb["pos"]
			var d := away.length()
			if d < REPULSE_DIST and d > 0.001:
				push += away.normalized() * (REPULSE_DIST - d) / REPULSE_DIST
		var out := (desired + push * REPULSE_W).normalized() * speed
		return {"move": out, "target": lock, "attack": false}

	# fight from the station at the hard-coded cadence
	if lock != -1:
		var reach: float = float(state["attack_range"]) - RANGE_MARGIN
		var target := best
		if here.distance_to(best["pos"]) > reach:
			for en in state["enemies"]:
				if float(en["hp"]) > 0.0 and here.distance_to(en["pos"]) <= reach:
					target = en
					break
		if here.distance_to(target["pos"]) <= reach and _time_since_hit >= HARDCODED_COOLDOWN:
			_time_since_hit = 0.0
			return {"move": Vector2.ZERO, "target": lock, "attack": int(target["id"])}
	return {"move": Vector2.ZERO, "target": lock, "attack": false}
