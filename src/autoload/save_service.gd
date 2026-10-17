class_name SaveServiceNode
extends Node
## Autoload « SaveService » — lecture/écriture atomiques de user://save.json
## (SaveStore), versions de schéma, migrations, sauvegarde de secours (.bak).
## N'interprète pas les sections : chaque service lit et écrit la sienne.

signal saved(error: Error)

var store: SaveStore = SaveStore.new()
var data: Dictionary = SaveSchema.empty()

var _save_pending: bool = false


func _ready() -> void:
	reload()


## Relit le disque (au démarrage, ou après use_store dans les tests).
func reload() -> void:
	data = store.load()
	if store.last_main_corrupted:
		push_warning("SaveService : sauvegarde principale corrompue, reprise depuis %s" % SaveStore.Source.keys()[store.last_source])


## Change de fichier (tests : dossier temporaire) et le relit.
func use_store(other: SaveStore) -> void:
	store = other
	reload()


func section(name: String) -> Dictionary:
	var sections: Dictionary = data.get("sections", {})
	return (sections.get(name, {}) as Dictionary).duplicate(true)


## Remplace une section ; l'écriture sur disque est regroupée en fin d'image.
func set_section(name: String, value: Dictionary) -> void:
	var sections: Dictionary = data.get("sections", {})
	sections[name] = value.duplicate(true)
	data["sections"] = sections
	if not _save_pending:
		_save_pending = true
		save_now.call_deferred()


func save_now() -> Error:
	_save_pending = false
	var error: Error = store.write(data)
	if error != OK:
		push_warning("SaveService : écriture impossible (%s)" % error_string(error))
	saved.emit(error)
	return error
