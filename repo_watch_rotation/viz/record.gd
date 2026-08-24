extends "res://judge.gd"
#
# RECORD driver for repo_watch_rotation — renders the AUTHORITATIVE judge simulation to video.
#
# A THIN SHELL over judge.gd (which it extends): the simulation loop, scenario/press handling, meters,
# search bookkeeping and result writing are all inherited — there is exactly ONE simulation, the
# judged one. This scene only flips on _record_mode and implements _on_frame: each settled frame is
# handed to game/view.gd (the same vector visuals the F5 preview draws with) and rendered. It also
# paints a small last-known marker while a guard is under a search obligation — a RECORD-ONLY visual
# (the search phase is a hidden-scenario event, so its skinning lives here in viz/, never in
# game/view.gd). It still writes result.json + prints GEB_RESULT so the recording can be cross-checked
# against the official judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N [--press axis:tier[,axis:tier]] \
#       --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_vs: Dictionary = {}
var _searching := false
var _last_known := Vector2.ZERO

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	_view_vs = {
		"guard_pos": vs["guard_pos"],
		"alarmed": vs["alarmed"],
		"t": vs["t"],
	}
	_searching = bool(vs.get("searching", false))
	_last_known = vs.get("last_known", Vector2.ZERO)
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _view_spec, _view_vs)
	# record-only: mark the last-known spot a roving guard is committed to search toward
	if _searching:
		var lk: Vector2 = _last_known
		draw_arc(lk, 20.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9), 2.0)
		draw_line(lk + Vector2(-7, 0), lk + Vector2(7, 0), Color(1.0, 0.85, 0.3, 0.9), 1.5)
		draw_line(lk + Vector2(0, -7), lk + Vector2(0, 7), Color(1.0, 0.85, 0.3, 0.9), 1.5)
