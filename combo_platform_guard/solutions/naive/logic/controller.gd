extends RefCounted
#
# NAIVE solution for combo_platform_guard — the broadly-wrong attempt.
#
# It gets the overall shape right (patrol, chase, cross gaps from the lip with a committed
# direction) but is wrong in three places at once:
#   * VISIBILITY : "visible" means DISTANCE ALONE inside the range gate — no sight ray, so an
#     occluded target is confidently claimed.
#   * PATROL     : the beat is a fixed +-STRIDE pace around the spawn point instead of the
#     home platform's real walkable ends, and there is no come-home fallback: pacing where I
#     stand IS the whole idle behaviour.
#   * CHASE      : no confront memory — every frame it simply chases the nearest visible
#     visitor, so with two visitors it parks on the near one forever. And it never actually
#     leaves the ground: it walks to the launch lip and waits there instead of jumping
#     ("someone that far away is the other platform's problem").

const EDGE_MARGIN := 26.0
const LIP_BACK := 14.0
const CONFIRM := 125.0
const RANGE_BACKOFF := 14.0
const STRIDE := 70.0             # fixed half-stride around the spawn, geometry-blind

var _dir := 1.0
var _anchor := INF               # spawn x, latched on the first frame
var _air_dir := 0.0
var _confronted := {}

func decide(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var seen := _seen(state)

	if not bool(state["is_on_floor"]):
		return {"move": _air_dir, "jump": false, "chasing": _nearest_id(seen)}

	var target := {}
	var best := INF
	for it in seen:
		var d: float = pos.distance_to(it["pos"])
		if d < best:
			best = d
			target = it

	if not target.is_empty():
		return _chase(state, target, best)

	return _patrol(state)

# Visibility by distance only (THE defect: no sight ray).
func _seen(state: Dictionary) -> Array:
	var pos: Vector2 = state["self_pos"]
	var gate: float = float(state["vision_range"]) - RANGE_BACKOFF
	var out := []
	for it in state["intruders"]:
		if pos.distance_to(it["pos"]) <= gate:
			out.append(it)
	return out

func _nearest_id(seen: Array) -> int:
	return -1 if seen.is_empty() else int(seen[0]["id"])

func _chase(state: Dictionary, target: Dictionary, dist: float) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var tpos: Vector2 = target["pos"]
	var id := int(target["id"])

	if dist <= CONFIRM:
		_confronted[id] = true
		return {"move": 0.0, "jump": false, "chasing": id}

	var toward := signf(tpos.x - pos.x)
	if toward == 0.0:
		toward = 1.0
	var my_plat := _platform_under(state, pos)
	if not my_plat.is_empty():
		var plat: Rect2 = my_plat["rect"]
		if tpos.x < plat.position.x or tpos.x > plat.position.x + plat.size.x:
			var lip_x := (plat.position.x + plat.size.x - LIP_BACK) if toward > 0.0 \
				else (plat.position.x + LIP_BACK)
			var lip_stand := Vector2(lip_x, plat.position.y - 12.0)
			if absf(pos.x - lip_x) <= 6.0:
				if lip_stand.distance_to(tpos) <= CONFIRM + 20.0:
					return {"move": 0.0, "jump": false, "chasing": id}
				_air_dir = toward
				return {"move": 0.0, "jump": false, "chasing": id}
			if (toward > 0.0 and pos.x > lip_x) or (toward < 0.0 and pos.x < lip_x):
				return {"move": -toward * 0.4, "jump": false, "chasing": id}
	return {"move": toward, "jump": false, "chasing": id}

func _patrol(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	if _anchor == INF:
		_anchor = pos.x
	if pos.x <= _anchor - STRIDE:
		_dir = 1.0
	elif pos.x >= _anchor + STRIDE:
		_dir = -1.0
	return {"move": _dir, "jump": false, "chasing": -1}

func _go_home(state: Dictionary) -> Dictionary:
	var pos: Vector2 = state["self_pos"]
	var home: Rect2 = state["home_rect"]
	var home_cx := home.position.x + home.size.x * 0.5
	var toward := signf(home_cx - pos.x)
	var my_plat := _platform_under(state, pos)
	if not my_plat.is_empty():
		var plat: Rect2 = my_plat["rect"]
		if home_cx < plat.position.x or home_cx > plat.position.x + plat.size.x:
			var lip_x := (plat.position.x + plat.size.x - LIP_BACK) if toward > 0.0 \
				else (plat.position.x + LIP_BACK)
			if absf(pos.x - lip_x) <= 6.0:
				_air_dir = toward
				return {"move": toward, "jump": true, "chasing": -1}
			if (toward > 0.0 and pos.x > lip_x) or (toward < 0.0 and pos.x < lip_x):
				return {"move": -toward * 0.4, "jump": false, "chasing": -1}
	return {"move": toward, "jump": false, "chasing": -1}

func _on_home(state: Dictionary) -> bool:
	var pos: Vector2 = state["self_pos"]
	var home: Rect2 = state["home_rect"]
	return pos.x >= home.position.x and pos.x <= home.position.x + home.size.x \
		and absf(pos.y - (home.position.y - 12.0)) <= 16.0

func _platform_under(state: Dictionary, pos: Vector2) -> Dictionary:
	for p in state["platforms"]:
		var r: Rect2 = p
		if pos.x >= r.position.x - 2.0 and pos.x <= r.position.x + r.size.x + 2.0 \
				and absf(pos.y - (r.position.y - 12.0)) <= 18.0:
			return {"rect": r}
	return {}

func _walk_segment(state: Dictionary) -> Array:
	var home: Rect2 = state["home_rect"]
	var pos: Vector2 = state["self_pos"]
	var lo: float = home.position.x
	var hi: float = home.position.x + home.size.x
	for w in state["walls"]:
		var wr: Rect2 = w
		if wr.position.y + wr.size.y >= home.position.y - 2.0 \
				and wr.position.y + wr.size.y <= home.position.y + 2.0:
			if wr.position.x + wr.size.x <= pos.x:
				lo = maxf(lo, wr.position.x + wr.size.x)
			elif wr.position.x >= pos.x:
				hi = minf(hi, wr.position.x)
	return [lo + 12.0, hi - 12.0]
