extends RefCounted
## NAIVE StatusEngine — red-teamed to be as strong as a straightforward first cut gets. It handles
## the gentle case (a single effect, applied and left alone) correctly: it ticks each round and
## retires an effect when its counter runs out, so a lone poison deals the right damage over the
## right number of rounds. It comes apart on the patterns the contract actually cares about:
##  * apply() always appends a fresh instance, so re-applying a kind stacks copies instead of
##    refreshing the one that is already running;
##  * stat effects are written straight onto the base stat (base_attack) instead of the removable
##    modifier substrate, so a debuff/buff never wears off;
##  * tick() resolves damage-over-time before heal-over-time regardless of the order the effects
##    were applied in, so a same-round rescue can arrive too late.

var _by_battler := {}


func setup(_roster) -> void:
	_by_battler.clear()


func apply(target, effect: Dictionary) -> void:
	var kind := String(effect.get("kind", ""))
	var mag := int(effect.get("magnitude", 0))
	var dur := int(effect.get("duration", 0))
	if dur <= 0 or kind == "":
		return
	# stat effects: written onto the base value directly (no handle to undo it later)
	if kind == "attack_down":
		target.stats.base_attack -= mag
	elif kind == "attack_up":
		target.stats.base_attack += mag
	# always a new instance, never a refresh
	var lst: Array = _by_battler.get(target, [])
	lst.append({"kind": kind, "magnitude": mag, "remaining": dur})
	_by_battler[target] = lst


func tick(_roster) -> void:
	for target in _by_battler:
		var lst: Array = _by_battler[target]
		# resolve dots before hots (fixed priority, ignores when each was applied)
		lst.sort_custom(func(a, b): return _order(String(a["kind"])) < _order(String(b["kind"])))
		var keep: Array = []
		for e in lst:
			if int(e["remaining"]) <= 0:
				continue
			match String(e["kind"]):
				"dot":
					target.stats.health -= int(e["magnitude"])
				"hot":
					target.stats.health += int(e["magnitude"])
				_:
					pass
			e["remaining"] = int(e["remaining"]) - 1
			keep.append(e)
		_by_battler[target] = keep


func _order(kind: String) -> int:
	return 0 if kind == "dot" else 1
