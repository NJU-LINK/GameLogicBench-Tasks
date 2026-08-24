extends "res://judge.gd"
#
# RECORD driver for combo_alert_escalation_loop — renders the AUTHORITATIVE judge simulation to video.
#
# This is a THIN SHELL over judge.gd (which it extends): the simulation loop, scenario/press handling,
# assertions and result writing are all inherited — there is exactly ONE simulation, the judged one.
# This scene only flips on _record_mode and implements the _on_frame hook: each settled frame is
# handed to game/view.gd (the same vector visuals the F5 preview draws with) and rendered, so Movie
# Maker captures the judged trajectory with the real game art. It also paints a small last-known
# marker while the guard is under a search obligation — a RECORD-ONLY visual (the search phase is a
# hidden-scenario event, so its skinning lives here in viz/, never in game/view.gd). It still writes
# result.json + prints GEB_RESULT so the recording can be cross-checked against the judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --press <axis:tier[,axis:tier]> \
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
	# record-only: mark the last-known spot the guard is committed to search toward
	if bool(_view_state.get("searching", false)):
		var lk: Vector2 = _view_state.get("last_known", Vector2.ZERO)
		draw_arc(lk, 20.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9), 2.0)
		draw_line(lk + Vector2(-7, 0), lk + Vector2(7, 0), Color(1.0, 0.85, 0.3, 0.9), 1.5)
		draw_line(lk + Vector2(0, -7), lk + Vector2(0, 7), Color(1.0, 0.85, 0.3, 0.9), 1.5)
