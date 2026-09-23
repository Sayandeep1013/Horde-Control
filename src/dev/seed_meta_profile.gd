extends Node
## Development-only meta-profile seeder (visual verification session,
## 2026-09-23: the skill tree art pass). Grants a fixed amount of Cores and
## buys a small, fixed set of ranks against whatever save directory
## `MetaProgress` resolves at its own `_ready()` -- i.e. `--meta-profile-dir=
## <dir>` on the SAME command line (`src/meta/meta_progress.gd`'s own
## `_resolve_base_path_from_cmdline()`; this scene never reads that flag
## itself, and never touches `MetaProgress.set_base_path_for_test()`, so a
## run with NO `--meta-profile-dir=` would seed the real `user://` profile --
## always pass it). Not part of the shipped game; nothing in scenes/
## references it. Mirrors src/dev/scene_capture.gd's own "dev-only harness"
## convention (including quitting itself once done) so the capture tool's
## own hard constraint ("never touch the real user profile") is satisfied by
## construction: this scene has no code path that can write anywhere else.
##
## Usage (run BEFORE the capture, against the SAME --meta-profile-dir):
##   Godot_v4.7.1-stable_win64_console.exe --headless --path . \
##     res://src/dev/seed_meta_profile.tscn -- \
##     --meta-profile-dir=<abs sandbox dir> [--cores=40] [--buy=vitality,vitality,swift_boots]
##
## `--buy` entries are applied in order via MetaProgress.buy() (the real
## purchase path -- price, prerequisites, and reveal all apply exactly as a
## live Hub session would), so a rank the tree cannot yet afford or that is
## still locked is simply skipped (silently -- see `_ready()`) rather than
## corrupting the profile.

const DEFAULT_CORES: int = 40
const DEFAULT_BUYS: Array[String] = ["vitality", "vitality", "swift_boots", "stone_walls"]


func _ready() -> void:
	var cores: int = DEFAULT_CORES
	var buys: Array[String] = DEFAULT_BUYS.duplicate()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cores="):
			cores = int(arg.trim_prefix("--cores="))
		elif arg.begins_with("--buy="):
			buys.clear()
			for id in arg.trim_prefix("--buy=").split(","):
				if id != "":
					buys.append(id)

	MetaProgress.ensure_loaded()
	if cores > 0:
		# The real production route (docs/18/Register "Meta: Run-End
		# Settlement"): 1 Core per simulated minute at 0 waves/0 kills/no
		# victory, matching tests/unit/skill_tree_screen_test.gd's own
		# `_grant_cores()` fixture helper. `_save()` runs inside settle_run()
		# itself (that method's own header: "Commits to disk ... before
		# returning").
		MetaProgress.settle_run({
			"run_id": "seed_meta_profile_%d" % Time.get_ticks_usec(),
			"sim_time_seconds": float(cores) * 60.0,
			"waves_cleared": 0, "kills": 0, "victory": false, "abandoned": false,
		})

	for id in buys:
		# buy() itself is a no-op (returns false, changes nothing) for a
		# locked or unaffordable id -- see can_buy()'s own guards -- so an
		# id ordered before its own prerequisite, or one this seed cannot
		# afford, is simply skipped rather than failing the whole seed.
		MetaProgress.buy(id)

	print("SEEDED profile at ", MetaProgress.get_base_path_for_test(), " cores=", MetaProgress.get_cores())
	get_tree().quit()
