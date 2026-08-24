extends RefCounted
#
# NAIVE reference module -- passes on the previewed swing, FAILS when the call pattern differs.
#
# It does the obvious thing a first pass reaches for: treat every body_entered signal as a hit and
# deal damage right there. Its two hand-rolled shortcuts -- the exact things this task exposes -- are
# (1) it never remembers which targets it has already hit this swing, so a body that leaves and
# re-enters the blade within one swing is hit twice; (2) it registers on any entry it is handed
# without checking the active-frame flag, so a target merely brushed during the wind-up also takes a
# hit; and (3) it assumes at most one body enters the blade per frame, so it handles entered[0] and
# drops the rest of a same-frame batch. On the previewed swing each target enters exactly once, on
# its own frame, during the active frames, so it looks correct.

func setup(_params: Dictionary) -> void:
	pass

func resolve(_swing: int, _active: bool, entered: Array, _exited: Array) -> Array:
	# the entry is a hit -- no per-swing dedup, no active-frame check, one entry per frame
	var out: Array = []
	if entered.is_empty():
		return out
	out.append(int(entered[0]))
	return out
