extends "res://judge.gd"
#
# RECORD driver for repo_td_income — renders the AUTHORITATIVE judge simulation to video.
#
# THIN SHELL over judge.gd (which it extends): the simulation loop, scenario handling, assertions
# and result writing are all inherited — there is exactly ONE simulation, the judged one. This scene
# only flips on _record_mode and implements the _on_frame hook: each settled frame's board is handed
# to game/view.gd (the same vector visuals the F5 preview draws with) and rendered, so Movie Maker
# captures the judged trajectory. It still writes result.json + prints GEB_RESULT so the recording
# can be cross-checked against the official judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N [--press axis:tier[,axis:tier]] \
#       --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _view_board: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_board = vs["board"]
	queue_redraw()

func _draw() -> void:
	if _view_board.is_empty():
		return
	View.render(self, _view_board)
