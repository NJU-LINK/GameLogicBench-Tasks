extends "res://judge.gd"
#
# RECORD driver for atom_plan_orchestrator — renders the AUTHORITATIVE judge simulation to video.
#
# A THIN SHELL over judge.gd (which it extends): the tick loop, scenario handling, assertions and
# result writing are all inherited — there is exactly ONE simulation, the judged one. This scene
# only flips on _record_mode and implements the _on_frame hook: each tick's world dict is handed to
# game/view.gd (the same vector dashboard the F5 preview draws) and rendered, so Movie Maker captures
# the judged trajectory. It still writes result.json + prints GEB_RESULT for cross-checking.
#
# Run (windowed, under Xvfb + software GL, Movie Maker one video frame per engine frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _view_w: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_w = vs["w"]
	queue_redraw()

func _draw() -> void:
	if _view_w.is_empty():
		return
	View.render(self, _view_w)
