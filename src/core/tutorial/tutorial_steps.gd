class_name TutorialSteps
extends RefCounted
## Tutoriel « Premiers pas » (ADR-051), logique pure : une leçon par tronçon du
## parcours d'entraînement. La leçon affichée suit le tronçon où se trouve le
## coureur ; elle est validée quand le geste attendu est vu (état du coureur,
## figure, objet utilisé). Les obstacles imposent le geste (trou, tunnel, mur) :
## on ne peut pas avancer sans l'avoir fait, sauf pour SPRINT et OBJET.

## Leçons dans l'ordre des tronçons (identifiants de data/levels/tutorial_library.tres).
const LESSONS: Array[Dictionary] = [
	{"chunk": &"t_run", "text": "Touche la flèche droite et garde le doigt dessus pour courir.",
		"done_states": [&"RUN", &"SPRINT"]},
	{"chunk": &"t_jump", "text": "Un trou ! Appuie sur SAUT juste avant le bord.",
		"done_states": [&"JUMP"]},
	{"chunk": &"t_slide", "text": "Passage bas : en courant, appuie sur GLISSE pour passer dessous.",
		"done_states": [&"SLIDE"]},
	{"chunk": &"t_vault", "text": "Obstacles bas : continue de courir, tu les franchis tout seul.",
		"done_states": [&"VAULT"]},
	{"chunk": &"t_climb", "text": "Mur haut : cours vers lui et garde la direction pour grimper puis te hisser.",
		"done_states": [&"WALL_RUN", &"WALL_CLIMB", &"LEDGE_HANG"]},
	{"chunk": &"t_sprint", "text": "Garde SPRINT appuyé pour courir plus vite et sauter plus loin.",
		"done_states": [&"SPRINT"]},
	{"chunk": &"t_item", "text": "Ton objet est en haut à gauche. Touche OBJET pour l'utiliser !",
		"done_item": true},
	{"chunk": &"t_spikes", "text": "Des pics ! Saute par-dessus. Si tu les touches, tu repars juste avant, gratuitement.",
		"done_past": 560.0},
	{"chunk": &"t_end", "text": "Dernière ligne droite : passe la ligne d'arrivée !",
		"done_states": []},
]

## Leçon affichée (-1 : aucune) et leçons réussies.
var current: int = -1
var done: Array[bool] = []


func _init() -> void:
	done.resize(LESSONS.size())
	done.fill(false)


static func index_of_chunk(chunk_id: StringName) -> int:
	for i: int in LESSONS.size():
		if LESSONS[i]["chunk"] == chunk_id:
			return i
	return -1


func text() -> String:
	return str(LESSONS[current]["text"]) if current >= 0 else ""


func is_current_done() -> bool:
	return current >= 0 and done[current]


func done_count() -> int:
	return done.count(true)


## Met à jour avec l'état du coureur. chunk_id : tronçon où il se trouve ;
## state : nom de l'état (RUN, JUMP…) ; local_x : position dans le tronçon ;
## item_used : un objet a été utilisé. Retourne vrai si la leçon change ou est réussie.
func update(chunk_id: StringName, state: StringName, local_x: float, item_used: bool) -> bool:
	var changed: bool = false
	var index: int = index_of_chunk(chunk_id)
	if index >= 0 and index != current:
		current = index
		changed = true
	if current < 0 or done[current]:
		return changed
	var lesson: Dictionary = LESSONS[current]
	var success: bool = false
	if lesson.has("done_states") and (lesson["done_states"] as Array).has(state):
		success = true
	if lesson.get("done_item", false) and item_used:
		success = true
	if lesson.has("done_past") and local_x > float(lesson["done_past"]):
		success = true
	if success:
		done[current] = true
		changed = true
	return changed
