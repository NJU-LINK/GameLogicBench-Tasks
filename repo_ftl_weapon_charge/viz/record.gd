extends "res://judge.gd"
#
# RECORD driver for repo_ftl_weapon_charge — renders the AUTHORITATIVE judge simulation to video.
#
# THIN SHELL over judge.gd (which it extends): the scenario table, the judge-authoritative tuning,
# the player-side script (target orders / re-arming / beam sweeps / shield window / crew moves), the
# frozen-side observation channels, the oracles and the verdict are all inherited — there is exactly
# ONE simulation, the judged one. The picture is the game's own: the judge instantiates the real
# TacticalSpaceCombat.tscn, so a windowed run shows the upstream GDQuest art (both ships, the rooms
# and crew, the beam sweeps, the shield bubble, the HP labels) doing exactly what the verdict is
# about. Nothing needs drawing here — the hook only exists so the judge's per-frame recording branch
# fires and Movie Maker captures every frame.
#
# The only difference from a judged run is skipping the bootstrap re-exec (_record_mode): the record
# pipeline pre-imports the project itself, and Movie Maker pins the frame pacing that the bootstrap's
# --fixed-fps 60 otherwise provides.
#
# NOTE (record is a degraded, display-only channel — TASK_AUTHORING §9.2 P2.5): the mp4 must be
# produced and readable; a cross-check MISMATCH is logged, not gated.

func _init() -> void:
	_record_mode = true


func _on_frame(_vs: Dictionary) -> void:
	pass
