extends Node
class_name RunEvents
## v1.0 run events (docs/32 §A; Register "v1.0 Run Events"; decisions D280-D289).
## The scheduled choices of a run: Opening Pick (before wave 1), Patron's Boon
## (gap after waves 4 and 11), Sanctuary (gap after waves 7 and 14, before each
## boss) and Blood Pact (after the Goblin Warchief dies). This node is the LOGIC
## half: it decides WHEN an event is due, rolls the offer on the run seed, and
## applies the choice. `EventDraftController` (src/ui/event_draft_controller.gd)
## is the UI half; it pops events from here and resolves them.
##
## Every random pick goes through KeyedRng on the run seed with a per-purpose key
## and a per-purpose serial, so a seed always offers the same cards.
##
## Effects compose by multiplication with the Draft and the meta layer: Valor,
## Siege Breaker and Eternal Flame each own a NAMED term (set_damage_term,
## set_burn_modifier) and the pact HP costs are a separate multiplier on the
## player and Tower maximum HP, because the Draft and meta setters are absolute
## and would otherwise overwrite them.
##
## Group "run_events". Enabled only for a real run (see `is_enabled_by_default`);
## unit and integration tests that load the prototype scene headless are unchanged.

signal event_queued(kind: String)
signal event_resolved(kind: String, choice: Dictionary)

const KIND_OPENING: String = "opening_pick"
const KIND_PATRON: String = "patrons_boon"
const KIND_SANCTUARY: String = "sanctuary"
const KIND_PACT: String = "blood_pact"

# --- Register "v1.0 Run Events" ----------------------------------------------
const OPENING_CARDS: int = 3 ## Opening Pick: player abilities offered
const ARMORY_OPENING_CARDS: int = 4 ## Armory skill node: offered instead of 3
const OPENING_RARITY: int = ContractEnums.Rarity.Rare ## floor; level 1
const ARMORY_OPENING_RARITY: int = ContractEnums.Rarity.Epic
const PATRON_WAVES: Array[int] = [4, 11] ## Patron's Boon after these waves
const PATRON_CARDS: int = 2
const LUCKY_COIN_PATRON_CARDS: int = 3 ## relic "lucky_coin"
const LUCKY_COIN_RELIC_ID: String = "lucky_coin"
const PATRON_RARITY: int = ContractEnums.Rarity.Epic ## floor ("Epic or better")
const SANCTUARY_WAVES: Array[int] = [7, 14] ## Sanctuary after these waves
const WARCHIEF_WAVE: int = 8 ## the campaign Goblin Warchief wave
const ENDLESS_LOOP_START_WAVE: int = 15 ## Endless events repeat every ENDLESS_LOOP_LENGTH waves past this
const ENDLESS_LOOP_LENGTH: int = 7
const PACTBOUND_CHAMPION_ID: String = "pactbound"
const PACTBOUND_EXTRA_PACT_WAVE: int = 11
const EVENT_MIN_GAP_SECONDS: float = 8.0 ## minimum gap after an event wave
const PACT_CHEST_WAIT_SECONDS: float = 6.0 ## a Blood Pact waits this long for the War Chest draft
const MEND_HEAL_FRACTION: float = 0.50 ## of player max HP
const RESTORE_HEAL_FRACTION: float = 0.30 ## of Tower max HP (and the shield refills)
const VALOR_DAMAGE_BONUS: float = 0.10 ## player and Tower damage for the rest of the run
const PACT_COST_FRACTION: float = 0.20 ## of the paying pool's max HP
const FLAWLESS_COST_FACTOR: float = 0.5 ## no damage taken during the boss wave
const PACTBOUND_COST_FACTOR: float = 0.5 ## champion Pactbound (stacks: a quarter)
const TWIN_STRING_EXTRA_ARROWS: int = 1
const BLOODLUST_HEAL_PER_KILL: float = 1.0
const SIEGE_BREAKER_TOWER_DAMAGE_BONUS: float = 0.40
const ETERNAL_FLAME_BURN_DPS_FACTOR: float = 2.0
const ETERNAL_FLAME_BURN_DURATION_FACTOR: float = 1.5

