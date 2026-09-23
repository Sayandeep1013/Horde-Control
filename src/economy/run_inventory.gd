extends RefCounted
class_name RunInventory

## Run Inventory (P2.10; MASTER_SDLC.md > Provisional Values Register >
## "Economy & Pickups"; > Content Data Contracts > "Economy Configuration
## Contract"). Owns the run-scoped Scrap balance and the XP/level curve.
## Cores are explicitly out of prototype scope (task brief: "Cores are out
## of prototype scope for the prototype") -- no Core field exists here, and
## the overflow hopper does not exist in the prototype (Register > Economy
## & Pickups > "Scrap": "the prototype has no hopper").
##
## Exposes the SAME field shape src/ui/hud_economy_state.gd already
## declares -- scrap_current, scrap_cap, xp_current,
## xp_required_for_next_level, level -- per this task's own brief, "so the
## orchestrator can wire the HUD to it without rewriting the HUD". See
## apply_to_hud_state() below, which is the one-line integration point; this
## class is never assigned directly to Hud.economy_state (that field is
## strictly typed HudEconomyState, src/ui/hud.gd), so a copy is unavoidable.
##
## Deliberately a RefCounted, not a Node, mirroring HudEconomyState's own
## choice ("a plain typed data holder ... never saved, never shown in an
## inspector"). This class DOES carry behaviour (crediting, the level
## curve, the player_died reaction) unlike HudEconomyState, but a
## RefCounted can still be a signal connection target (any Object can), so
## nothing here requires a place in the scene tree.

## Register > Economy & Pickups > "Scrap": "Cap 200 (HUD 'n/200')." Used
## only until configure() runs with a real EconomyConfiguration.
const SCRAP_CAP_DEFAULT: int = 200

var scrap_current: int = 0
var scrap_cap: int = SCRAP_CAP_DEFAULT

## MASTER_SDLC.md > "Experience (XP)": "A run starts at level 0." This
## differs from HudEconomyState's own default of 1 -- that field's header
## names its own value a placeholder ("no XP curve exists yet (Phase 05);
## kept > 0 so the HUD never divides by zero"). This class IS that XP curve
## now, and starts from the master's stated level instead;
## apply_to_hud_state() overwrites the HUD's placeholder with this real
## value once wired, which is worth the orchestrator knowing rather than
## silently differing -- named here and in the P2.10 evidence report.
var level: int = 0
var xp_current: float = 0.0
var xp_required_for_next_level: float = 1.0 # placeholder until configure() runs; kept > 0 so a caller never divides by zero, matching HudEconomyState's own stated reason

var _xp_level_cost: XpLevelCost = null
var _event_bus: Object = null

## Meta layer core (Scholar node). MASTER_SDLC.md > Provisional Values
## Register > "Meta: Skill Tree effects": "Scholar +10% XP from shards (3)".
## Set once at run start by `MetaLoadoutApplier`; REPLACES (never compounds)
## on a repeat call, matching this project's own C-STACK "one already-summed
## multiplier" convention (src/combat/auto_weapon.gd's `set_damage_
## multiplier()` header). Defaults to 1.0 (no bonus), so every existing
## caller that never sets this is unaffected.
var _xp_gain_multiplier: float = 1.0


func configure(economy: EconomyConfiguration, event_bus: Object = EventBus) -> void:
	assert(economy != null, "RunInventory.configure() requires a real EconomyConfiguration")
	scrap_cap = economy.scrap_cap
	_xp_level_cost = economy.xp_level_cost
	if _xp_level_cost != null:
		xp_required_for_next_level = float(_xp_level_cost.compute_level_cost(level))
	_connect_player_died(event_bus)


## P2.10 task brief: "another implementer is adding an EventBus.player_died
## signal RIGHT NOW: connect to it by name, and if it does not exist yet
## when you look, write your listener against that name anyway, guard the
## connection, and record the dependency in your report." Confirmed by grep
## at the time this was written: src/core/event_bus.gd declares only
## enemy_died, tower_damaged, and draft_opened -- no player_died (see the
## P2.10 evidence report, "Dependencies"). has_signal() guards the miss
## instead of erroring; is_connected() guards a double-connect on a second
## configure() call. The handler below accepts (and ignores) up to four
## optional arguments so it tolerates whatever signature player_died is
## actually declared with once it lands, since that signature is unknown as
## of this writing.
func _connect_player_died(event_bus: Object) -> bool:
	_event_bus = event_bus
	if _event_bus == null or not _event_bus.has_signal("player_died"):
		return false
	var callable: Callable = Callable(self, "_on_player_died")
	if not _event_bus.is_connected("player_died", callable):
		_event_bus.connect("player_died", callable)
	return true


