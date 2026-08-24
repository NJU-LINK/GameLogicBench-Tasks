extends RefCounted
#
# NAIVE reference arbiter -- passes on the battery it was tuned against, FAILS when the call pattern
# differs from the previewed one.
#
# It does the obvious thing: enforce a per-turret cooldown by COUNTING FRAMES. It reads the cooldown
# from setup, converts it to a frame count assuming 60 fps, and refuses a turret until that many
# frames have passed since it last fired. Its two hand-rolled shortcuts — the exact things this task
# exposes — are (1) it counts advance() calls instead of summing the dt it is handed, so when
# game-time is paced differently from 60 fps its cooldown drifts; and (2) it tracks each turret in
# isolation and never accounts for the SHARED power bank, so when many turrets fire in one frame it
# grants them all and over-draws the bank.

const HARDCODED_FPS := 60.0

var _cooldown_frames := 21
var _frame := 0
var _last_frame := {}      # turret id -> frame index of its last granted shot

func setup(params: Dictionary) -> void:
	_cooldown_frames = int(round(float(params["turret_cooldown"]) * HARDCODED_FPS))

func advance(_dt: float) -> void:
	_frame += 1                          # counts frames; ignores how much game-time dt carries

func request_fire(turret_id: int) -> bool:
	var last: int = int(_last_frame.get(turret_id, -1000000))
	if _frame - last < _cooldown_frames:
		return false                     # this turret still "cooling" by frame count
	# grant — no shared-bank accounting at all
	_last_frame[turret_id] = _frame
	return true
