extends RefCounted
class_name UiPalette

## UiPalette (UI pass). The single home of every COSMETIC token the UI uses:
## colour, spacing, corner radius, font size, and motion duration. Every file
## under src/ui/ reads these instead of carrying its own `Color(...)` or pixel
## literal, so the whole look can be retuned from this one file.
##
## None of these are gameplay numbers (CLAUDE.md > "Rules for any agent"; the
## Provisional Values Register owns those). A value the Register DOES own -
## the HUD's 40% tick, the Draft's 60% dim and 0.4 s lockout, the Console's
## 85% opacity / 24 px text floor / 0.5 s channel - stays cited where it
## already lives and is never restated here. The one overlap is DIM_DRAFT,
## which is the colour the Register's 60% figure is applied to, not the
## figure itself; the owning script keeps the citation.
##
## Direction (phases/UI_PASS/PLAN.md): minimal chrome, a clear screen centre,
## a muted dark ground so saturated threats win on value before hue, one
## outlined display font everywhere, small pill-shaped edge widgets.
##
## ## Tiny Swords medieval restyle (author decision, second UI pass)
## The surface/line tokens below were retinted from a blue-grey "sci-fi HUD"
## scheme to a warm wood/leather one, to sit under the Tiny Swords carved-
## wood and parchment 9-slice textures (`TEX_*` below,
## assets/third_party/tiny_swords/UI/, PROVENANCE.md) without a visible
## seam where a texture panel meets a flat one (e.g. Console's own
## per-instance StyleBoxFlat, built through `UiTheme.make_box()` with these
## same tokens -- see console.gd's header, "restyle it only through the
## theme"). No test asserts an exact colour value here (grepped) -- only
## relative brightness/contrast, which this retint preserves: every token
## keeps its old position in the dark-to-light ordering, only the hue moves
## from blue-grey toward brown/bronze.

# --- Surfaces -------------------------------------------------------------
const INK: Color = Color("18110c")            ## deepest panel fill (was a blue-black; now a dark umber)
const SURFACE: Color = Color("2a1d14")        ## raised panel / card fill (dark walnut)
const SURFACE_HOVER: Color = Color("3c2a19")  ## hovered / highlighted row fill (warm brown)
const LINE: Color = Color("6b5335")           ## resting border (bronze/wood)
const LINE_STRONG: Color = Color("a3763f")    ## emphasised resting border (bright bronze)
const PANEL_ALPHA: float = 0.88               ## floating panels (tooltips, the reroll pill's own surface before tint)
const CARD_ALPHA: float = 0.96                ## modal cards over a dim

## HUD polish (coordinator review, third pass): the HUD's own pills (Player/
## Tower/Scrap fields, and the Draft's Reroll pill) sit directly over live
## gameplay -- bright grass, light sand -- with nothing dimming the
## background behind them, unlike a modal CARD. The light parchment texture
## at PANEL_ALPHA read as "pale and see-through, washing out over grass/
## sand" (coordinator's own words, from a real capture). `PILL_TINT`
## multiplies over the SAME Carved_9Slides texture PANEL/CARD use (no new
## asset) to darken it into a solid wood-brown, at near-full opacity, so it
## reads as a solid frame regardless of what is moving underneath it.
const PILL_TINT: Color = Color(0.55, 0.47, 0.37, 0.98)

