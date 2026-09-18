extends Resource
class_name HopperConversionRule

## Economy-specific struct (docs/20 Contract Field Semantics > Economy
## Configuration Contract fields > "Hopper-to-Core conversion rate and
## trigger", meaning column: "rate: integer:1, trigger: enters Tower
## Interaction Radius"). docs/20 gives only one fixed trigger with no
## enumerated alternative anywhere, so trigger is typed as a documentation
## string rather than an invented one-member enum (P0.6 convention 3 bars
## adding convenience enum members).

@export var rate_scrap_per_core: int = 0
@export var trigger: String = ""
