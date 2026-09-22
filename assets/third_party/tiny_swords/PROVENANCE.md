# Third-party assets - Tiny Swords (Pixel Frog)

Source: **Tiny Swords** by Pixel Frog, <https://pixelfrog-assets.itch.io/tiny-swords>, downloaded 2026-09-23
from the file the store page labels **"TS_old version_CC0 Licensed"** (archive `Tiny Swords.zip`,
root folder `Tiny Swords (Update 010)`). That edition is released under **Creative Commons Zero 1.0
(CC0)**: personal and commercial use, modification and redistribution, credit optional. Credit is given
anyway, here and in-game.

The newer "Tiny Swords (Free Pack)" on the same page is **not** CC0 (its licence forbids redistribution),
and nothing from it is in this repository. The "Enemy Pack" is paid and was not used.

Every file is byte-identical to the archive. The only change is the path: the space in `Gold Mine` is
replaced by an underscore. `sha256` is the first 16 hex characters.

Sheet layouts (frame size, then rows top to bottom), so no reader has to re-derive them:

| Sheet | Frame | Rows |
| --- | --- | --- |
| Torch_Red | 192x192, 7 cols | 0 idle (7), 1 run (6), 2 attack right (6), 3 attack down (6), 4 attack up (6) |
| TNT_Yellow | 192x192, 7 cols | 0 idle (6), 1 run (6), 2 throw (7) |
| Barrel_Purple | 128x128, 6 cols | 0 closed (1), 1 pop out (6), 2 peek (1), 3 hide (6), 4 run (3), 5 explode (3) |
| Archer_Blue | 192x192, 8 cols | 0 idle (6), 1 run (6), 2 shoot up, 3 shoot up-diagonal, 4 shoot right, 5 shoot down-diagonal, 6 shoot down (8 each) |
| Dead | 128x128, 7 cols | 0 skull falls (7), 1 skull dissolves (7) |
| Explosions | 192x192, 9 cols | 0 explosion (9) |
| Fire | 128x128, 7 cols | 0 flame loop (7) |
| Dynamite | 64x64, 6 cols | 0 spin (6) |
| Tree | 192x192, 4 cols | 0 sway (4), 1 hit (2), 2 stump (1) |
| HappySheep_All | 128x128, 8 cols | 0 idle (8), 1 bounce (6) |
| Foam | 192x192, 8 cols | 0 foam loop (8) |
| Rocks_0N (water) | 128x128, 8 cols | 0 bob loop (8) |
| G/M/W_Spawn | 128x128, 7 cols | 0 spawn (7) |
| Tilemap_Flat | 64x64 tiles | cols 0-3 grass 9-slice and strips, cols 5-8 sand 9-slice and strips |
| Tilemap_Elevation | 64x64 tiles | cliff/elevation 9-slice, stairs |

