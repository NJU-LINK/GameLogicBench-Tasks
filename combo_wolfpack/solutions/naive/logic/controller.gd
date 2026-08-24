extends RefCounted
#
# NAIVE reference controller -- "it hunts, ship it". Each piece does the obvious thing that
# survives the previewed hunt, and each carries a lazy shortcut a hidden axis punishes:
#   * move   : drive STRAIGHT AT the prey with a linear radial repulsion off nearby packmates --
#              a genuine two-force attempt with NO ring assignment and NO disengagement: it
#              CAMPS at the contact ring. The solid prey body stops the charge and the repulsion
#              smears the wolves around it well enough on the previewed hunt; a prey that
#              lashes back mauls the camper (disengage), and a MOVING prey is chased from
#              behind -- the pack strings out on the tail, never wraps (encirclement).
#   * lock   : bare per-frame argmax over prey vulnerabilities -- no hysteresis. Fine while one
#              prey dominates (target_selection).
#   * strike : whenever ready and in reach, paced against a hard-coded 30-frame cadence (the
#              previewed value, which every scenario keeps). One brain per wolf means the
#              converging pack's clocks run near lock-step: on a frail prey the same-frame jaws
#              at the kill boundary overshoot (clean_kill), and there is no relay to keep a
#              rallying prey under pressure (pressure).

const HARDCODED_COOLDOWN := 30.0 / 60.0   # tuned to the preview; NOT read from state
const RANGE_MARGIN := 8.0
const SEP_REACH := 34.0                   # repel from a packmate inside this
const SEP_STR := 380.0                    # repulsion strength (linear ramp; strong near contact)

var _time_since_hit := 1e9

func on_tick(state: Dictionary) -> Dictionary:
	_time_since_hit += float(state["dt"])
	var here: Vector2 = state["self_pos"]
	var speed: float = float(state["max_speed"])

	# bare argmax lock over live prey
	var best := {}
	for p in state["prey"]:
		if float(p["hp"]) <= 0.0:
			continue
		if best.is_empty() or float(p["vulnerability"]) > float(best["vulnerability"]):
			best = p
	if best.is_empty():
		return {"move": Vector2.ZERO, "attack": false}
	var lock: int = int(best["id"])
	var tpos: Vector2 = best["pos"]
	var reach: float = float(state["attack_range"]) - RANGE_MARGIN
	var dp := here.distance_to(tpos)

	# drive at the prey + linear packmate repulsion, every frame (the prey's body is solid; the
	# world stops the charge at contact and the push spreads the wolves along it)
	var seek := (tpos - here).normalized() * speed
	var push := Vector2.ZERO
	for nb in state["neighbors"]:
		var away: Vector2 = here - nb["pos"]
		var d := away.length()
		if d > 0.001 and d < SEP_REACH:
			push += away.normalized() * SEP_STR * (SEP_REACH - d) / SEP_REACH
	var v := seek + push
	if v.length() > speed:
		v = v.normalized() * speed

	# strike at the hard-coded cadence whenever in reach
	var attack: Variant = false
	if dp <= reach and _time_since_hit >= HARDCODED_COOLDOWN:
		_time_since_hit = 0.0
		attack = lock
	return {"move": v, "target": lock, "attack": attack}
