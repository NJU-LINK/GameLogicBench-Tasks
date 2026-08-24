extends RefCounted
#
# NAIVE reference controller for atom_patrol_edge.
# Passes on BASELINE, fails on every hidden scenario.
#
# Plan-once dead-reckoner. On its first frame it reads the level geometry CORRECTLY —
# resolves the platform underfoot by y-match + x-containment, cuts the segment at any
# obstacle wall resting on it, keeps an 18-unit margin — so on any static world it walks
# the same patrol a per-frame reader would. Its two weaknesses:
#   1. it never looks at the state again after that first frame, and
#   2. it executes the plan as a frame-count schedule, converting distances to frames at
#      an assumed 2 units per frame (SPEED at the preview's 60 Hz).
# Anything that happens after frame 0, or any run whose timestep is not the one it
# assumed, silently desynchronizes the schedule from the world:
#   - wall injected mid-run    -> jams on it, the schedule keeps counting, later legs
#                                 walk the accumulated error off a cliff        (fell)
#   - wall removed mid-run     -> keeps shuttling the stale narrow segment (coverage)
#   - two walls injected       -> jams long stretches of every leg             (stalled)
#   - coarser timestep         -> every leg covers twice the planned ground      (fell)

const CHAR_RADIUS := 12.0
const EDGE_MARGIN := 18.0
const STEP := 2.0            # units per frame it assumes: SPEED (120) at 60 Hz

var _planned := false
var _dir := 1.0
var _frames_left := 0
var _leg_frames := 0

func decide(state: Dictionary) -> Dictionary:
	if not _planned:
		_plan(state)
	if _frames_left <= 0:
		_dir = -_dir
		_frames_left = _leg_frames
	_frames_left -= 1
	return {"move": _dir}

func _plan(state: Dictionary) -> void:
	_planned = true
	var pos: Vector2 = state["self_pos"]
	var foot_y: float = pos.y + CHAR_RADIUS
	var home := Rect2()
	var found := false
	for p in state["platforms"]:
		var r: Rect2 = p
		if absf(r.position.y - foot_y) <= 4.0 \
				and pos.x >= r.position.x - CHAR_RADIUS \
				and pos.x <= r.position.x + r.size.x + CHAR_RADIUS:
			home = r
			found = true
			break
	var lo: float
	var hi: float
	if found:
		lo = home.position.x
		hi = home.position.x + home.size.x
		for w in state["walls"]:
			var wr: Rect2 = w
			if absf((wr.position.y + wr.size.y) - home.position.y) <= 4.0:
				if wr.position.x + wr.size.x <= pos.x:
					lo = maxf(lo, wr.position.x + wr.size.x)
				elif wr.position.x >= pos.x:
					hi = minf(hi, wr.position.x)
	else:
		lo = pos.x - 50.0
		hi = pos.x + 50.0
	var left_limit := lo + EDGE_MARGIN
	var right_limit := hi - EDGE_MARGIN
	_leg_frames = maxi(int(ceilf((right_limit - left_limit) / STEP)), 1)
	_dir = 1.0
	_frames_left = maxi(int(ceilf((right_limit - pos.x) / STEP)), 1)
