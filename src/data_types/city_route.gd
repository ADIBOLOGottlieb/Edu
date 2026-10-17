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
## Un vigile poursuit le coureur sur ce parcours (M5).
@export var pursuit: bool = false
## Délai avant l'entrée du vigile (s).
@export var pursuer_delay: float = 2.5
## Temps de référence (s) pour la 3e étoile (arrivée sans mort sous ce temps).
@export var par_time: float = 0.0
