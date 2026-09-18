extends Resource
class_name MergeRule

## Pickup-specific struct (docs/20 Contract Field Semantics > Pickup
## Definition Contract fields > "Merge rule"). How this pickup type behaves
## when the pickup cap is hit. docs/20's struct names four sub-fields:
## trigger (fixed: "at pickup cap"), same type only (fixed: true), match
## radius (a REFERENCE to Economy Configuration's Merge radius field, not a
## per-pickup number), and resulting behaviour (fixed: "sum into nearest
## same-type neighbour within radius, else expire oldest of that type").
##
## trigger and resulting_behaviour (P0.6 review iteration 2, Ruling #5 /
## R3): exported as String rather than left in a `.gd` comment, resolving
## toward the treatment HopperConversionRule.trigger already uses for the
## structurally identical case of "docs/20 names exactly one fixed value" -
## a value that exists only in a comment is invisible to every check and
## every content diff. P0.6 convention 3 still bars inventing enum members
## for a value only ever described in prose (no alternative is documented
## anywhere), so both are typed String rather than a one-member enum.
##
## match_radius_px is intentionally NOT an @export (P0.6 review iteration 2,
## R2 - Major): docs/20 types it "reference to Economy Configuration's Merge
## radius field", not an independently authored per-pickup number. The
## prototype's two samples had already drifted to two different values (71
## vs 64) the day they were written, which is exactly the single-source-of-
## truth violation CLAUDE.md's Provisional Values Register rule exists to
## prevent. A per-pickup copy would also put the value out of reach of the
## documented Fallback Ladder escalation that raises Merge radius from 64 to
## 128 px at runtime (docs/20, Performance Budget). get_match_radius_px()
## resolves it from the Economy Configuration instead, following the same
## precedent the reviewer approved for WaveDefinition.get_spawn_budget(): a
## derived value takes its source as a parameter rather than being authored.

@export var trigger: String = "" ## fixed per docs/20: "at pickup cap"
@export var same_type_only: bool = false ## docs/20 states this is always true in practice; schema default kept at Godot's natural false so a sample must explicitly set true rather than inherit it unnoticed
@export var resulting_behaviour: String = "" ## fixed per docs/20: "sum into nearest same-type neighbour within radius, else expire oldest of that type"

## Derived: not authored (P0.6 review iteration 2, R2). Resolves this
## pickup's merge radius from the Economy Configuration's Merge radius
## field, per docs/20 ("match radius: reference to Economy Configuration's
## Merge radius field"), rather than an independently authored per-pickup
## copy that could drift from it.
func get_match_radius_px(economy: EconomyConfiguration) -> int:
	return economy.merge_radius_px