const SANCTUARY_MEND: String = "mend"
const SANCTUARY_RESTORE: String = "restore"
const SANCTUARY_VALOR: String = "valor"
const SANCTUARY_IDS: Array[String] = [SANCTUARY_MEND, SANCTUARY_RESTORE, SANCTUARY_VALOR]

const PACT_SECOND_LIFE: String = "second_life"
const PACT_TWIN_STRING: String = "twin_string"
const PACT_BLOODLUST: String = "bloodlust"
const PACT_SIEGE_BREAKER: String = "siege_breaker"
const PACT_ETERNAL_FLAME: String = "eternal_flame"
const PACT_IDS: Array[String] = [PACT_SECOND_LIFE, PACT_TWIN_STRING, PACT_BLOODLUST, PACT_SIEGE_BREAKER, PACT_ETERNAL_FLAME]

const OPTION_BLOOD: String = "blood" ## Pay with your blood (player max HP)
const OPTION_TOWER: String = "tower" ## Pay with the Tower (Tower max HP)
const OPTION_REFUSE: String = "refuse"

const TERM_VALOR: String = "valor"
const TERM_SIEGE_BREAKER: String = "siege_breaker"
const TERM_ETERNAL_FLAME: String = "eternal_flame"

@export var run_seed: int = 0
## Set by the integration from the loaded meta loadout (Armory skill node).
var armory_enabled: bool = false
var enabled: bool = true

var _queue: Array[Dictionary] = [] # {kind, wave, not_before, await_chest, flawless}
var _serials: Dictionary = {} # purpose (String) -> int
var taken_pacts: Array[String] = []
var sanctuary_choices: Array[String] = []
var opening_pick_id: String = ""
var pact_events_resolved: int = 0
var _damage_baseline: float = 0.0
var _player_pact_mult: float = 1.0
var _tower_pact_mult: float = 1.0
var _bloodlust_connected: bool = false
var _endless: bool = false
var _pactbound: bool = false
var _lucky_coin: bool = false

# Optional injected references (tests); otherwise resolved by group.
var _upgrade_system: Node = null
var _player: Node = null
var _tower: Node = null
var _ability_manager: Node = null
var _wave_director: Node = null


## True for a real (windowed) run; a headless process stays event-free unless
## `RunConfig.run_events_forced` is set (the balance bot sets it). Keeps the scene-level
## tests that run the prototype headless from stopping at an Opening Pick.
static func is_enabled_by_default() -> bool:
	return RunConfig.run_events_forced or DisplayServer.get_name() != "headless"


# --- Pure schedule (static, so the director and tests share one rule) ----------

## True on the Goblin Warchief waves: wave 8, and 16, 23, 30, ... in Endless.
static func is_warchief_wave(wave_number: int, endless: bool) -> bool:
	if wave_number == WARCHIEF_WAVE:
		return true
	return endless and wave_number > ENDLESS_LOOP_START_WAVE and (wave_number - ENDLESS_LOOP_START_WAVE - 1) % ENDLESS_LOOP_LENGTH == 0


static func _endless_event_wave(wave_number: int, endless: bool) -> bool:
	return endless and wave_number >= ENDLESS_LOOP_START_WAVE + ENDLESS_LOOP_LENGTH and (wave_number - ENDLESS_LOOP_START_WAVE) % ENDLESS_LOOP_LENGTH == 0


## The events due in the gap AFTER `wave_number` (1-based), in the order they open:
## Patron's Boon, then an extra Blood Pact (Pactbound), then Sanctuary last, so the
## blessing is the final choice before a boss. The post-Warchief Blood Pact is not
## listed: it is queued when the Warchief dies.
static func events_after_wave(wave_number: int, endless: bool, pactbound: bool = false) -> Array[String]:
	var out: Array[String] = []
	if PATRON_WAVES.has(wave_number) or _endless_event_wave(wave_number, endless):
		out.append(KIND_PATRON)
	if pactbound and wave_number == PACTBOUND_EXTRA_PACT_WAVE:
		out.append(KIND_PACT)
	# Sanctuary before every boss: waves 7 and 14, and in Endless after wave 15 (the
	# Warchief of wave 16 follows) and after each later loop's last wave.
	if SANCTUARY_WAVES.has(wave_number) or (endless and wave_number >= ENDLESS_LOOP_START_WAVE and (wave_number - ENDLESS_LOOP_START_WAVE) % ENDLESS_LOOP_LENGTH == 0):
		out.append(KIND_SANCTUARY)
	return out