| Path under `assets/third_party/tiny_swords/` | Original path under `Tiny Swords (Update 010)/` | Transform | sha256 (16) |
| --- | --- | --- | --- |
| `Deco/01.png` | `Deco/01.png` | verbatim | `aae1d14745a5886b` |
| `Deco/02.png` | `Deco/02.png` | verbatim | `7adc58201b1db819` |
| `Deco/03.png` | `Deco/03.png` | verbatim | `5afe95e862aaa047` |
| `Deco/04.png` | `Deco/04.png` | verbatim | `e4a6132577721eb8` |
| `Deco/05.png` | `Deco/05.png` | verbatim | `f51cf8d4647febc1` |
| `Deco/06.png` | `Deco/06.png` | verbatim | `edc4335ad52060a5` |
| `Deco/07.png` | `Deco/07.png` | verbatim | `fae1719e2b2de9bd` |
| `Deco/08.png` | `Deco/08.png` | verbatim | `f94b5fa5aac1b62b` |
| `Deco/09.png` | `Deco/09.png` | verbatim | `fa07501a73b22ae6` |
| `Deco/10.png` | `Deco/10.png` | verbatim | `68f57683bc1f512d` |
| `Deco/11.png` | `Deco/11.png` | verbatim | `26a7592cbc3ac76b` |
| `Deco/12.png` | `Deco/12.png` | verbatim | `54d6fce705950699` |
| `Deco/13.png` | `Deco/13.png` | verbatim | `9a7ef9a9695aba24` |
| `Deco/14.png` | `Deco/14.png` | verbatim | `4515949922edc553` |
| `Deco/15.png` | `Deco/15.png` | verbatim | `d09c7ef588b00cdb` |
| `Deco/16.png` | `Deco/16.png` | verbatim | `bbf9170c41a2bd10` |
| `Deco/17.png` | `Deco/17.png` | verbatim | `c3da63203ae56798` |
| `Deco/18.png` | `Deco/18.png` | verbatim | `8ef2e9479438091d` |
| `Effects/Explosion/Explosions.png` | `Effects/Explosion/Explosions.png` | verbatim | `fa3bcfbf05c3c1ce` |
| `Effects/Fire/Fire.png` | `Effects/Fire/Fire.png` | verbatim | `0ed74320a434cbe7` |
| `Factions/Goblins/Buildings/Wood_House/Goblin_House.png` | `Factions/Goblins/Buildings/Wood_House/Goblin_House.png` | verbatim | `5e25c872df37f63e` |
| `Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Red.png` | `Factions/Goblins/Buildings/Wood_Tower/Wood_Tower_Red.png` | verbatim | `4e422cfd3a0975ef` |
| `Factions/Goblins/Troops/Barrel/Purple/Barrel_Purple.png` | `Factions/Goblins/Troops/Barrel/Purple/Barrel_Purple.png` | verbatim | `d3a2bb8ae239951f` |
| `Factions/Goblins/Troops/TNT/Dynamite/Dynamite.png` | `Factions/Goblins/Troops/TNT/Dynamite/Dynamite.png` | verbatim | `5cfc3d6fa12655cd` |
| `Factions/Goblins/Troops/TNT/Yellow/TNT_Yellow.png` | `Factions/Goblins/Troops/TNT/Yellow/TNT_Yellow.png` | verbatim | `59741345199a16d2` |
| `Factions/Goblins/Troops/Torch/Red/Torch_Red.png` | `Factions/Goblins/Troops/Torch/Red/Torch_Red.png` | verbatim | `0612b50e25f5b5fe` |
| `Factions/Knights/Buildings/Castle/Castle_Blue.png` | `Factions/Knights/Buildings/Castle/Castle_Blue.png` | verbatim | `616cfeec6287ede0` |
| `Factions/Knights/Buildings/Castle/Castle_Construction.png` | `Factions/Knights/Buildings/Castle/Castle_Construction.png` | verbatim | `3850894fa86cfd08` |
| `Factions/Knights/Buildings/Castle/Castle_Destroyed.png` | `Factions/Knights/Buildings/Castle/Castle_Destroyed.png` | verbatim | `bdfb6452c3e16bd2` |
| `Factions/Knights/Buildings/House/House_Blue.png` | `Factions/Knights/Buildings/House/House_Blue.png` | verbatim | `9020e35116ffde6d` |
| `Factions/Knights/Buildings/Tower/Tower_Blue.png` | `Factions/Knights/Buildings/Tower/Tower_Blue.png` | verbatim | `2d39450c366fc1eb` |
| `Factions/Knights/Buildings/Tower/Tower_Construction.png` | `Factions/Knights/Buildings/Tower/Tower_Construction.png` | verbatim | `e4975c74fcf9874b` |
| `Factions/Knights/Buildings/Tower/Tower_Destroyed.png` | `Factions/Knights/Buildings/Tower/Tower_Destroyed.png` | verbatim | `e92d9ac401698e22` |
| `Factions/Knights/Troops/Archer/Arrow/Arrow.png` | `Factions/Knights/Troops/Archer/Arrow/Arrow.png` | verbatim | `ba35a379a56693fe` |
| `Factions/Knights/Troops/Archer/Blue/Archer_Blue.png` | `Factions/Knights/Troops/Archer/Blue/Archer_Blue.png` | verbatim | `0a2e1efff6d653d3` |
| `Factions/Knights/Troops/Dead/Dead.png` | `Factions/Knights/Troops/Dead/Dead.png` | verbatim | `2b621f86ef18fd92` |
| `Resources/Gold_Mine/GoldMine_Active.png` | `Resources/Gold Mine/GoldMine_Active.png` | verbatim | `c5205d8181d488ad` |
| `Resources/Resources/G_Idle.png` | `Resources/Resources/G_Idle.png` | verbatim | `ee9a2018e179b958` |
| `Resources/Resources/G_Spawn.png` | `Resources/Resources/G_Spawn.png` | verbatim | `c631caee64097731` |
| `Resources/Resources/M_Idle.png` | `Resources/Resources/M_Idle.png` | verbatim | `5c7b717272597e38` |
| `Resources/Resources/M_Spawn.png` | `Resources/Resources/M_Spawn.png` | verbatim | `1d86e71839a4c688` |
| `Resources/Resources/W_Idle.png` | `Resources/Resources/W_Idle.png` | verbatim | `23738d5fe80f20eb` |
| `Resources/Resources/W_Spawn.png` | `Resources/Resources/W_Spawn.png` | verbatim | `36b0b90b92784e6e` |
| `Resources/Sheep/HappySheep_All.png` | `Resources/Sheep/HappySheep_All.png` | verbatim | `1bc76e575da5b307` |
| `Resources/Sheep/HappySheep_Bouncing.png` | `Resources/Sheep/HappySheep_Bouncing.png` | verbatim | `45af7995c505f9e2` |
| `Resources/Sheep/HappySheep_Idle.png` | `Resources/Sheep/HappySheep_Idle.png` | verbatim | `ed5ead99086725ad` |
| `Resources/Trees/Tree.png` | `Resources/Trees/Tree.png` | verbatim | `63a1ae0399162152` |
| `Terrain/Bridge/Bridge_All.png` | `Terrain/Bridge/Bridge_All.png` | verbatim | `816de342b39f03ee` |
| `Terrain/Ground/Shadows.png` | `Terrain/Ground/Shadows.png` | verbatim | `e6b60e7445c67f3d` |
| `Terrain/Ground/Tilemap_Elevation.png` | `Terrain/Ground/Tilemap_Elevation.png` | verbatim | `dab562d922d81e4d` |
| `Terrain/Ground/Tilemap_Flat.png` | `Terrain/Ground/Tilemap_Flat.png` | verbatim | `683b4ebc6dff10d2` |
| `Terrain/Water/Foam/Foam.png` | `Terrain/Water/Foam/Foam.png` | verbatim | `eaeaab4c2211ce5b` |
| `Terrain/Water/Rocks/Rocks_01.png` | `Terrain/Water/Rocks/Rocks_01.png` | verbatim | `56a85a84754200c9` |
| `Terrain/Water/Rocks/Rocks_02.png` | `Terrain/Water/Rocks/Rocks_02.png` | verbatim | `02b5dea7d26c1b9a` |
| `Terrain/Water/Rocks/Rocks_03.png` | `Terrain/Water/Rocks/Rocks_03.png` | verbatim | `cb407bf96983b553` |
| `Terrain/Water/Rocks/Rocks_04.png` | `Terrain/Water/Rocks/Rocks_04.png` | verbatim | `7c3d7f8db1d18fe5` |
| `Terrain/Water/Water.png` | `Terrain/Water/Water.png` | verbatim | `5ef30a00bbff2259` |

