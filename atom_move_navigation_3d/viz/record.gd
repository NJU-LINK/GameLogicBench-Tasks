extends "res://judge.gd"
#
# RECORD driver for atom_move_navigation_3d — renders the AUTHORITATIVE judge simulation to video. A
# THIN SHELL over judge.gd: the nav bake, physics loop, scenario handling, assertions and result
# writing are all inherited (one simulation, the judged one). This scene only flips _record_mode on,
# builds the visual scene + agent once, and moves/follows the agent each stepped frame through
# game/view.gd.
#
# Run (windowed under Xvfb + software GL, Movie Maker one video frame per physics frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://logic/controller.gd --out /abs/result.json

const RView = preload("res://view.gd")

var _built := false
var _cam: Camera3D
var _avis: MeshInstance3D

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	var pos: Vector3 = vs["pos"]
	if not _built:
		_cam = RView.build_scene(self, vs["spec"])
		_avis = RView.spawn_agent(self, pos)
		_built = true
	RView.move_agent(_avis, pos)
	RView.follow(_cam, pos)
	RView.set_arrived(_avis, bool(vs.get("arrived", false)))
