class_name DraftTestHelpers
extends RefCounted

## Shared factory helpers for the six P2.12 named-acceptance-test suites
## (draft_queue_test.gd, draft_input_lockout_test.gd,
## guaranteed_first_draft_test.gd, encounter_deferral_test.gd,
## draft_determinism_test.gd, xp_cap_check_test.gd), so each suite's own
## before_test() stays short. Not a gdUnit4 suite itself.

const EconomyConfig: EconomyConfiguration = preload("res://data/economy/prototype.tres")
const DraftControllerScript: GDScript = preload("res://src/ui/draft_controller.gd")
const PauseAuthorityScript: GDScript = preload("res://src/core/pause_authority.gd")
const SimClockScript: GDScript = preload("res://src/core/sim_clock.gd")


## A real UpgradeSystem, its own real 8-card authored pool
## (upgrade_definitions' inline preload() defaults), indexed by _ready()
## (which requires being in a live tree -- the caller must add_child() +
## auto_free() the result, matching tests/unit/upgrade_effect_check_test.gd's
## own established convention).
static func build_upgrade_system() -> UpgradeSystem:
	return UpgradeSystem.new()


## A real RunInventory, configured against the real prototype economy
## (Register-authored XP curve, 5 + 3(L+1) -- Author decision D108,
## 2026-09-23; the teaching-wave XP cap this comment used to cite, C-XPCAP,
## is removed). event_bus is explicitly null -- RunInventory.configure()'s
## own guarded _connect_player_died() no-ops on a null bus, so this never
## touches the real EventBus autoload from an isolated suite.
static func build_run_inventory() -> RunInventory:
	var inv := RunInventory.new()
	inv.configure(EconomyConfig, null)
	return inv


static func build_draft_controller() -> DraftController:
	return DraftControllerScript.new() as DraftController


static func build_fresh_pause_authority() -> Node:
	return PauseAuthorityScript.new()


static func build_fresh_sim_clock() -> Node:
	return SimClockScript.new()