## Minimum gap (seconds) after `wave_number`: EVENT_MIN_GAP_SECONDS after any event
## wave (including the Warchief wave, whose Blood Pact follows), else 0.
static func gap_floor_after_wave(wave_number: int, endless: bool, pactbound: bool = false) -> float:
	if not events_after_wave(wave_number, endless, pactbound).is_empty() or is_warchief_wave(wave_number, endless):
		return EVENT_MIN_GAP_SECONDS
	return 0.0


## Cost of one side of a Blood Pact, as a fraction of that pool's max HP.
static func pact_cost_fraction(flawless: bool, pactbound: bool) -> float:
	var f: float = PACT_COST_FRACTION
	if flawless:
		f *= FLAWLESS_COST_FACTOR
	if pactbound:
		f *= PACTBOUND_COST_FACTOR
	return f


# --- Setup ------------------------------------------------------------------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"run_events")


func _exit_tree() -> void:
	StatusEffects.set_burn_modifier(TERM_ETERNAL_FLAME, 1.0, 1.0)
	if _bloodlust_connected and EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)


## Starts a run: reads the champion and relic rules, hooks the Wave Director and
## EventBus, and queues the Opening Pick. No-op when `enabled` is false.
func begin_run() -> void:
	if not enabled:
		return
	_endless = RunConfig.endless
	_pactbound = RunConfig.champion_id == PACTBOUND_CHAMPION_ID
	_lucky_coin = RunConfig.has_relic(LUCKY_COIN_RELIC_ID)
	StatusEffects.set_burn_modifier(TERM_ETERNAL_FLAME, 1.0, 1.0)
	_connect_sources()
	_queue_event({"kind": KIND_OPENING, "wave": 0})


func _connect_sources() -> void:
	var wd: Node = _director()
	if wd != null:
		if wd.has_signal(&"wave_ended") and not wd.wave_ended.is_connected(_on_wave_ended):
			wd.wave_ended.connect(_on_wave_ended)
		if wd.has_method(&"set_event_gap_provider"):
			wd.set_event_gap_provider(Callable(self, "gap_floor_for_director"))
	if not EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.connect(_on_wave_started)
	if not EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.connect(_on_boss_defeated)
	if not EventBus.war_chest_opened.is_connected(_on_war_chest_opened):
		EventBus.war_chest_opened.connect(_on_war_chest_opened)


func gap_floor_for_director(wave_number: int) -> float:
	return gap_floor_after_wave(wave_number, _endless, _pactbound)


# --- Triggers ------------------------------------------------------------------------

func _on_wave_ended(_wave_id: String, wave_index: int) -> void:
	on_wave_ended(wave_index + 1)


## A wave (1-based `wave_number`) just ended: queue the events due in its gap.
func on_wave_ended(wave_number: int) -> void:
	for kind in events_after_wave(wave_number, _endless, _pactbound):
		var entry: Dictionary = {"kind": kind, "wave": wave_number}
		if kind == KIND_PACT:
			entry["flawless"] = false
		_queue_event(entry)


func _on_wave_started(_wave_number: int, _wave_count: int, _wave_type: String, _is_boss: bool, _timestamp: float) -> void:
	_damage_baseline = CombatStats.get_run_counter("damage_taken")


func _on_boss_defeated(boss_id: String, _position: Vector2, _timestamp: float) -> void:
	on_warchief_defeated(boss_id, SimClock.now, CombatStats.get_run_counter("damage_taken") <= _damage_baseline + 0.0001)


## The Goblin Warchief died: queue a Blood Pact, held until the War Chest draft has
## closed (or PACT_CHEST_WAIT_SECONDS pass). `flawless` = no damage taken in the wave.
func on_warchief_defeated(boss_id: String, now: float, flawless: bool) -> void:
	if boss_id != "warchief":
		return
	_queue_event({"kind": KIND_PACT, "wave": 0, "flawless": flawless, "await_chest": true, "not_before": now + PACT_CHEST_WAIT_SECONDS})


