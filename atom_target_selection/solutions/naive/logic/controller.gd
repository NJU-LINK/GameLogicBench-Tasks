extends RefCounted
#
# NAIVE reference controller -- passes on the layout it was tuned against, FAILS when the top
# targets sit close enough that their wobble makes them cross.
#
# It does the "obvious" thing right: it ranks targets by threat and always locks onto the most
# threatening one, so it is never off-target and always reacts instantly to a real shift. Its one
# hand-rolled weakness -- the exact thing this task exposes -- is that it has NO hysteresis: it
# re-picks the bare argmax every single frame. When the two top targets are far apart in threat
# (as in the previewed setup) argmax never flickers and this looks fine. But when the top two sit
# within a wobble of each other, they swap the top spot dozens of times and this flips its lock on
# every crossing -> target_thrash.

var _lock := -1

func on_tick(state: Dictionary) -> Dictionary:
	var targets: Array = state["targets"]
	if targets.is_empty():
		return {"target": _lock}
	var best: int = int(targets[0]["id"])
	var best_threat: float = float(targets[0]["threat"])
	for tgt in targets:
		if float(tgt["threat"]) > best_threat:
			best_threat = float(tgt["threat"])
			best = int(tgt["id"])
	_lock = best
	return {"target": _lock}
