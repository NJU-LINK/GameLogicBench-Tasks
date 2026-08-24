extends "res://judge.gd"
#
# RECORD driver for combo_lane_deny — renders the AUTHORITATIVE judge simulation to video.
#
# This is a THIN SHELL over judge.gd (which it extends): the simulation loop, scenario/press
# handling, deny/complete assertions and result writing are all inherited — there is exactly ONE
# simulation, the judged one. This scene only flips on _record_mode and implements the _on_frame
# hook: each settled frame is handed to game/view.gd (the same vector visuals the F5 preview draws
# with) and rendered, so Movie Maker captures the judged trajectory.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N [--press ...] --controller res://logic/controller.gd --out /abs/r.json

const View = preload("res://view.gd")
const SimCoreViz = preload("res://sim_core.gd")

var _view_spec: Dictionary = {}
var _view_vs: Dictionary = {}

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	var box := SimCoreViz.def_box()
	_view_vs = {
		"def_pos": vs["def_pos"],
		"def_radius": SimCoreViz.DEF_RADIUS,
		"passer_pos": vs["passer_pos"],
		"passer_facing": vs["passer_facing"],
		"passer_phase": vs["passer_phase"],
		"ball_pos": vs["ball_pos"],
		"ball_vel": vs["ball_vel"],
		"ball_radius": SimCoreViz.BALL_RADIUS,
		"receivers": vs["receivers"],
		"box_pos": box.position,
		"box_size": box.size,
		"denies": vs["denies"],
		"conceded": vs["conceded"],
		"frame": vs["frame"],
	}
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty():
		return
	View.render(self, _view_spec, _view_vs)
