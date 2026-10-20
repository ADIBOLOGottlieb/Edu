class_name EnergyMeter
extends RefCounted
## Énergie du mode course (ADR-049), logique pure : des tickets. Lancer un
## parcours pas encore réussi coûte 1 ticket ; mourir et repartir au point de
## contrôle est gratuit ; l'arrivée rend le ticket (seuls les abandons coûtent).
## 1 ticket revient toutes les REGEN_SECONDS tant qu'on est sous MAX_TICKETS.
## Le temps est en secondes UTC fournies par l'appelant (horloge injectable).
## Horloge reculée : aucun temps accordé, le temps restant est conservé.

const MAX_TICKETS: int = 5
const REGEN_SECONDS: int = 72 * 60
## Plafond des tickets en réserve (achats, cadeaux), au-delà de la recharge.
const MAX_STORED: int = 99

var tickets: int = MAX_TICKETS
## Début de la recharge en cours (UTC) ; 0 = plein, pas de recharge.
var regen_from: int = 0
## Dernier instant vu (UTC), pour détecter une horloge reculée.
var last_seen: int = 0


## Met à jour la recharge jusqu'à `now`.
func refresh(now: int) -> void:
	if last_seen > 0 and now < last_seen:
		# Horloge reculée : on décale le départ de la recharge, aucun temps gagné.
		if regen_from > 0:
			regen_from -= last_seen - now
	last_seen = now
	if tickets >= MAX_TICKETS:
		regen_from = 0
		return
	if regen_from <= 0:
		regen_from = now
		return
	var gained: int = (now - regen_from) / REGEN_SECONDS
	if gained <= 0:
		return
	tickets = mini(MAX_TICKETS, tickets + gained)
	regen_from = 0 if tickets >= MAX_TICKETS else regen_from + gained * REGEN_SECONDS


func can_spend(now: int) -> bool:
	refresh(now)
	return tickets > 0


## Retire un ticket (départ d'un parcours). Faux s'il n'y en a plus.
func spend(now: int) -> bool:
	refresh(now)
	if tickets <= 0:
		return false
	tickets -= 1
	if tickets < MAX_TICKETS and regen_from <= 0:
		regen_from = now
	return true


## Rend un ticket (arrivée du parcours), sans dépasser le plein : un ticket
## revenu pendant la course compte déjà comme le ticket rendu.
func refund(now: int) -> void:
	refresh(now)
	if tickets < MAX_TICKETS:
		add(1, now)


## Ajoute des tickets (remboursement, récompense ; achat validé plus tard, M12).
func add(count: int, now: int) -> void:
	refresh(now)
	tickets = clampi(tickets + count, 0, MAX_STORED)
	if tickets >= MAX_TICKETS:
		regen_from = 0


## Secondes avant le prochain ticket (0 si plein).
func seconds_to_next(now: int) -> int:
	refresh(now)
	if tickets >= MAX_TICKETS:
		return 0
	return maxi(0, REGEN_SECONDS - (now - regen_from))


func to_dict() -> Dictionary:
	return {"tickets": tickets, "regen_from": regen_from, "last_seen": last_seen}


## Charge en bornant les valeurs (sauvegarde abîmée → valeur sûre la plus proche).
func from_dict(data: Dictionary, now: int) -> void:
	tickets = clampi(int(data.get("tickets", MAX_TICKETS)), 0, MAX_STORED)
	last_seen = clampi(int(data.get("last_seen", 0)), 0, now)
	regen_from = clampi(int(data.get("regen_from", 0)), 0, now)
	if tickets >= MAX_TICKETS:
		regen_from = 0
	refresh(now)


## « 1 h 12 », « 52 min », « 30 s ».
static func format_wait(seconds: int) -> String:
	if seconds >= 3600:
		return "%d h %02d" % [seconds / 3600, (seconds % 3600) / 60]
	if seconds >= 60:
		return "%d min" % ceili(seconds / 60.0)
	return "%d s" % seconds
