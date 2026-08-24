extends "res://judge.gd"
#
# RECORD driver for atom_dice_read — renders the AUTHORITATIVE judge simulation to video. A THIN
# SHELL over judge.gd: the physics loop, scenario handling, assertions and result writing are all
# inherited (one simulation, the judged one). This scene only flips _record_mode on, builds the
# visual scene once, gives each die its mesh, and renders each stepped frame through game/view.gd.
#
# Run (windowed under Xvfb + software GL, Movie Maker one video frame per physics frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --controller res://logic/controller.gd --out /abs/result.json

const RView = preload("res://view.gd")

var _built := false
var _rvis: Dictionary = {}         # die id -> MeshInstance3D

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	if not _built:
		RView.build_scene(self)
		# attach a mesh to each live rigid body child of the level root
		for c in _level_root.get_children():
			if c is RigidBody3D:
				var body: RigidBody3D = c
				_rvis[int(body.get_meta("die_id", 0))] = RView.attach_die(body)
		_built = true
	var reported: bool = bool(vs.get("reported", false))
	for d in vs.get("dice", []):
		var id := int(d["id"])
		if _rvis.has(id):
			RView.set_reported(_rvis[id], reported)
