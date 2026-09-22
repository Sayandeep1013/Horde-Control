extends GdUnitTestSuite

## Debug Overlay field-presence check (docs/20_Technical_Architecture.md >
## "Debugging, Telemetry & Run Recording" > Debug Overlay bullet;
## phases/PHASE_02_Technical_Foundations/PLAN.md > P1.4's exit criterion:
## "Overlay shows every required field"). Not the phase's single NAMED
## acceptance test (that is the Recorder schema check), but exists for the
## same reason run_recorder_behavior_test.gd exists alongside the schema
## check: an overlay that LOOKS complete but is missing one field's text
## must fail something.
##
## Loads the real overlay.tscn (not just overlay.gd in isolation), so a
## scene-wiring mistake (wrong @onready path, missing child node) is caught
## here too, not just a script-level unit test.

const OverlayScene: PackedScene = preload("res://src/debug/overlay.tscn")

## Every distinct field docs/20's Debug Overlay bullet names, as a
## substring expected to appear somewhere in the rendered text. Transcribed
## from the bullet directly (same independence rationale as the Recorder
## schema check): "FPS (current, median, and 1st percentile...)",
## "entity counts (Enemies, Projectiles, Pickups, Effects)",
## "damage-number, telegraph, and high-intensity-VFX counts",
## "Player/Tower HP and shield", "current Wave/Encounter ID",
## "the Pressure Metric value and its escalation/de-escalation state",
## "the current health quadrant", "the simulation time".
const REQUIRED_FIELD_MARKERS: Array[String] = [
	"FPS", # current/median/1st percentile
	"Enemies", "Projectiles", "Pickups", "Effects",
	"DamageNumbers", "Telegraphs", "HighIntensityVFX",
	"Player HP", "Tower HP", "Tower Shield",
	"Wave", "Encounter",
	"Pressure", "State", # Pressure value + escalation/de-escalation state
	"Health Quadrant",
	"Sim Time",
]

var _overlay: DebugOverlay


func before_test() -> void:
	_overlay = auto_free(OverlayScene.instantiate()) as DebugOverlay
	add_child(_overlay)


func test_process_mode_is_always() -> void:
	# MASTER_SDLC.md > Global Simulation Authority names "the UI CanvasLayer"
	# itself PROCESS_MODE_ALWAYS; see overlay.gd's header comment for why
	# the debug overlay follows that, not SimClock's PAUSABLE.
	assert_int(_overlay.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


func test_every_docs20_field_appears_in_the_rendered_text() -> void:
	_overlay._refresh_text()
	var text: String = _overlay._fields_label.text
	for marker in REQUIRED_FIELD_MARKERS:
		assert_str(text).append_failure_message(
			"missing required Debug Overlay field marker: '%s'\nfull text:\n%s" % [marker, text]
		).contains(marker)


func test_unset_gameplay_fields_show_the_unset_label_not_a_fabricated_value() -> void:
	# No Health/Wave Director/Pressure system exists yet (P2.x); until one
	# calls the typed setters, these fields must read "n/a", never 0 or any
	# other number that could be mistaken for real telemetry.
	_overlay._refresh_text()
	var text: String = _overlay._fields_label.text
	assert_str(text).contains("Player HP: n/a")
	assert_str(text).contains("Wave: n/a  Encounter: n/a")
	assert_str(text).contains("Health Quadrant: n/a")


func test_injected_gameplay_state_is_displayed_once_set() -> void:
	_overlay.set_player_state(42.0)
	_overlay.set_tower_state(300.0, 50.0)
	_overlay.set_wave_encounter("W3", "SwarmCrush")
	_overlay.set_pressure(1.5, "escalating")
	_overlay.set_health_quadrant("PlayerHigh_TowerLow")
	_overlay._refresh_text()
	var text: String = _overlay._fields_label.text
	assert_str(text).contains("Player HP: 42.0")
	assert_str(text).contains("Tower HP: 300.0")
	assert_str(text).contains("Tower Shield: 50.0")
	assert_str(text).contains("Wave: W3  Encounter: SwarmCrush")
	assert_str(text).contains("Pressure: 1.5  State: escalating")
	assert_str(text).contains("Health Quadrant: PlayerHigh_TowerLow")


func test_overlay_starts_hidden_in_the_launched_build() -> void:
	# Author decision 2026-09-23: hidden until F1.
	assert_bool(_overlay.is_overlay_visible()).is_false()
	assert_bool(_overlay.get_node("Panel").visible).is_false()


func test_f1_toggles_overlay_visibility() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = &"debug_overlay_toggle"
	press.pressed = true
	_overlay._unhandled_input(press) # hidden -> shown
	assert_bool(_overlay.is_overlay_visible()).is_true()
	assert_bool(_overlay._fields_label.visible).is_true()
	assert_bool(_overlay.get_node("Panel").visible).is_true()

	_overlay._unhandled_input(press) # shown -> hidden
	assert_bool(_overlay.is_overlay_visible()).is_false()
	assert_bool(_overlay._fields_label.visible).is_false()

	_overlay._unhandled_input(press)
	assert_bool(_overlay.is_overlay_visible()).is_true()


func test_f2_toggles_pseudolocalization_and_sets_the_registered_expansion_ratio() -> void:
	var was_enabled: bool = TranslationServer.is_pseudolocalization_enabled()

	var press: InputEventAction = InputEventAction.new()
	press.action = &"debug_pseudoloc_toggle"
	press.pressed = true
	_overlay._unhandled_input(press)

	assert_bool(TranslationServer.is_pseudolocalization_enabled()).is_not_equal(was_enabled)
	# MASTER_SDLC.md > Provisional Values Register > Technical Caps &
	# Performance > "Debug overlay" row: expansion ratio 0.3.
	var ratio: float = ProjectSettings.get_setting("internationalization/pseudolocalization/expansion_ratio", -1.0)
	assert_float(ratio).is_equal_approx(0.3, 0.0001)

	# Leave global engine state as found for later suites in the same run.
	_overlay._unhandled_input(press)
	assert_bool(TranslationServer.is_pseudolocalization_enabled()).is_equal(was_enabled)
