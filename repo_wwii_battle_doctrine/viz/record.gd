extends "res://judge.gd"
#
# repo_wwii_battle_doctrine RECORD shell. Extends the frozen judge driver so the RENDERED run IS the
# judged simulation. _record_mode flips the driver: it skips the bootstrap re-exec (the record pipeline
# does its own --import), and _drive awaits a physics frame after each command so Movie Maker captures
# the real battle.tscn (2D hex board + unit draw + damage popups) resolving through the engine under
# test. Judging is unaffected (the judge path never sets _record_mode).

func _init() -> void:
	_record_mode = true

func _on_frame(_vs: Dictionary) -> void:
	# battle.tscn self-renders; nothing extra to draw.
	pass
