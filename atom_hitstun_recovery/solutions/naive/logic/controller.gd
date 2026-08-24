extends RefCounted
#
# NAIVE red-team solution — passes the previewed baseline, FAILS when the calling pattern turns
# un-forewarned. Best-effort: it is a working single-slot state machine that handles apply /
# refresh / expiry / query correctly on the happy path, so the previewed baseline (a stun that is
# refreshed and then expires, at a steady 60 Hz) matches the reference frame for frame.
#
# Its two hand-rolled weaknesses — the exact things this task exposes — are both classic:
#   1. It counts DOWN A FRAME BUDGET instead of tracking the game time it is handed: advance()
#      decrements one frame per call and ignores dt. On a steady clock frames == game time, so the
#      baseline is fine — but when the game FREEZES (advance called with dt = 0.0) it keeps counting,
#      and the effect recovers early.
#   2. It EMITS `expired` BEFORE clearing its slot, then clears unconditionally — so an effect
#      applied reentrantly from the handler is immediately wiped, and the machine reports actionable
#      when it should still be blocked.

const DT := 1.0 / 60.0

signal expired(effect: String)

var _effect := ""
var _frames_left := 0

func apply(effect: String, duration: float) -> void:
	_effect = effect
	_frames_left = int(round(duration / DT))       # think in frames

func advance(_dt: float) -> void:
	if _effect == "":
		return
	_frames_left -= 1                                # counts calls, ignores dt -> drifts across a freeze
	if _frames_left <= 0:
		expired.emit(_effect)                        # emit BEFORE clearing -> drops a reentrant apply
		_effect = ""
		_frames_left = 0

func is_actionable() -> bool:
	return _effect == ""

func remaining() -> float:
	return float(max(_frames_left, 0)) * DT
