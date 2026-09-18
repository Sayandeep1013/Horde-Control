extends Resource
class_name XpLevelCost

## Economy-specific struct (docs/20 Contract Field Semantics > Economy
## Configuration Contract fields > "XP shard value and level cost formula",
## meaning column: "shard value: integer, cost formula: L -> 10 + 5(L+1)").
##
## Ambiguity flagged in the P0.6 report: docs/20 states the cost formula as
## a literal expression with two embedded magic numbers (10 and 5), not as
## named sub-fields. Given MASTER's opening line ("All major content types
## must be data-driven") and this document's own rule that content data is
## never hardcoded, this schema resolves the ambiguity by exporting the
## formula's two coefficients as authored data (base_cost, per_level_increment)
## rather than baking 10 and 5 into code, so L -> base_cost +
## per_level_increment * (L + 1). This is an interpretation, not something
## docs/20 states explicitly - a reviewer may prefer treating the formula as
## fixed application logic instead.

@export var shard_value: int = 0
@export var base_cost: int = 0
@export var per_level_increment: int = 0

## L -> base_cost + per_level_increment * (L + 1), per docs/20's formula shape.
func compute_level_cost(level: int) -> int:
	return base_cost + per_level_increment * (level + 1)
