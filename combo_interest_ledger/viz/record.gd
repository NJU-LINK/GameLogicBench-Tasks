extends "res://judge.gd"
#
# RECORD driver for combo_interest_ledger — renders the AUTHORITATIVE judge simulation to video.
#
# Thin shell over judge.gd (which it extends): the tick loop, scenario/press handling, assertions and
# result writing are all inherited — there is exactly ONE simulation, the judged one. This scene only
# flips on _record_mode and implements the _on_frame hook: each settled tick is handed to game/view.gd
# (the same visual code the F5 preview draws with) and rendered, so Movie Maker captures the judged
# trajectory with the real game art. It still writes result.json + prints GEB_RESULT so the recording
# can be cross-checked against the official judge verdict.
#
# Run (windowed, under Xvfb + software GL, Movie Maker capturing one video frame per sim tick):
#   xvfb-run -a godot --path <proj> --write-movie <out.avi> res://record.tscn -- \
#       --scenario <name> --seed N [--press axis:tier[,axis:tier]] \
#       --controller res://logic/controller.gd --out /abs/result.json

const View = preload("res://view.gd")

var _view_spec: Dictionary = {}
var _view_board: Dictionary = {}
var _view_events: Array = []

func _init() -> void:
	_record_mode = true

func _ready() -> void:
	# rebuild the same spec the judge builds, for the view (judge.gd builds it locally).
	var args := _parse_args(OS.get_cmdline_user_args())
	var seed_val := int(args.get("seed", "0"))
	var scenario := String(args.get("scenario", ""))
	var press := String(args.get("press", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val if scenario == BASELINE else seed_val + scenario.hash()
	_view_spec = Level.build(rng, scenario, press)
	super._ready()

func _on_frame(vs: Dictionary) -> void:
	_view_board = vs["board"]
	_view_events = vs.get("events", [])
	queue_redraw()

func _draw() -> void:
	if _view_spec.is_empty() or _view_board.is_empty():
		return
	View.render(self, _view_spec, _view_board, _view_events)
