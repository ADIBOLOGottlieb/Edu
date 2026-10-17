extends GutTest
## Sauvegarde (§11) : écriture atomique, sauvegarde de secours, corruption,
## migrations une par une, version inconnue refusée sans abîmer le fichier.

var _dir: String = ""
var _store: SaveStore


func before_each() -> void:
	_dir = "user://test_saves/save_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_dir)
	_store = SaveStore.new(_dir, "save.json")


func after_each() -> void:
	for file: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file))
	DirAccess.remove_absolute(_dir)


func _data(marker: int) -> Dictionary:
	var data: Dictionary = SaveSchema.empty()
	data["sections"]["profile"] = {"marker": marker}
	return data


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_write_then_load_round_trip() -> void:
	assert_eq(_store.write(_data(1)), OK)
	var loaded: Dictionary = _store.load()
	assert_eq(_store.last_source, SaveStore.Source.MAIN)
	assert_eq(int(loaded["sections"]["profile"]["marker"]), 1)
	assert_eq(int(loaded["schema_version"]), SaveSchema.CURRENT_VERSION)
	assert_true(str(loaded["written_at_utc"]).ends_with("Z"), "horodatage UTC")


func test_second_write_keeps_previous_as_backup_and_leaves_no_tmp() -> void:
	_store.write(_data(1))
	_store.write(_data(2))
	assert_false(FileAccess.file_exists(_store.tmp_path()), "pas de fichier temporaire restant")
	assert_true(FileAccess.file_exists(_store.backup_path()))
	var backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_store.backup_path()))
	assert_eq(int(backup["sections"]["profile"]["marker"]), 1, "l'ancien fichier devient .bak")
	assert_eq(int(_store.load()["sections"]["profile"]["marker"]), 2)


func test_truncated_main_falls_back_to_backup() -> void:
	_store.write(_data(1))
	_store.write(_data(2))
	var text: String = FileAccess.get_file_as_string(_store.main_path())
	_write_raw(_store.main_path(), text.substr(0, text.length() / 2))
	var loaded: Dictionary = _store.load()
	assert_true(_store.last_main_corrupted)
	assert_eq(_store.last_source, SaveStore.Source.BACKUP)
	assert_eq(int(loaded["sections"]["profile"]["marker"]), 1)


func test_tampered_content_is_detected_by_checksum() -> void:
	_store.write(_data(1))
	_store.write(_data(2))
	var text: String = FileAccess.get_file_as_string(_store.main_path())
	_write_raw(_store.main_path(), text.replace("\"marker\": 2", "\"marker\": 9"))
	_store.load()
	assert_eq(_store.last_source, SaveStore.Source.BACKUP, "JSON valide mais somme fausse : rejeté")


func test_everything_corrupted_starts_a_new_game() -> void:
	_write_raw(_store.main_path(), "{pas du json")
	_write_raw(_store.backup_path(), "")
	var loaded: Dictionary = _store.load()
	assert_eq(_store.last_source, SaveStore.Source.NEW)
	assert_eq(loaded, SaveSchema.empty())


func test_crash_leftover_tmp_is_ignored_and_replaced() -> void:
	_store.write(_data(1))
	# Coupure pendant une écriture : un save.tmp à moitié écrit traîne.
	_write_raw(_store.tmp_path(), "{\"sections\": {")
	assert_eq(int(_store.load()["sections"]["profile"]["marker"]), 1, "le fichier principal est intact")
	assert_eq(_store.write(_data(2)), OK)
	assert_eq(int(_store.load()["sections"]["profile"]["marker"]), 2)
	assert_false(FileAccess.file_exists(_store.tmp_path()))


func test_migration_v1_to_v2_moves_levels_into_progress() -> void:
	var v1: Dictionary = {
		"schema_version": 1,
		"sections": {"profile": {"levels": {"lome_be": 30.5}, "name": "Ama"}, "settings": {"music_volume": 0.4}},
	}
	var migrated: Dictionary = SaveSchema.migrate(v1, 1)
	assert_eq(int(migrated["schema_version"]), 2)
	var route: Dictionary = migrated["sections"]["progress"]["routes"]["lome_be"]
	assert_true(bool(route["completed"]))
	assert_almost_eq(float(route["best_time"]), 30.5, 0.001)
	assert_false((migrated["sections"]["profile"] as Dictionary).has("levels"))
	assert_eq(str(migrated["sections"]["profile"]["name"]), "Ama", "le reste est conservé")
	for section: String in SaveSchema.SECTIONS:
		assert_true((migrated["sections"] as Dictionary).has(section), "section %s présente" % section)


func test_v1_file_is_migrated_on_load() -> void:
	var sections: Dictionary = {"profile": {"levels": {"lome_boulevard": 21.0}}}
	var v1: Dictionary = {"schema_version": 1, "checksum": SaveStore.checksum(sections), "sections": sections}
	_write_raw(_store.main_path(), JSON.stringify(v1))
	var loaded: Dictionary = _store.load()
	assert_eq(_store.last_migrated_from, 1)
	assert_true((loaded["sections"]["progress"]["routes"] as Dictionary).has("lome_boulevard"))


func test_newer_unknown_version_is_refused_without_touching_the_file() -> void:
	var sections: Dictionary = {"profile": {"future": true}}
	var future: Dictionary = {"schema_version": 99, "checksum": SaveStore.checksum(sections), "sections": sections}
	var text: String = JSON.stringify(future)
	_write_raw(_store.main_path(), text)
	var loaded: Dictionary = _store.load()
	assert_eq(loaded, SaveSchema.empty(), "partie neuve en mémoire")
	assert_eq(FileAccess.get_file_as_string(_store.main_path()), text, "fichier du futur intact")


func test_no_payment_data_in_schema() -> void:
	for section: String in SaveSchema.SECTIONS:
		assert_false(section.contains("card") or section.contains("payment"), section)
