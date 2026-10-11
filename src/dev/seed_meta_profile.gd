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

	var wins: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--win="): # v1.0: record a victory per difficulty id, e.g. --win=soldier,veteran
			for id in arg.trim_prefix("--win=").split(","):
				if id != "":
					wins.append(id)

	var achievements: Array[String] = []
	var boss_kills: Array[String] = []
	var champion: String = ""
	var relics: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		# WP-LOADOUT capture helpers: --achievements=a,b  --boss-kills=warchief,king  --champion=id  --relics=a,b
		if arg.begins_with("--achievements="):
			achievements.assign(Array(arg.trim_prefix("--achievements=").split(",")))
		elif arg.begins_with("--boss-kills="):
			boss_kills.assign(Array(arg.trim_prefix("--boss-kills=").split(",")))
		elif arg.begins_with("--champion="):
			champion = arg.trim_prefix("--champion=")
		elif arg.begins_with("--relics="):
			relics.assign(Array(arg.trim_prefix("--relics=").split(",")))

	MetaProgress.ensure_loaded()
	for id in achievements:
		MetaProgress.set_achievement_unlocked_for_test(id)
	for id in boss_kills:
		MetaProgress.set_boss_kills_for_test(id, 1)
	for id in wins:
		MetaProgress.settle_run({"run_id": "seed_win_%s_%d" % [id, Time.get_ticks_usec()], "sim_time_seconds": 900.0, "waves_cleared": 15, "kills": 400, "victory": true, "difficulty_id": id, "wave_reached": 15, "elite_kills": 6})
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

	if champion != "":
		MetaProgress.set_selected_champion(champion)
	for i in relics.size():
		MetaProgress.set_selected_relic(i, relics[i])
	print("SEEDED profile at ", MetaProgress.get_base_path_for_test(), " cores=", MetaProgress.get_cores())
	get_tree().quit()
