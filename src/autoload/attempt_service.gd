class_name AttemptServiceNode
extends Node
## Autoload « AttemptService » — énergie du mode course par parcours (ADR-049,
## EnergyMeter), section « attempts » de la sauvegarde. Un parcours déjà réussi
## se rejoue gratuitement ; un nouveau parcours coûte un ticket, rendu à l'arrivée.
## Indépendant de la santé du personnage et de l'histoire.

signal changed()

enum Start { FREE, TICKET, EMPTY }

## Paramètre SceneRouter transmis au niveau : vrai si un ticket a été dépensé.
const TICKET_PARAM: String = "ticket"

var meter: EnergyMeter = EnergyMeter.new()
## Horloge UTC en secondes (remplaçable dans les tests).
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())


func _ready() -> void:
	reload()


func now() -> int:
	return int(clock.call())


func reload() -> void:
	var save_service: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	var saved: Dictionary = save_service.section("attempts") if save_service != null else {}
	meter = EnergyMeter.new()
	meter.from_dict(saved, now())
	changed.emit()


func save() -> void:
	var save_service: SaveServiceNode = get_node_or_null(^"/root/SaveService") as SaveServiceNode
	if save_service != null:
		save_service.set_section("attempts", meter.to_dict())


func tickets() -> int:
	meter.refresh(now())
	return meter.tickets


func seconds_to_next() -> int:
	return meter.seconds_to_next(now())


## Départ d'un parcours : gratuit s'il est déjà réussi, sinon un ticket (ou refus).
func request_start(already_completed: bool) -> Start:
	if already_completed:
		return Start.FREE
	if not meter.spend(now()):
		return Start.EMPTY
	save()
	changed.emit()
	return Start.TICKET


## Arrivée d'un parcours payé d'un ticket : le ticket est rendu.
func refund() -> void:
	meter.refund(now())
	save()
	changed.emit()


## « Énergie 4/5 · +1 dans 1 h 12 ».
func status_text() -> String:
	var text: String = "Énergie %d/%d" % [tickets(), EnergyMeter.MAX_TICKETS]
	var wait: int = seconds_to_next()
	if wait > 0:
		text += "  ·  +1 dans %s" % EnergyMeter.format_wait(wait)
	return text
