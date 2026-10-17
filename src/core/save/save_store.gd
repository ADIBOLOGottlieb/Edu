class_name SaveStore
extends RefCounted
## Lecture et écriture atomiques du fichier de sauvegarde (§11), sans SceneTree.
## Écriture : save.tmp → relecture et vérification → l'ancien save devient save.bak
## → save.tmp devient save. Lecture : save, sinon save.bak, sinon partie neuve.
## La somme de contrôle détecte la corruption (pas d'anti-triche).

## D'où viennent les données chargées.
enum Source { MAIN, BACKUP, NEW }

var directory: String = "user://"
var file_name: String = "save.json"

## Résultat du dernier chargement (pour le journal et les tests).
var last_source: Source = Source.NEW
## Vrai si le fichier principal était illisible ou corrompu au dernier chargement.
var last_main_corrupted: bool = false
var last_migrated_from: int = 0


func _init(save_directory: String = "user://", save_file_name: String = "save.json") -> void:
	directory = save_directory
	file_name = save_file_name


func main_path() -> String:
	return directory.path_join(file_name)


func tmp_path() -> String:
	return directory.path_join(file_name.get_basename() + ".tmp")


func backup_path() -> String:
	return directory.path_join(file_name.get_basename() + ".bak")


## Écrit `data` de façon atomique. Retourne OK ou l'erreur rencontrée ; en cas
## d'erreur, le fichier principal existant n'est jamais touché.
func write(data: Dictionary) -> Error:
	var out: Dictionary = data.duplicate(true)
	out["schema_version"] = SaveSchema.CURRENT_VERSION
	out["written_at_utc"] = Time.get_datetime_string_from_system(true) + "Z"
	out["checksum"] = checksum(out.get("sections", {}))
	var text: String = JSON.stringify(out, "\t", true)
	var file: FileAccess = FileAccess.open(tmp_path(), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	# Relecture : le fichier temporaire doit être complet et cohérent.
	var check: Dictionary = _read_valid(tmp_path())
	if check.is_empty():
		DirAccess.remove_absolute(tmp_path())
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(main_path()):
		if FileAccess.file_exists(backup_path()):
			DirAccess.remove_absolute(backup_path())
		var to_backup: Error = DirAccess.rename_absolute(main_path(), backup_path())
		if to_backup != OK:
			return to_backup
	return DirAccess.rename_absolute(tmp_path(), main_path())


## Charge la sauvegarde la plus récente valide, migrée à la version courante.
func load() -> Dictionary:
	last_main_corrupted = false
	last_migrated_from = 0
	var data: Dictionary = _read_valid(main_path())
	if not data.is_empty():
		last_source = Source.MAIN
		return _upgrade(data)
	last_main_corrupted = FileAccess.file_exists(main_path())
	data = _read_valid(backup_path())
	if not data.is_empty():
		last_source = Source.BACKUP
		return _upgrade(data)
	last_source = Source.NEW
	return SaveSchema.empty()


static func checksum(sections: Variant) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	# Forme canonique : comme relue depuis le disque (les entiers JSON redeviennent
	# des nombres décimaux), clés triées.
	var canonical: Variant = JSON.parse_string(JSON.stringify(sections))
	context.update(JSON.stringify(canonical, "", true).to_utf8_buffer())
	return context.finish().hex_encode()


## Contenu du fichier s'il est lisible, complet et non corrompu ; {} sinon.
func _read_valid(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	# Instance JSON : une erreur d'analyse est rendue, pas journalisée (fichier abîmé).
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	if not data.has("sections") or not data.has("schema_version") or not data.has("checksum"):
		return {}
	if str(data["checksum"]) != checksum(data["sections"]):
		return {}
	return data


func _upgrade(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("schema_version", 0))
	if version == SaveSchema.CURRENT_VERSION:
		return data
	var migrated: Dictionary = SaveSchema.migrate(data, version)
	if migrated.is_empty():
		# Version inconnue (plus récente) : partie neuve en mémoire, fichier intact.
		last_source = Source.NEW
		return SaveSchema.empty()
	last_migrated_from = version
	return migrated
