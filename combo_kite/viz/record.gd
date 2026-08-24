extends "res://judge.gd"
#
# RECORD driver for combo_kite — renders the AUTHORITATIVE judge simulation to video.
#
# This is a THIN SHELL over judge.gd (which it extends): the simulation loop, scenario handling,
# assertions and result writing are all inherited — there is exactly ONE simulation, the judged
# one. This scene only flips on _record_mode and implements the _on_frame hook: each settled frame
# is handed to game/view.gd (the same visual code the F5 preview draws with) and rendered, so
# Movie Maker captures the judged trajectory with the real game art.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --press <axis> --controller res://logic/controller.gd --out /abs/result.json

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
	# Judge-side geometry the preview twin never draws (pocket_door scenario): the divider/pocket
	# walls and, once closed, the door plug. Painted here in viz/ — game/view.gd must stay free
	# of hidden-scenario knowledge (TASK_AUTHORING §1: viz/ owns hidden-only visuals).
	for r in _view_spec.get("extra_walls", []):
		draw_rect(r, Color(0.45, 0.4, 0.35))
	if bool(_view_state.get("door_closed", false)) and _view_spec.has("door_rect"):
		draw_rect(_view_spec["door_rect"], Color(0.7, 0.35, 0.3))