## Derived files (art pass, D102)

Every file below is a Python/PIL transform of one or more of the verbatim files above -- built by
`sandbox/inspect/` scratch scripts during this session, not hand-drawn, and reproducible from the
verbatim sources at any time. "Original path" below names the source file(s) transformed rather than
an upstream path (there is no single upstream original for a composite).

| Path under `assets/third_party/tiny_swords/` | Source file(s) | Transform | sha256 (16) |
| --- | --- | --- | --- |
| `Derived/tower_stage0_base.png` | `Factions/Knights/Buildings/Tower/Tower_Blue.png` | letterboxed onto a transparent 320x256 canvas, horizontally centred, bottom-aligned (matches Castle_Blue.png's own native 320x256 canvas so every Tower evolution stage shares one size/anchor) | `308c250617e5028d` |
| `Derived/tower_destroyed_padded.png` | `Factions/Knights/Buildings/Tower/Tower_Destroyed.png` | same 320x256 letterbox as `tower_stage0_base.png` | `e62d9676f20905eb` |
| `Derived/tower_stage1_archer.png` | `Factions/Knights/Buildings/Tower/Tower_Blue.png` + `Factions/Knights/Troops/Archer/Blue/Archer_Blue.png` (frame [0,0], the idle pose, alpha-trimmed) | Tower_Blue letterboxed as above, one archer frame composited standing on the tower's top platform | `00af7348b9848f04` |
| `Derived/tower_stage3_archers.png` | `Factions/Knights/Buildings/Castle/Castle_Blue.png` + `Factions/Knights/Troops/Archer/Blue/Archer_Blue.png` (frame [0,0], alpha-trimmed, one instance mirrored) | two archer frames composited standing on the castle's battlements, left and right of centre | `b20003da4cd3ad91` |
| `Derived/grass_fill_tile.png` | `Terrain/Ground/Tilemap_Flat.png` | 64x64 crop of the grass 9-slice's centre/fill tile (atlas col 1, row 1) | `c080267c6f90f981` |
| `Derived/sand_fill_tile.png` | `Terrain/Ground/Tilemap_Flat.png` | 64x64 crop of the sand 9-slice's centre/fill tile (atlas col 6, row 1) | `db6f26fe7472b067` |
