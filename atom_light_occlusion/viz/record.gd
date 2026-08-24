extends "res://judge.gd"
#
# RECORD driver for atom_light_occlusion — renders the AUTHORITATIVE judged picture to video.
#
# This is a THIN SHELL over judge.gd (which it extends): chamber building, controller invocation,
# the settle wait, the frame grab and every pixel-relation assertion are all inherited — there is
# exactly ONE judged picture, the recorded one. This scene only flips on _record_mode and
# implements the _on_frame hook (called once, with the spec and the final verdict): it puts the
# game/view.gd instrument overlay (torch anchor, range ring, wall outlines — the same visual code
# the F5 preview draws with) on a top CanvasLayer, so the captured video shows the lit chamber
# with its instruments and the verdict line. It still writes record_result.json + prints
# GEB_RESULT so the recording can be cross-checked against the official judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per engine frame):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario baseline --seed N --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_note := ""

func _init() -> void:
	_record_mode = true

func _on_frame(vs: Dictionary) -> void:
	_view_spec = vs["spec"]
	var result: Dictionary = vs["result"]
	_view_note = "%s  (scenario %s seed %s)" % [
		String(result.get("outcome", "?")).to_upper(),
		String(result.get("scenario", "?")), str(result.get("seed", "?")),
	]
	# instrument overlay on a top layer, above the judged picture and any solution layers
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var overlay := Node2D.new()
	overlay.draw.connect(func() -> void: View.render(overlay, _view_spec, {"note": _view_note}))
	layer.add_child(overlay)
	overlay.queue_redraw()
