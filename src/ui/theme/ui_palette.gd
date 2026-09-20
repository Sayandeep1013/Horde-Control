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

# --- Surfaces -------------------------------------------------------------
const INK: Color = Color("0b1014")            ## deepest panel fill
const SURFACE: Color = Color("141c23")        ## raised panel / card fill
const SURFACE_HOVER: Color = Color("1d2933")  ## hovered / highlighted row fill
const LINE: Color = Color("3a4a55")           ## resting border
const LINE_STRONG: Color = Color("6b7f8c")    ## emphasised resting border
const PANEL_ALPHA: float = 0.88               ## HUD pills and floating panels
const CARD_ALPHA: float = 0.96                ## modal cards over a dim

# --- Text -----------------------------------------------------------------
const TEXT: Color = Color("ede6d6")
const TEXT_DIM: Color = Color("8a97a0")
const TEXT_DISABLED: Color = Color("5a656d")
const TEXT_OUTLINE: Color = Color(0.02, 0.03, 0.04, 0.95)

# --- Semantic -------------------------------------------------------------
const ACCENT: Color = Color("ffd866")         ## focus, highlight, fill rings
const PLAYER: Color = Color("62d26f")         ## player health, player cards
const TOWER: Color = Color("e8a33d")          ## Tower health, Tower cards
const SHIELD: Color = Color("8fd3ff")         ## Tower shield segment
const DANGER: Color = Color("e5484d")         ## low health, threat, defeat
const XP: Color = Color("a78bfa")             ## XP bar, level
const SCRAP: Color = Color("d9894a")          ## Scrap, prices
const SUCCESS: Color = Color("7be08a")        ## victory, affordable

# --- Dims (full-screen backdrops behind modal UI) -------------------------
const DIM_DRAFT: Color = Color(0.0, 0.0, 0.0, 1.0)  ## alpha is the owner's Register-cited figure
const DIM_TINT: Color = Color("05080b")             ## tint used instead of pure black where the owner allows

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

# --- Type -----------------------------------------------------------------
const FONT_PATH: String = "res://assets/ui/fonts/PixelifySans-Variable.ttf"
const FONT_WEIGHT_BODY: int = 500
const FONT_WEIGHT_DISPLAY: int = 700
const FONT_SIZE_SMALL: int = 16
const FONT_SIZE_BODY: int = 20
const FONT_SIZE_VALUE: int = 24
const FONT_SIZE_HEADING: int = 32
const FONT_SIZE_TITLE: int = 56
const OUTLINE_BODY: int = 4
const OUTLINE_DISPLAY: int = 8

# --- Motion (seconds; all cosmetic, none gate input) ----------------------
const MOTION_FAST: float = 0.08
const MOTION_BASE: float = 0.16
const MOTION_SLOW: float = 0.28
const BAR_FLASH: float = 0.22                 ## white flash on a bar losing value
const BAR_LAG: float = 0.45                   ## trailing "ghost" segment catch-up


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
