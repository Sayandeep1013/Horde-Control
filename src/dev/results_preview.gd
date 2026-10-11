extends Node
## Development-only preview of the v1.0 Results screen with sample data, for the
## capture harness (WP-META, D254). Nothing in scenes/ references it.
##   ... scene_capture.tscn -- --scene=res://src/dev/results_preview.tscn \
##       --out=sandbox/captures/meta/results --meta-profile-dir=<abs dir> [--victory] [--endless]
## `--victory` shows a win; `--endless` an Endless defeat. It never settles a run
## and never writes a profile.

func _ready() -> void:
	UiStrings.ensure_registered()
	var victory: bool = false
	var endless: bool = false
	for arg in OS.get_cmdline_user_args():
		victory = victory or arg == "--victory"
		endless = endless or arg == "--endless"
	var screen: RunEndScreen = (load("res://scenes/ui/run_end.tscn") as PackedScene).instantiate() as RunEndScreen
	add_child(screen)
	var report: Array[Dictionary] = []
	for entry in [["bow", 18400.0], ["ballista", 9100.0], ["flame_arrows", 6200.0], ["tower_bow", 5300.0], ["burn", 3900.0], ["whirling_axes", 2600.0], ["caltrops", 900.0]]:
		report.append({"source_id": entry[0], "damage": entry[1]})
	screen.show_summary({
		"outcome_title": "Victory" if victory else "Defeated", "cause_text": "" if victory else "You were defeated",
		"wave_reached": 15 if victory else 22 if endless else 11, "wave_total": 15, "scrap_held": 140, "time_survived_seconds": 905.0 if victory else 640.0,
		"kills": 512, "elite_kills": 9, "difficulty_name": "Veteran", "endless": endless, "run_seed": 4242, "damage_report": report,
	})
	screen.set_settlement({
		"lines": [
			{"label": "Time survived (15 min)", "amount": 15}, {"label": "Waves cleared (15)", "amount": 30},
			{"label": "Enemies defeated (512)", "amount": 20}, {"label": "Elites defeated (9)", "amount": 9},
			{"label": "Scrap (140)", "amount": 14}, {"label": "Victory", "amount": 10},
			{"label": "Settlement bonus (+20%)", "amount": 20}, {"label": "Veteran difficulty (x1.4)", "amount": 46},
		] if victory else [{"label": "Time survived (10 min)", "amount": 10}, {"label": "Waves cleared (11)", "amount": 22}, {"label": "Enemies defeated (512)", "amount": 20}],
		"total_cores": 164 if victory else 52, "saved": true,
		"new_best_waves": true, "new_best_endless_wave": endless, "unlocked_difficulty": "warlord" if victory else "", "unlocked_endless": victory,
		"newly_unlocked_achievements": [{"id": "founder", "display_name": "Founder"}] if victory else [],
	})
	screen.set_active(true)
