extends RefCounted
#
# NAIVE reference module -- passes on the previewed (gentle) motion, FAILS when the call pattern
# differs.
#
# It takes the shortcut a first pass reaches for: if the straight-line destination looks clear (a
# quick shape query there finds nothing), just teleport the body to it — skip the expensive sweep.
# Only when the destination is blocked does it fall back to a single swept move that stops at the
# first contact. It never resolves an initial overlap and never slides the leftover motion along a
# surface. On the previewed head-on approach the destination is blocked exactly at the stop, so the
# swept fallback lands it on the wall face and it looks correct.
#
# The two hand-rolled shortcuts this task exposes: (1) the "endpoint clear -> teleport" fast path
# passes a fast body straight through a thin wall (its far-side destination is clear); and (2) with
# no depenetration and no sliding, a body spawned inside a wall stays embedded, and a body driven
# into a wall at an angle stops dead instead of sliding along it.

var _body: RID
var _margin := 0.08

func setup(params: Dictionary) -> void:
	_body = params["body"]
	_margin = float(params.get("margin", 0.08))

func solve(from: Vector2, motion: Vector2) -> Vector2:
	var dest := from + motion
	var dss := PhysicsServer2D.space_get_direct_state(PhysicsServer2D.body_get_space(_body))
	var sp := PhysicsShapeQueryParameters2D.new()
	sp.shape_rid = PhysicsServer2D.body_get_shape(_body, 0)
	sp.transform = Transform2D(0.0, dest)
	sp.collision_mask = PhysicsServer2D.body_get_collision_mask(_body)
	if dss.intersect_shape(sp, 1).is_empty():
		return dest                     # destination looks clear -> teleport (tunnels a fast mover)
	# blocked destination: one swept move to first contact, no slide, no depenetration
	var r := PhysicsTestMotionResult2D.new()
	var p := PhysicsTestMotionParameters2D.new()
	p.from = Transform2D(0.0, from)
	p.motion = motion
	p.margin = _margin
	PhysicsServer2D.body_test_motion(_body, p, r)
	return from + r.get_travel()