func _on_war_chest_opened(_timestamp: float) -> void:
	for entry in _queue:
		entry["await_chest"] = false


## Dev / capture helper (scene_capture `--event=`): queues `kind` for the next poll.
func queue_dev_event(kind: String, flawless: bool = false) -> void:
	_queue_event({"kind": kind, "wave": 0, "flawless": flawless})


func _queue_event(entry: Dictionary) -> void:
	if not enabled:
		return
	_queue.append(entry)
	event_queued.emit(String(entry["kind"]))


# --- Queue access (the UI polls these) -----------------------------------------------

func has_pending() -> bool:
	return not _queue.is_empty()


func get_pending_kinds() -> Array[String]:
	var out: Array[String] = []
	for e in _queue:
		out.append(String(e["kind"]))
	return out


## The next event that is ready at SimClock time `now`, removed from the queue; {}
## when none. A post-Warchief Blood Pact is not ready until the chest draft is done
## or its wait elapsed.
func pop_next(now: float) -> Dictionary:
	for i in _queue.size():
		var e: Dictionary = _queue[i]
		if bool(e.get("await_chest", false)) and now < float(e.get("not_before", 0.0)):
			continue
		_queue.remove_at(i)
		return e
	return {}


# --- Offers --------------------------------------------------------------------------

## Builds the offer for a popped event: {kind, cards: Array[Dictionary], ...}. An
## empty `cards` means there is nothing to offer (the event is skipped).
##   upgrade card:  {type:"upgrade", id, rarity, multiplier}
##   blessing card: {type:"blessing", id}
##   pact option:   {type:"pact", pact_id, option, fraction, amount}
func build_offer(event: Dictionary) -> Dictionary:
	var kind: String = String(event.get("kind", ""))
	match kind:
		KIND_OPENING:
			return _opening_offer()
		KIND_PATRON:
			return _patron_offer()
		KIND_SANCTUARY:
			return {"kind": kind, "cards": [{"type": "blessing", "id": SANCTUARY_MEND}, {"type": "blessing", "id": SANCTUARY_RESTORE}, {"type": "blessing", "id": SANCTUARY_VALOR}]}
		KIND_PACT:
			return _pact_offer(bool(event.get("flawless", false)))
	return {"kind": kind, "cards": []}


func _next_rng(purpose: String) -> RandomNumberGenerator:
	var serial: int = int(_serials.get(purpose, 0))
	_serials[purpose] = serial + 1
	return KeyedRng.rng_for([run_seed, purpose, serial])


func _rarity_multiplier(rarity: int) -> float:
	return float(DraftController.RARITY_VALUE_MULTIPLIER.get(rarity, 1.0))


## Distinct picks from `pool` on the keyed stream `purpose` (partial Fisher-Yates).
func _pick_distinct(pool: Array, count: int, purpose: String) -> Array:
	var rng: RandomNumberGenerator = _next_rng(purpose)
	var bag: Array = pool.duplicate()
	var out: Array = []
	while out.size() < count and not bag.is_empty():
		out.append(bag.pop_at(rng.randi_range(0, bag.size() - 1)))
	return out


func _opening_offer() -> Dictionary:
	var us: Node = get_upgrade_system()
	var mgr: Node = get_ability_manager()
	var pool: Array = []
	for id in AbilityIds.PLAYER_ABILITIES:
		if us != null and us.has_method("is_ability_available") and not us.is_ability_available(id):
			continue
		if mgr != null and (mgr.get_level(id) > 0 or not mgr.can_grant(id)):
			continue # an Opening Pick grants a NEW ability at level 1
		pool.append(id)
	var count: int = ARMORY_OPENING_CARDS if armory_enabled else OPENING_CARDS
	var rarity: int = ARMORY_OPENING_RARITY if armory_enabled else OPENING_RARITY
	var cards: Array[Dictionary] = []
	for id in _pick_distinct(pool, count, "event_opening"):
		cards.append({"type": "upgrade", "id": id, "rarity": rarity, "multiplier": _rarity_multiplier(rarity)})
	return {"kind": KIND_OPENING, "cards": cards, "armory": armory_enabled}


