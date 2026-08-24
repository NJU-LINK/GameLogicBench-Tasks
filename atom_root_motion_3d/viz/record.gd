extends "res://judge.gd"
#
# RECORD driver for atom_root_motion_3d — renders the AUTHORITATIVE judge simulation to video. A THIN
# SHELL over judge.gd: the animation clock, physics settle, controller loop, assertions and result
# writing are all inherited (one simulation, the judged one). This scene only flips _record_mode on,
# builds the visual scene + character mesh once, and follows the character with the third-person
# camera each stepped frame through game/view.gd.
#
# Run (windowed under Xvfb + software GL, Movie Maker one video frame per physics frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://logic/controller.gd --out /abs/result.json

const RView = preload("res://view.gd")

var _built := false
var _cam: Camera3D
var _cvis: MeshInstance3D

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	var body: CharacterBody3D = vs["body"]
	if not _built:
		_cam = RView.build_scene(self, vs["spec"])
		_cvis = RView.attach_character(body)
		_built = true
	RView.follow(_cam, body.global_position)
	RView.set_arrived(_cvis, bool(vs.get("arrived", false)))
