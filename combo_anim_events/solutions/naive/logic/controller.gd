extends RefCounted
#
# NAIVE dispatcher -- the "worked on the demo rig" build. It drives the frame events off its OWN
# per-frame counter, assuming the animation always plays forward at a fixed 60 fps from the start:
# each poll it ticks its counter by one and fires any event whose frame number (time * 60) equals the
# counter. This reads current_animation only to pick the right event table -- it NEVER reads the
# real clock position, honours the seek flag, or resets on an animation switch.
#
# On the gentle public baseline (one animation, real 60 fps, one event per frame, no seek, no
# interrupt) the counter tracks the real clock by coincidence and it passes. Every hidden scenario
# leans on the gap:
#  * low frame rate : a big step never lands the counter on the skipped frame numbers -> misses events.
#  * speed_scale    : the clock moves faster than the counter -> events fire at the wrong frame.
#  * seek           : the counter ignores the jump -> drifts off the sought clock.
#  * interrupt      : the counter is not reset on the animation switch -> the new animation's events
#                     fire at the wrong frame.

const FPS := 60.0

var _ap: AnimationPlayer = null
var _events := {}
var _frame := 0


func setup(anim_player: AnimationPlayer, events: Dictionary) -> void:
	_ap = anim_player
	_events = events.duplicate(true)
	_frame = 0


func poll(_just_sought: bool) -> Array:
	var out: Array = []
	var anim := _ap.current_animation
	_frame += 1
	for e in _events.get(anim, []):
		if int(round(float(e["time"]) * FPS)) == _frame:
			out.append(String(e["id"]))
	return out
