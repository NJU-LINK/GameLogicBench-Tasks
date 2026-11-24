# GameLogicBench — Task Library

The dataset for GameLogicBench: 72 tasks (21 atom, 28 combo, 23 repo). Each task
is a Godot 4.4 project with one gameplay mechanism hollowed out, together with a
frozen judge and reference solutions.

Place this library at `tasks/` under the harness repository root.

Twenty of the Repo-tier tasks vendor upstream open-source Godot projects; each carries
that project's own license files and a `README_UPSTREAM.md` (or `NOTICE_UPSTREAM.md`)
recording the source and every material change. The other three —
`repo_damage_control`, `repo_td_income` and `repo_watch_rotation` — were written from
scratch for GameLogicBench and contain no third-party code or media.

## License

Code written for GameLogicBench is released under the MIT License, and task briefs,
specifications and documentation under CC BY 4.0; see [`LICENSE`](LICENSE). Vendored
third-party files keep their upstream licenses, listed in [`NOTICE.md`](NOTICE.md). One task,
`repo_turbofat_piece_phase`, contains game resources under CC BY-NC 4.0 and may be used for
non-commercial purposes only.
