extends "res://judge_core.gd"
## record.gd — RECORD driver. A thin shell over the judge core (which it extends): the roster build,
## the two-phase loop with the status engine wired in (sim_core), the contract check and the result
## writing are all inherited — there is exactly ONE simulation, the judged one. This scene only
## lowers the animation time-scale so Movie Maker captures a watchable battle, and adds a Stage node
## that paints the LIVE roster every frame with game/view.gd (the same visual the F5 preview draws).
## It still writes record_result.json + prints GEB_RESULT so the recording can be cross-checked
## against the judge (recording is a display channel; the cross-check is informational).
##
## Run (windowed, under Xvfb + software GL, Movie Maker capturing one frame per engine frame):
##   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
##       --scenario <name> --seed N --controller <engine path> --out /abs/result.json

const View = preload("res://view.gd")


class Stage extends Node2D:
	var core: Object = null
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if core != null and core._roster != null:
			View.render(self, core._roster, {})


func _init() -> void:
	_time_scale = 6.0   # slow the animation waits enough for a watchable capture (logic unchanged)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stage := Stage.new()
	stage.core = self
	add_child(stage)
	var args := _parse_args(OS.get_cmdline_user_args())
	var result: Dictionary = await run(args)
	_finish(String(args.get("out", "")), result, bool(result.get("pass", false)))


func _parse_args(uargs: PackedStringArray) -> Dictionary:
	var d := {}
	var i := 0
	while i < uargs.size():
		var a := uargs[i]
		if a.begins_with("--"):
			var key := a.substr(2)
			var val := "true"
			if i + 1 < uargs.size() and not uargs[i + 1].begins_with("--"):
				val = uargs[i + 1]
				i += 1
			d[key] = val
		i += 1
	return d


func _finish(out_path: String, result: Dictionary, passed: bool) -> void:
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(result, "  "))
			f.close()
	print("GEB_RESULT ", JSON.stringify(result))
	await get_tree().create_timer(0.3).timeout   # let Movie Maker flush the final frames
	get_tree().quit(0 if passed else 1)
