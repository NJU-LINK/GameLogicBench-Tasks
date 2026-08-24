extends "res://judge.gd"
#
# RECORD driver for combo_wolfpack — renders the AUTHORITATIVE judge simulation to video.
#
# This is a THIN SHELL over judge.gd (which it extends): the simulation loop, scenario handling,
# per-wolf integration, the windowed encirclement assertion and result writing are all inherited —
# there is exactly ONE simulation, the judged one. This scene only flips on _record_mode (which
# also enables the per-frame physics await in judge.gd's loop, so Movie Maker captures one video
# frame per sim frame) and implements the _on_frame hook: each settled frame is handed to
# game/view.gd (the same vector visuals the F5 preview draws with) and rendered. It still writes
# result.json + prints GEB_RESULT so the recording can be cross-checked against the official
# judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --seed N --scenario <name> [--press <axis>] --controller res://logic/controller.gd \
#       --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_state: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	var vuln := {}
	for p in (vs["prey"] as Array):
		vuln[int(p["id"])] = SimCore.vuln_at(p, int(vs["frame"]))
	_view_state = {"pos": vs["pos"], "prey": vs["prey"], "prey_pos": vs["prey_pos"],
		"vuln": vuln, "ring_radius": SimCore.RING_RADIUS, "unit_radius": SimCore.UNIT_RADIUS}
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _view_spec, _view_state)
