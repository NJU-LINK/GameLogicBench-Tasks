extends RefCounted
#
# NAIVE reference controller -- the classic "runs great on my machine" build. Every piece does
# the OBVIOUS thing that survives the previewed setup, and each shortcut is a real-world bug
# pattern the hidden scenarios lean on:
#   * pacing   : converts the stated cooldown into a FRAME count once at setup (60 fps assumed)
#                and counts frames between swings                       (frame-denominated time)
#   * numbers  : cooldown / attack_range captured once at setup, never re-read (setup caching)
#   * routing  : asks the nav map once per target and replays the cached waypoints
#                                                                       (plan-once navigation)
#   * stagger  : checked before swinging, but the walking leg never looks at it
#   * lock     : bare per-frame argmax over threat (fine in the preview's wide gaps)
#   * death    : hp <= 0 -> one prompt ack, stays down (learned that lesson the hard way)
# In the gentle public orchestration every shortcut coincidentally complies.

const RANGE_MARGIN := 8.0
const WAYPOINT_REACH := 12.0

var _cd_frames := 50
var _range := 60.0
var _frames_since_hit := 1000000
var _acked := false
var _path := PackedVector2Array()
var _path_i := 0
var _path_target := -1

func setup(state: Dictionary) -> void:
	# 0.8 s at 60 fps = 48 frames; +2 frames of safety.
	_cd_frames = int(round(float(state["cooldown"]) * 60.0)) + 2
	_range = float(state["attack_range"])

func on_tick(state: Dictionary) -> Dictionary:
	if float(state["self_hp"]) <= 0.0:
		if not _acked:
			_acked = true
			return {"move": Vector2.ZERO, "attack": false, "death_ack": true}
		return {"move": Vector2.ZERO, "attack": false}

	_frames_since_hit += 1

	# bare argmax lock, recomputed every frame
	var targets: Array = state["targets"]
	var best := -1
	var best_t := -INF
	var cur := {}
	for tgt in targets:
		if float(tgt["hp"]) <= 0.0:
			continue
		if float(tgt["threat"]) > best_t:
			best_t = float(tgt["threat"])
			best = int(tgt["id"])
			cur = tgt
	if best == -1:
		return {"move": Vector2.ZERO, "attack": false}

	var here: Vector2 = state["self_pos"]
	var tpos: Vector2 = cur["pos"]
	var d: float = here.distance_to(tpos)

	# in range -> swing whenever the frame counter says the weapon recovered
	if d <= _range - RANGE_MARGIN:
		if _frames_since_hit >= _cd_frames and float(state["hitstun_remaining"]) <= 0.0:
			_frames_since_hit = 0
			return {"move": Vector2.ZERO, "attack": best, "target": best}
		return {"move": Vector2.ZERO, "attack": false, "target": best}

	# walk the route we computed for this target when we first picked it
	if _path_target != best or _path.size() == 0:
		var map: RID = state["nav_map"]
		_path = NavigationServer2D.map_get_path(map, here, tpos, true)
		_path_i = 1 if _path.size() >= 2 else 0
		_path_target = best
	var aim: Vector2 = tpos
	if _path_i < _path.size():
		aim = _path[_path_i]
		if here.distance_to(aim) < WAYPOINT_REACH and _path_i < _path.size() - 1:
			_path_i += 1
			aim = _path[_path_i]
	return {"move": aim - here, "attack": false, "target": best}
