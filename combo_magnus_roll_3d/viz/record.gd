extends "res://judge.gd"
#
# RECORD driver for combo_magnus_roll_3d -- renders the AUTHORITATIVE judge simulation to video.
#
# A THIN SHELL over judge.gd (which it extends): the world build, the scenario handling, the air-flow
# and turf schedule, the ball's motion and the verdict are all inherited -- there is exactly ONE
# simulation, the judged one. This scene only flips _record_mode on and implements the _on_frame hook:
# it builds the scene's visuals once through game/view.gd, gives the judged ball its mesh, and each
# frame points the wind arrow along the current air flow, drops a trail dot and paints the rough-grass
# slab as soon as the round has placed it (that last one lives here rather than in game/view.gd: the
# previewed round is uniform short grass, and where the rough sits is a hidden-scenario fact).
#
# Run (windowed, under Xvfb + software GL, one video frame per sim frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://logic/controller.gd --out /abs/result.json

const RView = preload("res://view.gd")
const ROUGH_COLOR := Color(0.13, 0.26, 0.13)

var _built := false
var _rough := false

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	if not _built:
		RView.build_scene(self, float(vs["slope_deg"]))
		RView.attach_ball(vs["ball"])
		_built = true
	RView.set_wind(self, vs["wind"])
	RView.trail(self, vs["pos"], int(vs["tick"]))
	if bool(vs["zone_bound"]) and not _rough:
		var frame := RView.turf_frame(self)
		if frame != null:
			var span := 24.0
			var x := float(vs["zone_x"]) + float(vs["zone_sign"]) * span * 0.5
			RView.slab(frame, Vector3(span, 0.05, SimCore.TURF_SIZE.z),
				Vector3(x, 0.025, 0.0), ROUGH_COLOR)
			_rough = true
