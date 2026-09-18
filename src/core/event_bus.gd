extends Node

## EventBus Autoload (docs/20_Technical_Architecture.md > Godot 4.x
## Implementation Standards > "Communication, events"; MASTER_SDLC.md >
## Global Simulation Authority, process-mode paragraph: "`PauseAuthority`,
## `EventBus`, the UI `CanvasLayer` ... are `PROCESS_MODE_ALWAYS`, so they
## keep functioning while paused"). PROCESS_MODE_ALWAYS so a paused UI
## (Level-Up Draft, pause menu) can still receive and react to whatever was
## emitted at the instant the pause took effect.
##
## THE rule that matters (docs/20 > "Communication, events"): a system emits
## a signal to ANNOUNCE a state change it has already made to its OWN data.
## It never calls a mutating function on another system through this bus,
## and this bus never calls a mutating function on anyone either -- it only
## re-broadcasts what an emit_*() wrapper is told to broadcast. That is why
## every signal here is paired with a typed emit_*() method instead of
## leaving callers to call Signal.emit() directly: the wrapper is the one
## place the "announce a change already made, never request one" rule and
## the timestamp rule below are enforced in code, not left to every call
## site remembering both.
##
## Every timestamp on every signal is SimClock.now (simulation time), never
## Time.get_ticks_msec()/get_unix_time() (wall clock) -- P1.2 task brief:
## "Timestamps come from SimClock.now, not wall clock." This makes a
## recorded event replay at the correct simulation instant regardless of
## real-world frame timing or SimClock.time_scale (Determinism where it
## matters; docs/20 > SimLoop order).
##
## docs/20's "Communication, events" bullet names three signals as EXAMPLES
## ("State changes are announced ... for example `enemy_died`,
## `tower_damaged`, `draft_opened`"), not an exhaustive list -- confirmed by
## reading the full bullet and the rest of docs/20; no fourth signal name
## appears anywhere in that document. Those three are implemented below.
## Later phases ADD signals here as the systems that own that state are
## built (P1.5 death/hit systems, P2.x Wave Director/draft/Console systems
## each add their own state-change signal when built), rather than this
## task inventing signal shapes for systems that do not exist yet. See the
## P1.2 evidence report, "Contradictions and ambiguities," item 1.

## Emitted once, at Logical Death (docs/20 > Logical Death: "the instant an
## entity's HP reaches 0, a `dead` flag is set on it"), by whichever system
## sets that flag (P1.5, not yet built). `position` is the entity's position
## at the moment of death, useful to a listener (drops, VFX, the Run
## Recorder) without it having to still hold a live reference to the entity.
signal enemy_died(entity: Node2D, position: Vector2, timestamp: float)

## Emitted once per instance of Tower damage (health or shield), by whichever
## system resolves the hit (docs/20 > SimLoop order, step 8 "death
## resolution" is where damage becomes final for the tick). `new_health` and
## `new_shield` are the Tower's pools AFTER this damage is applied
## (MASTER_SDLC.md > Health Recovery Rules: "the shield absorbs damage
## before health"), so a listener (screen edge indicator, audio cue,
## directional damage flash -- "Damage to the Tower must be loud") never has
## to reconstruct current state by summing deltas itself.
signal tower_damaged(amount: float, new_health: float, new_shield: float, timestamp: float)

## Emitted once when a Level-Up Draft opens (docs/19_UI_UX.md > Upgrade
## Draft UI & Navigation: "When the player levels up, the simulation pauses
## fully and the Level-Up Draft appears."; MASTER_SDLC.md > SimLoop order,
## step 11: "A level-up requested at step 11 counts as an open Level-Up
## Draft for step 13 of the same tick"). Emitted by the system that
## requested the level-up, after it has itself pushed the `draft` pause
## reason on PauseAuthority -- EventBus never pushes a pause reason on
## anyone's behalf; announcing and causing are different things.
signal draft_opened(timestamp: float)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Typed emit wrapper. Stamps the announcement with SimClock.now so no call
## site can pass wall-clock time or forget the timestamp entirely.
func emit_enemy_died(entity: Node2D, position: Vector2) -> void:
	enemy_died.emit(entity, position, SimClock.now)


## Typed emit wrapper. `amount` is the damage just applied (positive);
## `new_health`/`new_shield` are the Tower's resulting pools.
func emit_tower_damaged(amount: float, new_health: float, new_shield: float) -> void:
	tower_damaged.emit(amount, new_health, new_shield, SimClock.now)


## Typed emit wrapper.
func emit_draft_opened() -> void:
	draft_opened.emit(SimClock.now)
