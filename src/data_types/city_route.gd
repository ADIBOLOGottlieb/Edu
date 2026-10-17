class_name CityRoute
extends Resource
## Un parcours d'une ville : suite fixe de tronçons, du départ à l'arrivée.

@export var id: StringName = &""
## Nom affiché (quartier, lieu de la ville).
@export var display_name: String = ""
## 0 = initiation … 4 = expert (repris des tronçons).
@export_range(0, 4) var difficulty: int = 0
## Identifiants des tronçons de la ChunkLibrary, dans l'ordre.
@export var chunk_ids: Array[StringName] = []
