extends Resource
class_name WeaponEvolutionRequirement

## Weapon-specific struct (docs/20 Contract Field Semantics > Weapon and
## Evolution Definition Contract fields > "Evolution prerequisites and the
## evolution target"). What must be owned to evolve, and what the weapon
## becomes.

@export var prerequisites: Array[String] = [] ## Upgrade Unique IDs
@export var evolution_target_id: String = "" ## Weapon Unique ID
