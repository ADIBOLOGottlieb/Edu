extends GutTest
## Énergie par parcours (ADR-049) : dépense, remboursement à l'arrivée, recharge
## 1 ticket / 72 min, plein, horloge reculée, sauvegarde abîmée, affichage.

const T0: int = 1_800_000_000
const R: int = EnergyMeter.REGEN_SECONDS


func test_starts_full_and_spends() -> void:
	var meter: EnergyMeter = EnergyMeter.new()
	assert_eq(meter.tickets, EnergyMeter.MAX_TICKETS)
	assert_eq(meter.seconds_to_next(T0), 0, "plein : pas de recharge")
	assert_true(meter.spend(T0))
	assert_eq(meter.tickets, 4)
	assert_eq(meter.seconds_to_next(T0), R)


func test_empty_refuses() -> void:
	var meter: EnergyMeter = EnergyMeter.new()
	for i: int in 5:
		assert_true(meter.spend(T0))
	assert_false(meter.can_spend(T0))
	assert_false(meter.spend(T0 + 10))
	assert_eq(meter.tickets, 0)


func test_finishing_refunds_the_ticket() -> void:
	var meter: EnergyMeter = EnergyMeter.new()
	meter.spend(T0)
	meter.refund(T0 + 120)
	assert_eq(meter.tickets, 5, "arrivée : ticket rendu")
	assert_eq(meter.seconds_to_next(T0 + 120), 0, "plein : recharge arrêtée")


func test_regen_one_ticket_per_72_minutes() -> void:
	var meter: EnergyMeter = EnergyMeter.new()
	for i: int in 5:
		meter.spend(T0)
	meter.refresh(T0 + R - 1)
	assert_eq(meter.tickets, 0)
	meter.refresh(T0 + R)
	assert_eq(meter.tickets, 1)
	assert_eq(meter.seconds_to_next(T0 + R + 60), R - 60, "la recharge suivante continue")
	meter.refresh(T0 + 3 * R + 30)
	assert_eq(meter.tickets, 3)
	meter.refresh(T0 + 100 * R)
	assert_eq(meter.tickets, EnergyMeter.MAX_TICKETS, "jamais au-delà du plein par la recharge")


func test_six_hours_refill_from_empty() -> void:
	var meter: EnergyMeter = EnergyMeter.new()
	for i: int in 5:
		meter.spend(T0)
	meter.refresh(T0 + 6 * 3600)
	assert_eq(meter.tickets, 5, "5 × 72 min = 6 h")


func test_clock_moved_back_gives_no_time() -> void:
	var meter: EnergyMeter = EnergyMeter.new()
	meter.spend(T0)
	meter.refresh(T0 + 1000)
	var left: int = meter.seconds_to_next(T0 + 1000)
	meter.refresh(T0 - 50_000)
	assert_eq(meter.seconds_to_next(T0 - 50_000), left, "temps restant conservé")
	meter.refresh(T0 - 50_000 + left)
	assert_eq(meter.tickets, 5, "le temps compte de nouveau après le recul")


func test_extra_tickets_above_max_and_clamping() -> void:
	var meter: EnergyMeter = EnergyMeter.new()
	meter.add(3, T0)
	assert_eq(meter.tickets, 8, "achat / récompense : au-delà du plein")
	assert_true(meter.spend(T0))
	assert_eq(meter.seconds_to_next(T0), 0, "encore au-dessus du plein : pas de recharge")
	meter.add(500, T0)
	assert_eq(meter.tickets, EnergyMeter.MAX_STORED)


func test_round_trip_and_bad_save() -> void:
	var meter: EnergyMeter = EnergyMeter.new()
	meter.spend(T0)
	meter.spend(T0 + 100)
	var restored: EnergyMeter = EnergyMeter.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(meter.to_dict())), T0 + R)
	assert_eq(restored.tickets, 4, "1 ticket revenu pendant l'absence")
	var bad: EnergyMeter = EnergyMeter.new()
	bad.from_dict({"tickets": -7, "regen_from": T0 + 9_999_999, "last_seen": "x"}, T0)
	assert_eq(bad.tickets, 0)
	assert_true(bad.regen_from <= T0, "départ de recharge jamais dans le futur")
	bad.from_dict({}, T0)
	assert_eq(bad.tickets, EnergyMeter.MAX_TICKETS, "section vide : plein")


func test_format_wait() -> void:
	assert_eq(EnergyMeter.format_wait(4320), "1 h 12")
	assert_eq(EnergyMeter.format_wait(3120), "52 min")
	assert_eq(EnergyMeter.format_wait(61), "2 min")
	assert_eq(EnergyMeter.format_wait(30), "30 s")
