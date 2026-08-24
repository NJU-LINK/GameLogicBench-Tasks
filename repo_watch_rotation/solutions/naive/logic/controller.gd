extends RefCounted
#
# NAIVE reference controller -- the "watch with a stopwatch, chase what you see, go home when you
# lose it" officer. Made as strong as possible EXCEPT for the two core disciplines:
#   * SUSPICION : instead of a rate-weighted, draining meter it counts CONSECUTIVE frames the watched
#     intruder sits in a post's cone and fires once that dwell passes a threshold tuned to the gentle
#     preview. Blind to how central/close the intruder is (fill RATE) and resets the instant it leaves
#     the cone — so it fires far too early on a faint edge-hugger (premature), never accumulates on a
#     fast point-blank rush inside its short in-cone window (missed), and never survives peeking.
#   * SEARCH    : none. It navigates cleanly (no wall clips, no ghost chases) and closes on a visible
#     quarry, but the instant the quarry slips from sight it turns straight back for its post — no
#     last-known memory, no commit.
#   * ALLOCATION: greedy — guard 1 chases whatever it can see; guard 0 holds the upper post. It never
#     reasons about whether the post it leaves can afford the absence.
# Fine on the gentle baseline (dwell coincides, the quarry is only lost by range); every hidden cell
# breaks it on an armed axis.

const DWELL := 135                     # tuned to the gentle preview drill
const CLOSE_TO := 70.0

var _count := {}                       # per-post consecutive in-cone frame count
var _alarmed := {}

func setup(state: Dictionary) -> void:
	for p in state["posts"]:
		_count[int(p["id"])] = 0
		_alarmed[int(p["id"])] = false

func on_tick(state: Dictionary) -> Dictionary:
	# --- suspicion: dwell counter per post ---
	var alarms := {}
	for p in state["posts"]:
		var pid := int(p["id"])
		if not _count.has(pid):
			_count[pid] = 0
			_alarmed[pid] = false
		if bool(p["intruder_in_cone"]):
			_count[pid] += 1
		else:
			_count[pid] = 0
		if _count[pid] >= DWELL:
			_alarmed[pid] = true
		alarms[pid] = _alarmed[pid]

	# --- allocation: guard 0 holds post A; guard 1 chases the nearest visible chaser ---
	var guards := {}
	var post_by_id := {}
	for p in state["posts"]:
		post_by_id[int(p["id"])] = p
	guards[0] = _hold(state["guards"][0]["pos"], post_by_id.get(0, {}))

	var g1: Vector2 = state["guards"][1]["pos"]
	var world: Node2D = state["world"]
	var space := world.get_world_2d().direct_space_state
	var vision: float = float(state["vision_range"])
	var nearest := {}
	for ent in state["entities"]:
		var ep: Vector2 = ent["pos"]
		if g1.distance_to(ep) > vision:
			continue
		var q := PhysicsRayQueryParameters2D.create(g1, ep)
		if space.intersect_ray(q).is_empty():
			if nearest.is_empty() or g1.distance_to(ep) < g1.distance_to(nearest["pos"]):
				nearest = {"id": int(ent["id"]), "pos": ep}

	if not nearest.is_empty():
		var tpos: Vector2 = nearest["pos"]
		if g1.distance_to(tpos) > CLOSE_TO:
			guards[1] = {"move": _nav(state, g1, tpos), "chasing": int(nearest["id"])}
		else:
			guards[1] = {"move": Vector2.ZERO, "chasing": int(nearest["id"])}
	else:
		# nothing visible -> straight back home to post C (no search, no memory)
		guards[1] = _hold(g1, post_by_id.get(1, {}))
	return {"guards": guards, "alarms": alarms}

func _hold(here: Vector2, post: Dictionary) -> Dictionary:
	if post.is_empty():
		return {"move": Vector2.ZERO, "chasing": -1}
	var pp: Vector2 = post["pos"]
	if here.distance_to(pp) > 2.0:
		return {"move": pp - here, "chasing": -1}
	return {"move": Vector2.ZERO, "chasing": -1}

func _nav(state: Dictionary, here: Vector2, to_pos: Vector2) -> Vector2:
	var map: RID = state["nav_map"]
	var path: PackedVector2Array = NavigationServer2D.map_get_path(map, here, to_pos, true)
	var aim: Vector2 = to_pos
	if path.size() >= 2:
		aim = path[1]
		if here.distance_to(aim) < 1.0 and path.size() > 2:
			aim = path[2]
	return aim - here