func _patron_offer() -> Dictionary:
	var us: Node = get_upgrade_system()
	var pool: Array = []
	if us != null:
		for ownership in [ContractEnums.PoolOwnership.Player, ContractEnums.PoolOwnership.Tower]:
			var defs: Array[UpgradeDefinition] = us.get_offerable_upgrades(ownership)
			var useful: Array = []
			for d in defs:
				if not us.is_card_wasted_now(d.unique_id):
					useful.append(d.unique_id)
			pool.append_array(useful if not useful.is_empty() else defs.map(func(d: UpgradeDefinition) -> String: return d.unique_id))
	var count: int = LUCKY_COIN_PATRON_CARDS if _lucky_coin else PATRON_CARDS
	var cards: Array[Dictionary] = []
	for id in _pick_distinct(pool, count, "event_patron"):
		cards.append({"type": "upgrade", "id": id, "rarity": PATRON_RARITY, "multiplier": _rarity_multiplier(PATRON_RARITY)})
	return {"kind": KIND_PATRON, "cards": cards}


func _pact_offer(flawless: bool) -> Dictionary:
	var pool: Array = []
	for id in PACT_IDS:
		if not taken_pacts.has(id):
			pool.append(id)
	if pool.is_empty():
		return {"kind": KIND_PACT, "cards": []}
	var pact_id: String = String(_pick_distinct(pool, 1, "event_pact")[0])
	var fraction: float = pact_cost_fraction(flawless, _pactbound)
	var cards: Array[Dictionary] = [
		{"type": "pact", "pact_id": pact_id, "option": OPTION_BLOOD, "fraction": fraction, "amount": int(round(_player_max_hp() * fraction))},
		{"type": "pact", "pact_id": pact_id, "option": OPTION_TOWER, "fraction": fraction, "amount": int(round(_tower_max_hp() * fraction))},
		{"type": "pact", "pact_id": pact_id, "option": OPTION_REFUSE, "fraction": 0.0, "amount": 0},
	]
	return {"kind": KIND_PACT, "cards": cards, "pact_id": pact_id, "flawless": flawless, "pactbound": _pactbound}


# --- Resolution -----------------------------------------------------------------------

## Applies card `index` of `offer`. Returns the card (or {} if out of range).
func resolve(offer: Dictionary, index: int) -> Dictionary:
	var cards: Array = offer.get("cards", [])
	if index < 0 or index >= cards.size():
		return {}
	var card: Dictionary = cards[index]
	var kind: String = String(offer.get("kind", ""))
	match kind:
		KIND_OPENING, KIND_PATRON:
			var us: Node = get_upgrade_system()
			if us != null:
				us.apply_rank(String(card["id"]), float(card["multiplier"]))
			if kind == KIND_OPENING:
				opening_pick_id = String(card["id"])
		KIND_SANCTUARY:
			apply_blessing(String(card["id"]))
		KIND_PACT:
			pact_events_resolved += 1
			if String(card["option"]) != OPTION_REFUSE:
				apply_pact(String(card["pact_id"]), String(card["option"]), float(card["fraction"]))
	event_resolved.emit(kind, card)
	return card


func apply_blessing(id: String) -> void:
	sanctuary_choices.append(id)
	match id:
		SANCTUARY_MEND:
			var p: Node = get_player()
			if p != null:
				p.heal(p.death_state.max_hp * MEND_HEAL_FRACTION)
		SANCTUARY_RESTORE:
			var t: Node = get_tower()
			var th: Object = t.get("health") if t != null else null
			if th != null:
				th.heal(th.max_health * RESTORE_HEAL_FRACTION)
				th.restore_shield()
		SANCTUARY_VALOR:
			var w: Object = _player_weapon()
			if w != null:
				w.set_damage_term(TERM_VALOR, 1.0 + VALOR_DAMAGE_BONUS)
			var tw: Object = _tower_weapon()
			if tw != null:
				tw.set_damage_term(TERM_VALOR, 1.0 + VALOR_DAMAGE_BONUS)


