extends Resource
class_name ConsolePriceFormula

## Economy-specific struct (docs/20 Contract Field Semantics > Economy
## Configuration Contract fields > "Upgrade Console price formula", meaning
## column: "Scrap per rank: integer, formula: price = Scrap-per-rank x rank
## being bought"). Unlike XpLevelCost, the formula here introduces no magic
## number beyond the one named field, so no extra coefficient is invented -
## price is a pure function of scrap_per_rank and the rank parameter.

@export var scrap_per_rank: int = 0

func compute_price(rank_being_bought: int) -> int:
	return scrap_per_rank * rank_being_bought
