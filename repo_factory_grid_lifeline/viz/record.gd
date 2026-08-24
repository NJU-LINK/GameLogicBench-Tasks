extends "res://judge.gd"
#
# RECORD driver for repo_factory_grid_lifeline -- renders the AUTHORITATIVE judge simulation.
#
# THIN SHELL over judge.gd (which it extends): the scenario worlds, the tick loop, the injections,
# the surgery, every contract check and the verdict are all inherited -- there is exactly ONE
# simulation, the judged one. The picture is the game's own 2D pixel art: the judge places the real
# entity scenes (stirling engine, power plant, turret, crusher with their AnimatedSprite2D art), so
# a windowed run shows the real factory floor working (or starving) through the lifeline under
# test. The only additions here are a camera framing the judge's fixed factory cells and a ground
# backdrop; the only difference from a judged run is skipping the headless bootstrap re-exec
# (_record_mode) -- the record pipeline pre-imports the project and Movie Maker pins frame pacing.
#
# NOTE (record is a degraded, display-only channel -- TASK_AUTHORING P2.5): the mp4 must be
# produced and readable; cross-check MISMATCH is logged, not gated. This driver runs the judged
# simulation, so the picture is faithful to the verdict by construction.

func _init() -> void:
	_record_mode = true


func _ready() -> void:
	# frame the factory: cells span roughly (-4..6, 0..4) * 16px
	var cam := Camera2D.new()
	cam.position = Vector2(0, 16)
	cam.zoom = Vector2(3.0, 3.0)
	add_child(cam)
	cam.make_current()
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.05, 0.20)
	bg.position = Vector2(-320, -180)
	bg.size = Vector2(640, 360)
	bg.z_index = -10
	add_child(bg)
	super()


func _on_frame(_vs: Dictionary) -> void:
	# The 2D world renders itself (real entity scenes and their animations). This hook additionally
	# redraws the display-only pipe/provider markers below so the heat network (and its mid-run
	# surgery) is visible in the video.
	queue_redraw()


func _draw() -> void:
	# display-only dressing: the laid pipe paths and the heat providers (bare logic entities with
	# no sprite of their own). Purely visual; the judged simulation is untouched.
	if _pipe_paths == null:
		return
	for path in _pipe_paths._paths:
		for i in range(path.size() - 1):
			draw_line(Vector2(path[i]) * 16.0, Vector2(path[i + 1]) * 16.0,
				Color(0.65, 0.42, 0.22), 3.0)
		for p in path:
			draw_circle(Vector2(p) * 16.0, 2.0, Color(0.45, 0.28, 0.15))
	for nm in _hprov:
		if is_instance_valid(_hprov[nm]) and _entities.has(nm) and is_instance_valid(_entities[nm]):
			var pos: Vector2 = _entities[nm].position
			draw_rect(Rect2(pos - Vector2(6, 6), Vector2(12, 12)), Color(1.0, 0.55, 0.12))
			var lvl: float = clampf(float(_hprov[nm].amount) / 60.0, 0.0, 1.0)
			draw_rect(Rect2(pos + Vector2(-6, 8), Vector2(12.0 * lvl, 2)), Color(1.0, 0.3, 0.1))
