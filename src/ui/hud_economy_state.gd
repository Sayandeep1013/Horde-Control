extends RefCounted
class_name HudEconomyState

## HudEconomyState (P2.6). The read interface the HUD owns for the four
## fields that have no owning system yet, per this task's own brief
## ("Cross-task seams"): Scrap, XP/level/rerolls, and the Wave counter.
## Economy is Phase 05 (docs/29 Milestones & Roadmap; phases/README.md phase
## table, row 05); the Wave Director is Phase 04 (row 04). Neither exists as
## of this task.
##
## This is a plain typed data holder (RefCounted, not a Node/Resource - it
## is never saved, never shown in an inspector, and carries no behaviour of
## its own), read every frame by src/ui/hud.gd
## (Hud._refresh_scrap()/_refresh_xp()/_refresh_tower_health()'s wave line).
## A future Economy/Wave Director system drives the HUD by mutating an
## instance of this class's fields (or a subclass that overrides nothing but
## adds its own update logic) and letting the HUD's own per-frame poll pick
## the change up - `Hud` is never rewritten when those systems land, only
## this seam starts being driven by something real instead of the neutral
## defaults below. See the P2.6 evidence report, "Cross-task seams," for the
## full reasoning and the EventBus signals this HUD does NOT have to wait
## for as a result.
##
## Not a Provisional Values Register source in the sense of "read from
## here"; every field is CURRENT OBSERVED STATE the real game will report,
## never a tuning constant. Two default values below ARE cited from the
## Register because a sensible zero-state has to start somewhere:
## `scrap_cap` and `wave_total`.

## MASTER_SDLC.md > Provisional Values Register > Economy & Pickups >
## "Scrap": "Cap 200 (HUD 'n/200')."
const SCRAP_CAP_DEFAULT: int = 200

## docs/19_UI_UX.md > "HUD": "'Wave n/8' shows wave progress"; Register >
## Onboarding & Session names 8 combat waves per biome.
const WAVE_TOTAL_DEFAULT: int = 8

## Register > Progression & Upgrades > "Level-Up Draft": "Reroll 1 per run
## (prototype)."
const REROLLS_DEFAULT: int = 1

var scrap_current: int = 0
var scrap_cap: int = SCRAP_CAP_DEFAULT
var hopper_amount: int = 0 # Register > Economy & Pickups > "Scrap": "the prototype has no hopper" -- stays 0 until a real hopper exists; the HUD hides this field whenever it is 0, per docs/19's own "whenever the hopper is non-empty" wording.

var xp_current: float = 0.0
var xp_required_for_next_level: float = 1.0 # no XP curve exists yet (Phase 05); kept > 0 so the HUD never divides by zero
var level: int = 1
var rerolls_remaining: int = REROLLS_DEFAULT

var wave_current: int = 0
var wave_total: int = WAVE_TOTAL_DEFAULT
