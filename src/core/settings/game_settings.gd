class_name GameSettings
extends RefCounted
## Réglages du joueur (§4 SettingsService) : logique pure, valeurs bornées,
## sérialisés dans la section « settings ».

const QUALITIES: Array[StringName] = [&"low", &"medium", &"high"]
const LANGUAGES: Array[StringName] = [&"fr", &"en"]

## Volumes de 0 (muet) à 1.
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var vibrations: bool = true
## Opacité des commandes tactiles (0,2 à 1).
var touch_opacity: float = 0.6
## Taille des boutons tactiles (0,8 à 1,4).
var touch_scale: float = 1.0
## &"low", &"medium", &"high".
var quality: StringName = &"high"
var language: StringName = &"fr"
## Compteur d'images par seconde en haut à gauche (mesure sur téléphone).
var show_fps: bool = false
## Éclaboussures de sang à la mort par un piège (ADR-052) ; désactivable.
var blood_effects: bool = true


func to_dict() -> Dictionary:
	return {
		"music_volume": music_volume, "sfx_volume": sfx_volume, "vibrations": vibrations,
		"touch_opacity": touch_opacity, "touch_scale": touch_scale,
		"quality": String(quality), "language": String(language), "show_fps": show_fps,
		"blood_effects": blood_effects,
	}


## Charge en bornant chaque valeur ; une clé absente ou invalide garde sa valeur par défaut.
func from_dict(data: Dictionary) -> void:
	music_volume = clampf(float(data.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	vibrations = bool(data.get("vibrations", vibrations))
	show_fps = bool(data.get("show_fps", show_fps))
	blood_effects = bool(data.get("blood_effects", blood_effects))
	touch_opacity = clampf(float(data.get("touch_opacity", touch_opacity)), 0.2, 1.0)
	touch_scale = clampf(float(data.get("touch_scale", touch_scale)), 0.8, 1.4)
	var wanted_quality: StringName = StringName(str(data.get("quality", quality)))
	quality = wanted_quality if QUALITIES.has(wanted_quality) else quality
	var wanted_language: StringName = StringName(str(data.get("language", language)))
	language = wanted_language if LANGUAGES.has(wanted_language) else language


## Décibels pour un volume linéaire (0 → silence).
static func to_db(volume: float) -> float:
	return linear_to_db(volume) if volume > 0.001 else -80.0
