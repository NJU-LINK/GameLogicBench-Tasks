extends "res://judge.gd"
#
# RECORD driver for atom_group_avoidance — renders the AUTHORITATIVE judge simulation to video.
#
# This is a THIN SHELL over judge.gd (which it extends): the simulation loop, scenario handling,
# per-unit avoidance, assertions and result writing are all inherited — there is exactly ONE
# simulation, the judged one. This scene only flips on _record_mode and implements the _on_frame
# hook: each settled frame is handed to game/view.gd (the same vector visuals the F5 preview
# draws with) and rendered, so Movie Maker captures the judged trajectory. It still writes
# record_result.json + prints GEB_RESULT so the recording can be cross-checked against the
# official judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --seed N --scenario baseline --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_state: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	_view_state = vs
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _view_spec, _view_state)
