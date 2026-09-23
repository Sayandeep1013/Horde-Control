extends GdUnitTestSuite

## UI pass (phases/UI_PASS/LEDGER.md, UR-21). `src/ui/dev/ui_capture.gd`
## stages UI states in the assembled prototype by node path and, for states
## that otherwise take minutes of play, by private member. Nothing else
## tells anyone when a rename breaks it: the tool is run by hand, rarely,
## and a missing member there fails only at the moment a screenshot is
## needed. This asserts that everything the tool reaches for still resolves
## on `scenes/prototype.tscn`. The lists below are transcribed from the
## tool by hand, deliberately - reading them out of the tool would only
## prove the tool agrees with itself.

const PrototypeScene: PackedScene = preload("res://scenes/prototype.tscn")

## D115 (no in-run shop): the Tower Console node/script is removed from
## scenes/prototype.tscn and from src/ui/dev/ui_capture.gd's own capture
## sequence -- CONSOLE_PROPERTIES/CONSOLE_METHODS and the "Console" node
## path below are removed with it, not merely left unused.
const NODE_PATHS: Array[String] = [
	"DraftInstance",
	"RunFlowController",
	"Main/Tower",
	"Main/Player",
	"Main/Player/GameCamera",
	"ThreatFeedbackLayer/Overlay",
]

const FLOW_METHODS: Array[String] = ["_end_run", "_on_pause_action_pressed"]
const FLOW_PROPERTIES: Array[String] = ["pause_menu", "settings_menu"]
const DRAFT_METHODS: Array[String] = ["force_open_for_test", "simulate_hover_for_test", "skip_lockout_for_test", "confirm_choice_for_test"]

var _proto: Node = null


func before_test() -> void:
	_proto = auto_free(PrototypeScene.instantiate())
	add_child(_proto)


func _has_property(object: Object, property: String) -> bool:
	for entry: Dictionary in object.get_property_list():
		if entry["name"] == property:
			return true
	return false


func test_every_node_the_capture_tool_fetches_exists() -> void:
	for path: String in NODE_PATHS:
		assert_object(_proto.get_node_or_null(path)).append_failure_message("ui_capture.gd fetches '%s', which is not in scenes/prototype.tscn" % path).is_not_null()
	var tower: Node = _proto.get_node("Main/Tower")
	assert_object(tower.find_child("Hurtbox", true, false)).append_failure_message("ui_capture.gd stages threat feedback through the Tower's 'Hurtbox'").is_not_null()
	assert_object(tower.find_child("TowerHealth", true, false)).append_failure_message("ui_capture.gd reads Tower health through 'TowerHealth'").is_not_null()
	assert_bool(tower.find_child("Hurtbox", true, false).has_signal(&"damage_received")).is_true()


func test_every_member_the_capture_tool_reaches_into_exists() -> void:
	var flow: Node = _proto.get_node("RunFlowController")
	for method: String in FLOW_METHODS:
		assert_bool(flow.has_method(method)).append_failure_message("RunFlowController no longer has %s(); update src/ui/dev/ui_capture.gd" % method).is_true()
	for property: String in FLOW_PROPERTIES:
		assert_bool(_has_property(flow, property)).append_failure_message("RunFlowController no longer has '%s'; update src/ui/dev/ui_capture.gd" % property).is_true()
	assert_bool((flow.get_script() as Script).get_script_constant_map().has("EndCause")).append_failure_message("RunFlowController no longer has the EndCause enum").is_true()

	var draft: Node = _proto.get_node("DraftInstance")
	for method: String in DRAFT_METHODS:
		assert_bool(draft.has_method(method)).append_failure_message("DraftController no longer has %s(); update src/ui/dev/ui_capture.gd" % method).is_true()

	assert_bool(PauseAuthority.has_method("get_active_reasons")).is_true()
