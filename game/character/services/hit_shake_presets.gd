class_name HitShakePresets
extends RefCounted

enum Preset { LIGHT, MEDIUM, HEAVY, CRITICAL, JAB, MAGIC, BLOCK_HIT, CUSTOM, NONE }

const DATA := {
	Preset.LIGHT: {
		"distance": 6.0, "duration": 0.18, "oscillations": 4,
		"decay": 0.55, "return_mult": 1.2
	},
	Preset.MEDIUM: {
		"distance": 14.0, "duration": 0.30, "oscillations": 7,
		"decay": 0.65, "return_mult": 1.5
	},
	Preset.HEAVY: {
		"distance": 24.0, "duration": 0.45, "oscillations": 6,
		"decay": 0.78, "return_mult": 1.6
	},
	Preset.CRITICAL: {
		"distance": 32.0, "duration": 0.55, "oscillations": 9,
		"decay": 0.80, "return_mult": 2.0
	},
	Preset.JAB: {
		"distance": 8.0, "duration": 0.12, "oscillations": 3,
		"decay": 0.45, "return_mult": 1.0
	},
	Preset.MAGIC: {
		"distance": 10.0, "duration": 0.40, "oscillations": 8,
		"decay": 0.70, "return_mult": 1.8
	},
	Preset.BLOCK_HIT: {
		"distance": 6.0, "duration": 0.20, "oscillations": 5,
		"decay": 0.60, "return_mult": 1.3
	},
	Preset.NONE: {
		"distance": 0.0, "duration": 0.0, "oscillations": 0,
		"decay": 0.0, "return_mult": 0.0
	},
}


static func resolve(preset: int, custom: Dictionary) -> Dictionary:
	if preset == Preset.CUSTOM:
		return custom
	return DATA.get(preset, DATA[Preset.MEDIUM])