# --- Tiny Swords UI textures (assets/third_party/tiny_swords/UI/;
# PROVENANCE.md; every file below is used verbatim, CC0) -------------------
const TS_UI_ROOT: String = "res://assets/third_party/tiny_swords/UI/"
## Carved wood/parchment panel (192x192): used for every static PILL/PANEL/
## CARD/TOOLTIP surface (HUD pills, the Level-Up Draft card frame accent,
## pause/settings/run-end/console modal cards, tooltips).
const TEX_PANEL_CARVED: String = TS_UI_ROOT + "Banners/Carved_9Slides.png"
## Small flat swatch (64x64) of the same carved-wood fill, tiled behind
## draft-card text for a parchment texture at a size too small for the full
## 9-slice frame to read cleanly.
const TEX_PANEL_CARVED_SWATCH: String = TS_UI_ROOT + "Banners/Carved_Regular.png"
const TEX_BUTTON_NORMAL: String = TS_UI_ROOT + "Buttons/Button_Blue_9Slides.png"
const TEX_BUTTON_HOVER: String = TS_UI_ROOT + "Buttons/Button_Hover_9Slides.png"
const TEX_BUTTON_PRESSED: String = TS_UI_ROOT + "Buttons/Button_Blue_9Slides_Pressed.png"
const TEX_BUTTON_DISABLED: String = TS_UI_ROOT + "Buttons/Button_Disable_9Slides.png"
## Ribbon banners (192x64, folded-cloth ends): the HUD's Wave banner and any
## section-heading ribbon.
const TEX_RIBBON_YELLOW: String = TS_UI_ROOT + "Ribbons/Ribbon_Yellow_3Slides.png"
const TEX_RIBBON_BLUE: String = TS_UI_ROOT + "Ribbons/Ribbon_Blue_3Slides.png"
const TEX_RIBBON_RED: String = TS_UI_ROOT + "Ribbons/Ribbon_Red_3Slides.png"
## Gold-coin-pouch icon (128x128), used for the HUD's Scrap field (task
## instruction: "Scrap shown with the gold icon").
const TEX_SCRAP_ICON: String = "res://assets/third_party/tiny_swords/Resources/Resources/G_Idle_NoShadow.png"

## 9-slice texture margins, in source-texture pixels, measured directly
## against the PNGs (sandbox/inspect PIL scan, this session): the carved
## ink-outline + bevel band on every `_9Slides.png` sheet (192x192) reads as
## flat, repeatable fill by roughly 28-30px in from each edge. 26 sits just
## inside that, so the decorative frame stays crisp and un-stretched even on
## a HUD pill as short as ~56px tall (half of 26*2) while leaving the
## flat interior free to stretch/tile for any larger panel.
const PANEL_TEXTURE_MARGIN: int = 26
## A shallow row/cell (the run-end stat grid) is often well under
## 2*PANEL_TEXTURE_MARGIN tall; Godot proportionally shrinks a
## StyleBoxTexture's margins to fit a box smaller than that, which
## compresses the carved-wood corner art into an illegible smear (measured
## against a real capture during this pass: the run-end stat cells read as
## a faint dashed line, not a visible frame). A smaller, dedicated margin
## for shallow rows keeps the frame crisp at their real height instead.
const ROW_TEXTURE_MARGIN: int = 12
## The 3-slice ribbon sheets (192x64) are exactly three 64px thirds (left
## flag end / body / right flag end, PROVENANCE.md's own sheet-layout
## convention) -- 64 is the true, exact seam, not a measured approximation,
## and only the horizontal margins are used (a ribbon's height never
## stretches).
const RIBBON_TEXTURE_MARGIN: int = 64

## HUD polish (coordinator review, third pass): the Draft card's own
## background was a TILED 64x64 swatch (Carved_Regular.png repeated), which
## the coordinator's capture showed as a visible "waffle grid" of seams --
## a real defect, not a matter of taste (a tiled texture at this scale has
## no seamless edge). Replaced with a flat, calm parchment fill + a dark
## wood border on the card's own StyleBoxFlat (draft_card_view.gd already
## owns one for its runtime corner-radius mutation) -- no texture, so no
## seam is possible. Colours sampled from the Carved sheets' own measured
## fill/outline (PIL scan, first UI pass) rather than invented.
const PARCHMENT: Color = Color("d9c7a0")      ## flat parchment card fill
const WOOD_BORDER: Color = Color("4a3018")    ## dark wood-brown card frame

# --- Text -----------------------------------------------------------------
const TEXT: Color = Color("f5ecd8")           ## warm parchment-white (was a cooler cream)
const TEXT_DIM: Color = Color("b3a181")       ## warm dim tan (was blue-grey)
const TEXT_DISABLED: Color = Color("6b5f4f")  ## warm dim brown (was blue-grey)
const TEXT_OUTLINE: Color = Color(0.05, 0.03, 0.02, 0.95) ## near-black, warmed to match the wood ink rather than a blue-black

