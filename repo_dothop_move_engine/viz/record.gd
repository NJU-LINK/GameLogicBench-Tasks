extends "res://judge.gd"
#
# RECORD driver for repo_dothop_move_engine — renders the AUTHORITATIVE judge simulation to video.
#
# Thin shell over judge.gd (extended): the drive loop, scenario handling, assertions and result
# writing are all inherited — there is exactly ONE simulation, the judged one (the agent's engine
# driving the vendored world). This scene flips on _record_mode and implements _on_frame: each
# executed move's observable world is handed to game/view.gd (the same vector visuals the F5 preview
# draws with). It still writes result.json + prints GEB_RESULT so the recording can be cross-checked
# against the official verdict.
#
# Run (windowed, Xvfb + software GL, Movie Maker one video frame per engine frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://engine/move_engine.gd --out /abs/result.json

const View = preload("res://view.gd")
const SimCoreR = preload("res://sim_core.gd")

var _view_spec: Dictionary = {}
var _view_vs: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	var st = vs["st"]
	_view_spec = vs["spec"]
	_view_vs = {
		"st": st,
		"step": int(vs.get("step", 0)),
		"steps": (vs["spec"] as Dictionary).get("script", []).size(),
		"dots_remaining": SimCoreR.dots_remaining(st),
		"last_dir": String(vs.get("last_dir", "")),
		"note": String(vs.get("note", "")),
	}
	queue_redraw()

func _draw() -> void:
	if _view_vs.is_empty():
		return
	View.render(self, _view_spec, _view_vs)