## Takes pact `pact_id`, paying `fraction` of the max HP of the pool named by
## `option` (OPTION_BLOOD: the player, OPTION_TOWER: the Tower), then applies its effect.
func apply_pact(pact_id: String, option: String, fraction: float) -> void:
	if taken_pacts.has(pact_id):
		return
	taken_pacts.append(pact_id)
	if option == OPTION_BLOOD:
		_player_pact_mult *= (1.0 - fraction)
		var p: Node = get_player()
		if p != null:
			p.set_pact_max_health_multiplier(_player_pact_mult)
	elif option == OPTION_TOWER:
		_tower_pact_mult *= (1.0 - fraction)
		var t: Node = get_tower()
		var th: Object = t.get("health") if t != null else null
		if th != null:
			th.set_pact_max_health_multiplier(_tower_pact_mult)
	match pact_id:
		PACT_SECOND_LIFE:
			var p2: Node = get_player()
			if p2 != null:
				p2.set_second_life_available(true)
		PACT_TWIN_STRING:
			var w: Object = _player_weapon()
			if w != null:
				w.set_full_extra_arrows(TWIN_STRING_EXTRA_ARROWS)
		PACT_BLOODLUST:
			if not _bloodlust_connected:
				_bloodlust_connected = true
				EventBus.enemy_died.connect(_on_enemy_died)
		PACT_SIEGE_BREAKER:
			var tw: Object = _tower_weapon()
			if tw != null:
				tw.set_damage_term(TERM_SIEGE_BREAKER, 1.0 + SIEGE_BREAKER_TOWER_DAMAGE_BONUS)
		PACT_ETERNAL_FLAME:
			StatusEffects.set_burn_modifier(TERM_ETERNAL_FLAME, ETERNAL_FLAME_BURN_DPS_FACTOR, ETERNAL_FLAME_BURN_DURATION_FACTOR)


func _on_enemy_died(_entity: Node2D, _position: Vector2, _timestamp: float) -> void:
	var p: Node = get_player()
	if p != null:
		p.heal(BLOODLUST_HEAL_PER_KILL)


## Pacts and Sanctuary choices taken, for the pause build panel: [{type:"pact"|"sanctuary", id}].
func get_summary() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in taken_pacts:
		out.append({"type": "pact", "id": id})
	for id in sanctuary_choices:
		out.append({"type": "sanctuary", "id": id})
	return out


# --- Scene references (group lookups; tests inject) ---------------------------------------

func get_upgrade_system() -> Node:
	if _upgrade_system == null or not is_instance_valid(_upgrade_system):
		_upgrade_system = get_tree().get_first_node_in_group(&"upgrade_system") if is_inside_tree() else null
	return _upgrade_system


func get_player() -> Node:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	return _player


func get_tower() -> Node:
	if _tower == null or not is_instance_valid(_tower):
		_tower = get_tree().get_first_node_in_group(&"tower") if is_inside_tree() else null
	return _tower


func get_ability_manager() -> Node:
	if _ability_manager == null or not is_instance_valid(_ability_manager):
		_ability_manager = get_tree().get_first_node_in_group(&"ability_manager") if is_inside_tree() else null
	return _ability_manager


func _director() -> Node:
	if _wave_director == null or not is_instance_valid(_wave_director):
		_wave_director = get_tree().get_first_node_in_group(&"wave_director") if is_inside_tree() else null
	return _wave_director


func _player_weapon() -> Object:
	var p: Node = get_player()
	return p.get_node_or_null("AutoWeapon") if p != null else null


func _tower_weapon() -> Object:
	var t: Node = get_tower()
	return t.get("weapon") if t != null else null


func _player_max_hp() -> float:
	var p: Node = get_player()
	return p.death_state.max_hp if p != null and p.death_state != null else 0.0


func _tower_max_hp() -> float:
	var t: Node = get_tower()
	var th: Object = t.get("health") if t != null else null
	return th.max_health if th != null else 0.0


func set_upgrade_system_for_test(n: Node) -> void:
	_upgrade_system = n


func set_player_for_test(n: Node) -> void:
	_player = n


func set_tower_for_test(n: Node) -> void:
	_tower = n


func set_ability_manager_for_test(n: Node) -> void:
	_ability_manager = n


func set_wave_director_for_test(n: Node) -> void:
	_wave_director = n


func set_rules_for_test(endless: bool, pactbound: bool, lucky_coin: bool) -> void:
	_endless = endless
	_pactbound = pactbound
	_lucky_coin = lucky_coin
