extends RefCounted

class_name Element

# Elemental chain. Each element is strong against ("beats") the next one in the
# cycle, which loops back to the start. This is the reverse of the original
# Fire → Ice → Lightning → Earth → Fire ordering:
#   Fire → Earth → Lightning → Ice → Fire
# so, notably, Ice now beats Fire.
enum Type {
	FIRE,
	ICE,
	LIGHTNING,
	EARTH,
}

# The element each type is strong against.
const STRONG_AGAINST = {
	Type.FIRE: Type.EARTH,
	Type.EARTH: Type.LIGHTNING,
	Type.LIGHTNING: Type.ICE,
	Type.ICE: Type.FIRE,
}

# Display tint for each element, used to colour bombs and effects.
const COLORS = {
	Type.FIRE: Color(0.9, 0.15, 0.1),
	Type.ICE: Color(0.15, 0.35, 0.9),
	Type.LIGHTNING: Color(1.0, 0.9, 0.25),
	Type.EARTH: Color(0.65, 0.45, 0.25),
}

const NAMES = {
	Type.FIRE: "Fire",
	Type.ICE: "Ice",
	Type.LIGHTNING: "Lightning",
	Type.EARTH: "Earth",
}

# True when `attacker` is strong against `defender` per the elemental chain.
static func beats(attacker: Type, defender: Type) -> bool:
	return STRONG_AGAINST.get(attacker, -1) == defender

static func get_color(type: Type) -> Color:
	return COLORS.get(type, Color.WHITE)

static func get_display_name(type: Type) -> String:
	return NAMES.get(type, "Unknown")

# Lowercase key (e.g. "fire") used to build item ids like "fire_bomb".
static func get_key(type: Type) -> String:
	return get_display_name(type).to_lower()

# A solid-colour square texture, used for bomb icons in the inventory.
static func make_square_texture(color: Color, size: int = 16) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