# --- Semantic -------------------------------------------------------------
const ACCENT: Color = Color("ffd866")         ## focus, highlight, fill rings
const PLAYER: Color = Color("62d26f")         ## player health, player cards
const TOWER: Color = Color("e8a33d")          ## Tower health, Tower cards
const SHIELD: Color = Color("8fd3ff")         ## Tower shield segment
const DANGER: Color = Color("e5484d")         ## low health, threat, defeat
const XP: Color = Color("a78bfa")             ## XP bar, level
const SCRAP: Color = Color("d9894a")          ## Scrap, prices
const GOLD: Color = Color("f4c430")           ## the Scrap icon's own coin colour; punch/glow accents that read as "treasure" rather than the cooler ACCENT gold
const SUCCESS: Color = Color("7be08a")        ## victory, affordable
## Meta layer core (Hub/Skill Tree screen): the Core currency's own colour --
## deliberately distinct from SCRAP/GOLD (the in-run economy) and XP (the
## player's own level bar), so a glance never confuses "Cores, spent between
## runs" with either in-run resource. An amethyst crystal tone (the Skill
## Tree screen draws it as a gem via UiShapeGlyph.Shape.CRYSTAL, not a font
## character or a reused Tiny Swords coin icon -- see that file's header).
const CORES: Color = Color("b18ee0")

# --- Dims (full-screen backdrops behind modal UI) -------------------------
const DIM_DRAFT: Color = Color(0.0, 0.0, 0.0, 1.0)  ## alpha is the owner's Register-cited figure
const DIM_TINT: Color = Color("0a0603")             ## tint used instead of pure black where the owner allows (warmed to match the wood/ink retint)

# --- Spacing (px at the 1920x1080 base resolution) ------------------------
const SPACE_XS: int = 4
const SPACE_S: int = 8
const SPACE_M: int = 12
const SPACE_L: int = 16
const SPACE_XL: int = 24
const SPACE_XXL: int = 32
const SCREEN_MARGIN: int = 20

# --- Shape ----------------------------------------------------------------
const RADIUS_PILL: int = 12
const RADIUS_PANEL: int = 8
const RADIUS_SMALL: int = 4
const BORDER_THIN: int = 2
const BORDER_THICK: int = 3
const SLIDER_PAD: int = 5                     ## half-height of a slider track

# --- Type -----------------------------------------------------------------
## Jersey 10 (SIL OFL 1.1, licence beside it). Author decision 2026-09-20,
## replacing Pixelify Sans, whose "5" read as "S" and "2" as "8" at HUD sizes
## (phases/UI_PASS/LEDGER.md, UR-15). It is a single-weight face: the two
## weights below only take effect if a variable font is put back.
const FONT_PATH: String = "res://assets/ui/fonts/Jersey10-Regular.ttf"
const FONT_WEIGHT_BODY: int = 500
const FONT_WEIGHT_DISPLAY: int = 700
## Sizes are tuned to Jersey 10, whose glyphs sit small in the em: about a
## quarter larger than the same role needed in Pixelify Sans.
const FONT_SIZE_SMALL: int = 20
const FONT_SIZE_BODY: int = 26
const FONT_SIZE_VALUE: int = 30
const FONT_SIZE_HEADING: int = 40
const FONT_SIZE_TITLE: int = 68
const OUTLINE_BODY: int = 4
const OUTLINE_DISPLAY: int = 8
const LINE_SPACING: int = 2

# --- Motion (seconds; all cosmetic, none gate input) ----------------------
const MOTION_FAST: float = 0.08
const MOTION_BASE: float = 0.16
const MOTION_SLOW: float = 0.28
const BAR_FLASH: float = 0.22                 ## white flash on a bar losing value
const BAR_LAG: float = 0.45                   ## trailing "ghost" segment catch-up
const BAR_SHAKE: float = 0.24                 ## HUD pill shake decay on a health loss
const BAR_SHAKE_AMPLITUDE_PX: float = 5.0     ## peak shake offset, decaying to 0 over BAR_SHAKE
const VALUE_PUNCH: float = 0.18               ## a HUD value label's scale-punch on change (Scrap count, etc.)
const VALUE_PUNCH_SCALE: float = 1.35         ## peak scale of a value punch
const XP_GLOW: float = 0.35                   ## XP bar's brief brighten on a gain
const XP_BURST: float = 0.55                  ## XP bar/level emblem celebration burst on a level-up


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
