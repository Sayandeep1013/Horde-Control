extends Resource
class_name ReadabilityProfile

## Shared struct (docs/20 Contract Field Semantics > Shared fields and struct
## types > "Readability profile"). Governs how an entity stays identifiable
## under the readability hierarchy.

@export var silhouette_class: ContractEnums.SilhouetteClass = ContractEnums.SilhouetteClass.Small
@export var reserved_colour: Color = Color.WHITE
@export var minimum_on_screen_size_px: int = 0