## Test/orchestrator seam: re-attempt the connection later (e.g. once the
## real EventBus.player_died lands, or a wave/run-flow system supplies a
## fresh EventBus reference) without rebuilding this RunInventory.
func try_connect_player_died(event_bus: Object = EventBus) -> bool:
	return _connect_player_died(event_bus)


func is_player_died_connected() -> bool:
	return _event_bus != null and _event_bus.has_signal("player_died") \
		and _event_bus.is_connected("player_died", Callable(self, "_on_player_died"))


## MASTER_SDLC.md (task brief): "On PLAYER death, carried Scrap goes to
## zero and nothing carries to the next run." Register > Economy & Pickups
## > "Scrap": "carried and lost on death" / "unspent Scrap discarded at run
## end". The prototype has no hopper (Register), so there is nothing else
## to zero; XP/level are not reset here -- starting a fresh run (clearing
## the whole inventory, including XP/level) is Run Flow's job (P2.14), not
## named as this task's own rule, which speaks only to Scrap.
func _on_player_died(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void:
	scrap_current = 0


## Register > Economy & Pickups > "Scrap": "the prototype has no hopper
## (overflow discarded with a FULL indicator)" -- clamped at scrap_cap,
## excess silently discarded, never queued anywhere else.
func credit_scrap(amount: int) -> void:
	if amount <= 0:
		return
	scrap_current = mini(scrap_current + amount, scrap_cap)


func is_scrap_full() -> bool:
	return scrap_current >= scrap_cap


## MASTER_SDLC.md > "Experience (XP)": "advancing from level L to level L+1
## costs 10 + 5(L+1) XP ... any XP earned beyond what a level-up consumes
## carries over as the remainder toward the next level." A while loop, not
## a single if, so one large XP credit can carry through more than one
## level-up in the same call, matching "remainder ... toward the next
## level" applying repeatedly rather than only once. Sets
## _level_up_requested for consume_level_up_requested() (SimLoop step 11's
## seam) to report to a future Draft system (P2.12; opening the Draft
## itself is out of this task's scope).
var _level_up_requested: bool = false

## Typed command (Meta layer core). Also usable directly from a test.
func set_xp_gain_multiplier(multiplier: float) -> void:
	_xp_gain_multiplier = multiplier


## Typed command (Meta layer core, War Chest node). MASTER_SDLC.md >
## Provisional Values Register > "Meta: Skill Tree effects": "War Chest:
## start at level 1 ... when the first wave begins". Mirrors
## src/ui/draft_controller.gd's own `_grant_forced_level()` shape (also
## authored for the master's forced-first-level rule): raises `level` if it
## has not already reached `level_value` from a real level-up, recomputes
## `xp_required_for_next_level` from the new level, and leaves `xp_current`
## untouched. Defensive against lowering a level a real level-up already
## reached, exactly like the Draft's own version.
func grant_meta_starting_level(level_value: int) -> void:
	if level < level_value:
		level = level_value
	if _xp_level_cost != null:
		xp_required_for_next_level = float(_xp_level_cost.compute_level_cost(level))


func credit_xp(amount: float) -> void:
	if amount <= 0.0:
		return
	amount *= _xp_gain_multiplier
	xp_current += amount
	if _xp_level_cost == null:
		return # no curve configured yet (defensive; every real spawn calls configure() first)
	while xp_current >= xp_required_for_next_level:
		xp_current -= xp_required_for_next_level
		level += 1
		_level_up_requested = true
		xp_required_for_next_level = float(_xp_level_cost.compute_level_cost(level))


## SimLoop step 11 seam (docs/20 > "SimLoop order": "A level-up requested
## at step 11 counts as an open Level-Up Draft for step 13"). Returns true
## at most once per level-up and clears the flag, so a caller polling every
## tick observes each level-up exactly once. Opening the actual Level-Up
## Draft is P2.12's scope, not this task's; this is the hook P2.12 reads.
func consume_level_up_requested() -> bool:
	var requested: bool = _level_up_requested
	_level_up_requested = false
	return requested


## Copies this run's live state into `hud_state` using the exact field
## names src/ui/hud_economy_state.gd already declares, per this task's
## brief ("the SAME field shape ... so the orchestrator can wire the HUD to
## it without rewriting the HUD"). hud_state.hopper_amount,
## rerolls_remaining, wave_current/wave_total are left untouched -- they
## belong to other systems (no hopper in the prototype; rerolls/wave are
## P2.12/P2.8's fields, not this task's).
func apply_to_hud_state(hud_state: HudEconomyState) -> void:
	hud_state.scrap_current = scrap_current
	hud_state.scrap_cap = scrap_cap
	hud_state.xp_current = xp_current
	hud_state.xp_required_for_next_level = xp_required_for_next_level
	hud_state.level = level
