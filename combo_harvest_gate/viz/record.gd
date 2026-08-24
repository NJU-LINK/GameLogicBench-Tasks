extends "res://judge.gd"
#
# RECORD driver for combo_harvest_gate — renders the AUTHORITATIVE judge simulation to video.
#
# Thin shell over judge.gd (which it extends): the simulation loop, scenario/press handling,
# assertions and result writing are all inherited — there is exactly ONE simulation, the judged
# one. This scene only flips on _record_mode and implements the _on_frame hook: each settled
# frame is handed to game/view.gd (the same visual code the F5 preview draws with) and rendered,
# so Movie Maker captures the judged trajectory with the real game art. It still writes
# record_result.json + prints GEB_RESULT so the recording can be cross-checked against the
# official judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --press <axis> --controller res://logic/controller.gd \
#       --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_vs: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	# translate the judge's frame dict into the view's expected vs keys
	_view_vs = {
		"mines": vs.get("mines", []),
		"pos": vs.get("pos", []),
		"loads": vs.get("loads", []),
		"pushed": vs.get("pushed", []),
		"player_res": int(vs.get("player_res", 0)),
		"frame": int(vs.get("frame", 0)),
	}
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _view_spec, _view_vs)
