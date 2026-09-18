extends Resource
class_name PersistentAssetRule

## One {asset class, persists across biomes} pair (docs/20 Contract Field
## Semantics > Tower Definition Contract fields > "Persistent asset rules").
## Which Tower-attached assets (for example drones) survive a biome
## transition. Typed per P0.6 convention 6.

@export var asset_class: String = ""
@export var persists_across_biomes: bool = false
