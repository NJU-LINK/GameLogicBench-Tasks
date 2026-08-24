extends "res://judge.gd"
#
# RECORD driver — renders the AUTHORITATIVE judge simulation to video. Thin shell over judge.gd:
# flips _record_mode, implements _on_frame to paint each settled frame via game/view.gd, defers all
# simulation/assertion logic to the parent.
#
# Run (windowed, under Xvfb + software GL):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N --press <axis[,axis]> --controller res://logic/controller.gd \
#       --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_pos: Vector2 = Vector2.ZERO
var _view_plats: Array = []
var _view_goal := 0
var _view_gone: Array = []

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	if vs.get("body") != null:
		_view_pos = (vs["body"] as CharacterBody2D).position
	var live: Array = vs["plats"]
	# A ledge that has left the live set leaves a fading scar in the picture.
	if not _view_plats.is_empty() and live.size() < _view_plats.size():
		for r in _view_plats:
			if not live.has(r):
				_view_gone.append([r, 0])
	for g in _view_gone:
		(g as Array)[1] = int((g as Array)[1]) + 1
	_view_plats = live.duplicate()
	_view_goal = int(vs["goal_idx"])
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty() or _view_plats.is_empty():
		return
	View.render(self, _view_spec, {"body_pos": _view_pos, "plats": _view_plats,
		"goal_idx": _view_goal, "gone": _view_gone})
