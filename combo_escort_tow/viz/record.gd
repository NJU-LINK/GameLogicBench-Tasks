extends "res://judge.gd"
#
# RECORD driver for combo_escort_tow — renders the AUTHORITATIVE judge simulation to video.
#
# This is a THIN SHELL over judge.gd (which it extends): the simulation loop, scenario/press
# handling, assertions and result writing are all inherited — there is exactly ONE simulation, the
# judged one. This scene only flips on _record_mode and implements the _on_frame hook: each settled
# frame is handed to game/view.gd (the same vector visuals the F5 preview draws with) and rendered,
# so Movie Maker captures the judged trajectory with the real game art. It also paints the closing
# doors once they have shut — a RECORD-ONLY visual (the mid-run close is a hidden-scenario event, so
# its skinning lives here in viz/, never in game/view.gd). It still writes result.json + prints
# GEB_RESULT so the recording can be cross-checked against the official judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N [--press <axis:tier[,axis:tier]>] \
#       --controller res://logic/controller.gd --out /abs/result.json

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
	# record-only: paint the closing doors that have shut (hidden-scenario event skinning)
	var doors: Array = _view_spec.get("doors", [])
	var closed: int = int(_view_state.get("doors_closed", 0))
	for i in range(min(closed, doors.size())):
		draw_rect(doors[i]["rect"], Color(0.5, 0.28, 0.28))
