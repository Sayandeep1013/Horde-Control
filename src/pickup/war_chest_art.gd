extends RefCounted
class_name WarChestArt
## v1.0 (WP-ENEMIES): a clean pixel-art treasure chest drawn into a 32x32
## ImageTexture, used when the project-made sprite
## res://assets/sprites/v1/war_chest.png (WP-ASSETS) is not present. Shown at
## 2x with nearest filtering by Pickup.

const SIZE: int = 32
const OUTLINE: Color = Color(0.13, 0.08, 0.05)
const WOOD: Color = Color(0.55, 0.32, 0.14)
const WOOD_LIGHT: Color = Color(0.70, 0.43, 0.2)
const WOOD_DARK: Color = Color(0.38, 0.21, 0.09)
const GOLD: Color = Color(0.98, 0.8, 0.2)
const GOLD_DARK: Color = Color(0.75, 0.55, 0.1)

static var _cache: ImageTexture = null


static func texture() -> ImageTexture:
	if _cache == null:
		_cache = ImageTexture.create_from_image(_build())
	return _cache


static func _build() -> Image:
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Body (x 4..27, y 14..27) and lid (x 4..27, y 7..14).
	_rect(img, 4, 14, 24, 14, OUTLINE)
	_rect(img, 5, 15, 22, 12, WOOD)
	_rect(img, 5, 15, 22, 2, WOOD_LIGHT)
	_rect(img, 5, 25, 22, 2, WOOD_DARK)
	_rect(img, 4, 7, 24, 8, OUTLINE)
	_rect(img, 5, 8, 22, 6, WOOD_LIGHT)
	_rect(img, 5, 12, 22, 2, WOOD)
	# Rounded lid top corners.
	for p in [Vector2i(4, 7), Vector2i(27, 7)]:
		img.set_pixelv(p, Color(0, 0, 0, 0))
	# Gold bands and lock.
	_rect(img, 9, 8, 3, 19, GOLD_DARK)
	_rect(img, 20, 8, 3, 19, GOLD_DARK)
	_rect(img, 9, 8, 1, 19, GOLD)
	_rect(img, 20, 8, 1, 19, GOLD)
	_rect(img, 14, 12, 4, 6, OUTLINE)
	_rect(img, 15, 13, 2, 4, GOLD)
	img.set_pixel(15, 15, OUTLINE)
	# Glint.
	_rect(img, 7, 9, 2, 1, Color(1, 1, 0.85))
	return img


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < SIZE and yy < SIZE:
				img.set_pixel(xx, yy, c)
