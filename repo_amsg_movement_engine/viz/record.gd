extends "res://judge_core.gd"
## record.gd — the viz/demo layer (geb "必交 but 降级": produces a readable mp4; cross-check with
## the judge is informational, not a gate). It IS the judge simulation — this script extends the
## frozen judge_core and only adds a follow camera, a light and an environment, so the rendered
## run is exactly the judged run (real mixamo rig + animation tree, true materials). Invoked by
## the record pipeline windowed under Xvfb with --write-movie; one headless --import pass runs
## first, so the script-class cache exists without the judge's re-exec bootstrap (Movie Maker
## itself pins the frame clock).

var _cam: Camera3D


func _ready() -> void:
	var args := {}
	var uargs := OS.get_cmdline_user_args()
	var i := 0
	while i < uargs.size():
		var a: String = uargs[i]
		if a.begins_with("--"):
			var key := a.substr(2)
			var val := "true"
			if i + 1 < uargs.size() and not uargs[i + 1].begins_with("--"):
				val = uargs[i + 1]
				i += 1
			args[key] = val
		i += 1
	var result: Dictionary = await run(args)
	var out := String(args.get("out", ""))
	if out != "":
		var fa := FileAccess.open(out, FileAccess.WRITE)
		if fa != null:
			fa.store_string(JSON.stringify(result, "  "))
			fa.close()
	print("GEB_RESULT ", JSON.stringify(result))
	await get_tree().create_timer(0.5).timeout   # let Movie Maker flush
	get_tree().quit(0 if bool(result.get("pass", false)) else 1)


func _viz_setup() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.46, 0.60)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.78)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 160, 0)   # from behind the camera's shoulder
	light.light_energy = 1.2
	add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60, -20, 0)
	fill.light_energy = 0.6
	add_child(fill)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	# visible floor/step/slab meshes for the invisible judge collision boxes
	for b: Array in spec["boxes"]:
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		mesh.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.53, 0.48)
		mesh.material_override = mat
		mesh.position = b[0]
		add_child(mesh)


func _process(_dt: float) -> void:
	if _cam != null and rig != null:
		# keep the camera low enough to stay under scenario slabs (ceiling_lock's underside is ~1.95)
		_cam.global_position = rig.global_position + Vector3(2.6, 1.25, -3.4)
		_cam.look_at(rig.global_position + Vector3(0, 0.9, 0))
