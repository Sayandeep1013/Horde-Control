extends Resource
class_name ContractEnums

## Every enum used by a Content Data Contract (MASTER_SDLC.md > Content Data
## Contracts), typed exactly once here per docs/20_Technical_Architecture.md
## > Contract Field Semantics, and referenced everywhere else as
## ContractEnums.<Name> (P0.6 convention 3). Member lists match Contract
## Field Semantics exactly - same members, same order, no extra NONE/UNSET
## member added for convenience, per P0.6 convention 3. This project chose to
## centralise every enum here, including contract-specific ones the task
## allowed to live on their own contract resource, for one discoverable
## source of truth; see phases/PHASE_01_Contracts_Docs_Harness/evidence/
## p06_report.md "Conventions" section.

## Shared fields and struct types table -----------------------------------

## Target intent (shared table): Enemy.target_intent, IntentBudgetOverride,
## EnemyIntentMixEntry, PressureIntentWeightEntry, TargetingRuleParameters.
enum TargetIntent {
	TowerSeeker,
	PlayerHunter,
	Opportunist,
	ZoneDenier,
	Disruptor,
	Splitter,
}

## Band label (shared table): categorical tier for a Health or Damage value;
## null in the prototype. Used inside BandedValue (P0.6 convention 5), never
## directly on a contract field.
enum BandLabel { Low, Mid, High }

## Difficulty band (shared table): categorical tier for a wave or biome, NOT
## the same field as Band label (P0.6 convention 5) - this one is always
## non-null. Used by Wave.difficulty_band.
enum DifficultyBand { Low, Mid, High }

## Contact behaviour (shared table): Enemy.contact_behaviour.
enum ContactBehaviour { None, Damage, Explode, Block }

## Entity cap behaviour (shared table): Encounter.entity_cap_behavior.
enum EntityCapBehaviour { Throttle, Defer, Skip }

## Pause and deferral behaviour (shared table): Encounter.pause_and_deferral_behavior.
enum PauseAndDeferralBehaviour { DeferUntilDraftCloses, Cancel }

## Pool ownership (shared table): Upgrade.pool_ownership (and inherited by
## TowerUpgradeDefinition).
enum PoolOwnership { Player, Tower, Weapon, Utility }

## Visual readability impact (shared table): Upgrade.visual_readability_impact.
enum VisualReadabilityImpact { None, Low, High }

## Performance cost category (shared table): Upgrade.performance_cost_category.
enum PerformanceCostCategory { Light, Medium, Heavy }

## Silhouette class, part of the Readability profile struct (shared table).
enum SilhouetteClass { Small, Medium, Large, Boss }

## Telegraph shape, part of the Telegraph data struct (shared table).
enum TelegraphShape { Wedge, Line, Circle, Ring }

## Attack type, part of the Attack profile struct (shared table).
enum AttackType { Melee, Ranged, Contact }

## Effect struct's "kind" field (shared table). Effect itself is typed for
## forward compatibility with the out-of-scope Status Effect contract
## (P0.6 convention 2); no in-scope P0.6 contract's sample uses it.
enum EffectKind { Damage, Heal, StatModifier }

## Effect struct's "target" field (shared table). Named distinctly from
## UpgradeEffectTarget below - same-sounding field, different member list,
## different struct.
enum EffectStructTarget { Player, Tower, Enemy }

## Encounter type (Encounter Definition Contract fields; also reused by
## Director Configuration's per-encounter-type tables, which is why it lives
## here rather than only on EncounterDefinition).
enum EncounterType {
	StandardAssault,
	SplitAssault,
	Siege,
	Hunt,
	Elite,
	Duel,
	MiniBoss,
	BiomeBoss,
	Escort,
	Blackout,
	Breach,
	Ambush,
	Pincer,
	EnvironmentalEvent,
	ResourceRush,
	SwarmCrush,
}

## Lane separation rule, part of Director Configuration's per-encounter-type
## directional weighting entry.
enum LaneSeparationRule { Fixed180, MobilityScaled }

## Ring, part of the same directional weighting entry.
enum RingType { Tower, View }

## Pathing fallback behavior (Enemy Definition Contract fields).
enum PathingFallbackBehavior { Standard, Custom }

## Failure resolution (Encounter Definition Contract fields).
enum FailureResolution { RewardForfeited, CompletesWithPartialReward }

## Rarity (Upgrade Definition Contract fields).
enum Rarity { Common, Rare, Epic }

## Upgrade's "Effect target" (Upgrade Definition Contract fields). Named
## distinctly from EffectStructTarget above - same-sounding field, different
## member list, different struct.
enum UpgradeEffectTarget { Player, Tower, PlayerWeapon, TowerWeapon }

## Boss overlap rules (Wave Definition Contract fields).
enum BossOverlapRules { NotApplicable, SuppressesRegularSpawns }

## Coverage shape (Weapon and Evolution Definition Contract fields).
enum CoverageShape { Cone, Line, Radius, SingleTarget }

## Engagement rhythm (Weapon and Evolution Definition Contract fields).
enum EngagementRhythmKind { Sustained, Burst }

## Which stat category a weapon evolution changes (Weapon and Evolution
## Definition Contract fields).
enum EvolutionChangeAxis { Range, Coverage, TargetCount, Rhythm }

## Magnet behaviour (Pickup Definition Contract fields).
enum MagnetBehaviour { Attracted, Static }

## Pickup type (Pickup Definition Contract fields). Health is listed because
## Contract Field Semantics states it as a member ("vertical slice only") -
## the member list is typed exactly regardless of when it becomes reachable.
enum PickupType { XP, Scrap, Core, Health }

## Hurtbox definition (Player Definition Contract fields). A single-member
## enum - Contract Field Semantics defines only {SameAsBody} today.
enum HurtboxDefinition { SameAsBody }
