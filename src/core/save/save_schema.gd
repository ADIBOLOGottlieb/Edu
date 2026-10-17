class_name SaveSchema
extends RefCounted
## Format de user://save.json (docs/ARCHITECTURE.md §11) et migrations.
##   { schema_version, written_at_utc, checksum, sections: { profile, progress,
##     settings, attempts, narrative, inventory, entitlements_cache } }
## Chaque migration fait passer d'une version à la suivante ; elles sont testées
## une par une. Aucune donnée de paiement n'est jamais sauvegardée.

const CURRENT_VERSION: int = 2
const SECTIONS: Array[String] = [
	"profile", "progress", "settings", "attempts", "narrative", "inventory", "entitlements_cache",
]


static func empty() -> Dictionary:
	var sections: Dictionary = {}
	for section: String in SECTIONS:
		sections[section] = {}
	return {"schema_version": CURRENT_VERSION, "written_at_utc": "", "sections": sections}


## Amène `data` (version `from_version`) jusqu'à CURRENT_VERSION. Une version plus
## récente que le jeu est refusée (retourne {}), pour ne jamais l'abîmer.
static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version > CURRENT_VERSION or from_version < 1:
		return {}
	var migrated: Dictionary = data.duplicate(true)
	var version: int = from_version
	while version < CURRENT_VERSION:
		match version:
			1:
				migrated = _v1_to_v2(migrated)
		version += 1
	migrated["schema_version"] = CURRENT_VERSION
	return migrated


## v1 (squelette M0) : progression des niveaux rangée dans « profile.levels »
## (identifiant → meilleur temps). v2 : section « progress » dédiée aux villes.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var sections: Dictionary = data.get("sections", {})
	var profile: Dictionary = sections.get("profile", {})
	var routes: Dictionary = {}
	var levels: Dictionary = profile.get("levels", {})
	for route_id: Variant in levels:
		routes[str(route_id)] = {"completed": true, "best_time": float(levels[route_id]), "stars": 1}
	profile.erase("levels")
	sections["profile"] = profile
	sections["progress"] = {"routes": routes}
	for section: String in SECTIONS:
		if not sections.has(section):
			sections[section] = {}
	data["sections"] = sections
	return data
