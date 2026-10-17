class_name Hazard
extends Node2D
## Piège d'un tronçon, construit à partir d'un HazardSpec (coordonnées locales au
## tronçon : LevelChunk ajoute le nœud à son origine). Difficulté façon Ninja Arashi :
## précis et punitif, mais lisible et annoncé (tremblement, étincelles) avant de tuer.
##
## - &"spikes"  : pics, toujours mortels.
## - &"saw"     : scie qui tourne, mortelle en permanence ; va-et-vient adouci de
##                rect.position à rect.position + path_to sur `period`.
## - &"crusher" : bloc (solide, on peut s'y poser) : repos, tremblement 0,3 s, chute
##                rapide de path_to, reste en bas, remonte lentement. Mortel pendant
##                la chute et en bas seulement (active_ratio du cycle).
## - &"flame"   : buse toujours visible ; crépite 0,35 s avant de s'allumer ; mortelle
##                allumée seulement (active_ratio du cycle ; period nulle = toujours).
## - &"crumble" : plateforme solide qui tremble quand on s'y pose, tombe après 0,5 s et
##                revient 3 s plus tard. Jamais mortelle elle-même.
##
## Le temps est une horloge interne (déterministe) avancée dans _physics_process ;
## reset() la remet à zéro (tronçons recyclés). La zone mortelle (Area2D, couche
## HAZARD) est testée à chaque tick tant que le piège est dangereux : une flamme qui
## s'allume sur le coureur le tue même sans nouvelle entrée dans la zone.

const SPIKES: StringName = &"spikes"
const SAW: StringName = &"saw"
const CRUSHER: StringName = &"crusher"
const FLAME: StringName = &"flame"
const CRUMBLE: StringName = &"crumble"

const DEFAULT_INK: Color = Color(0.04, 0.04, 0.05)
const DEFAULT_ACCENT: Color = Color(0.95, 0.70, 0.30)
const FLAME_OUTER: Color = Color(0.93, 0.30, 0.07)
const FLAME_MID: Color = Color(1.0, 0.60, 0.14)
const FLAME_CORE: Color = Color(1.0, 0.94, 0.66)
const EMBER: Color = Color(0.42, 0.10, 0.05)

## Marges d'équité : la zone mortelle est un peu plus petite que le dessin.
const SPIKE_MARGIN_X: float = 3.0
const SPIKE_MARGIN_TOP: float = 4.0
## Largeur d'un pic dessiné.
const SPIKE_PITCH: float = 14.0
## Rayon mortel de la scie / rayon dessiné (dents comprises).
const SAW_HIT_RATIO: float = 0.82
## Vitesse de rotation de la scie (rad/s).
const SAW_SPIN: float = 13.0
## Cycle par défaut d'une scie mobile sans période (s).
const SAW_DEFAULT_PERIOD: float = 2.4
const CRUSHER_DEFAULT_PERIOD: float = 3.0
## Tremblement d'annonce avant la chute (s).
const CRUSHER_SHAKE: float = 0.3
## Durée de la chute (s) : très rapide, comme un pilon.
const CRUSHER_DROP: float = 0.12
## Hauteur de la tige du vérin au-dessus de la position haute.
const CRUSHER_ROD: float = 34.0
const CRUSHER_TEETH: float = 10.0
## La zone mortelle couvre le bas du bloc et dépasse de quelques pixels dessous.
const CRUSHER_MARGIN: float = 4.0
const CRUSHER_LIP: float = 4.0
const FLAME_TELEGRAPH: float = 0.35
const FLAME_NOZZLE: float = 12.0
const FLAME_MARGIN: float = 4.0
## Durée d'embrasement visuel (la flamme est déjà mortelle).
const FLAME_GROW: float = 0.08
const CRUMBLE_DELAY: float = 0.5
const CRUMBLE_RESPAWN: float = 3.0
const CRUMBLE_FALL_ANIM: float = 0.45
const CRUMBLE_FADE_IN: float = 0.2
const DISABLED_ALPHA: float = 0.3

enum CrumbleState { SOLID, SHAKING, FALLEN }

var spec: HazardSpec
var ink: Color = DEFAULT_INK
var accent: Color = DEFAULT_ACCENT

var _time: float = 0.0
var _area: Area2D
var _hit_shape: CollisionShape2D
## Écraseur : corps mobile solide (couche WORLD).
var _crusher_body: AnimatableBody2D
## Plateforme fragile : corps solide et capteur de présence.
var _platform_shape: CollisionShape2D
var _sensor: Area2D
var _crumble_state: CrumbleState = CrumbleState.SOLID
## Temps passé dans l'état courant de la plateforme fragile.
var _crumble_time: float = 0.0
## Piratage (équipement) : piège inoffensif pendant ce temps (s).
var _disabled_left: float = 0.0


## theme nul = encre et accent par défaut.
static func create(hazard_spec: HazardSpec, city_theme: CityTheme) -> Hazard:
	assert(hazard_spec != null, "Hazard : HazardSpec manquant")
	var hazard: Hazard = Hazard.new()
	hazard.spec = hazard_spec
	if city_theme != null:
		hazard.ink = city_theme.ink
		hazard.accent = city_theme.accent
	hazard._build()
	hazard.reset()
	return hazard


## État initial (tronçons recyclés) : horloge à zéro, plateforme en place.
func reset() -> void:
	_disabled_left = 0.0
	modulate.a = 1.0
	_time = 0.0
	_crumble_state = CrumbleState.SOLID
	_crumble_time = CRUMBLE_FADE_IN
	if _platform_shape != null:
		_platform_shape.set_deferred(&"disabled", false)
	_apply_pose()
	queue_redraw()


## Place l'horloge (tests, aperçus). Ne touche pas à l'état de la plateforme fragile.
func set_time(t: float) -> void:
	_time = t
	_apply_pose()
	queue_redraw()


func get_time() -> float:
	return _time


## Rend le piège inoffensif (piratage) : il reste visible, estompé.
func disable_for(seconds: float) -> void:
	_disabled_left = maxf(_disabled_left, seconds)
	modulate.a = DISABLED_ALPHA


func is_disabled() -> bool:
	return _disabled_left > 0.0


## Avance l'horloge d'un pas : pose, plateforme fragile, puis mises à mort.
func advance(delta: float) -> void:
	if _disabled_left > 0.0:
		_disabled_left = maxf(0.0, _disabled_left - delta)
		modulate.a = DISABLED_ALPHA if _disabled_left > 0.0 else 1.0
	_time += delta
	if spec.kind == CRUMBLE:
		_advance_crumble(delta)
	_apply_pose()
	_hurt_overlapping()
	if spec.kind != SPIKES:
		queue_redraw()


func _physics_process(delta: float) -> void:
	advance(delta)


func is_dangerous() -> bool:
	return is_dangerous_at(_time)


## Danger à un instant de l'horloge (anticipation par l'autopilote).
func is_dangerous_at(t: float) -> bool:
	if _disabled_left > 0.0 and t - _time < _disabled_left:
		return false
	match spec.kind:
		SPIKES, SAW:
			return true
		CRUSHER:
			var tau: float = _cycle_time(t)
			var ph: PackedFloat32Array = _crusher_phases()
			return tau >= ph[1] and tau < ph[3]
		FLAME:
			return _flame_lit_at(t)
	return false


## Annonce visible avant le danger (écraseur qui tremble, flamme qui crépite).
func is_telegraphing() -> bool:
	match spec.kind:
		CRUSHER:
			var tau: float = _cycle_time(_time)
			var ph: PackedFloat32Array = _crusher_phases()
			return tau >= ph[0] and tau < ph[1]
		FLAME:
			return _flame_telegraph_progress(_time) >= 0.0
		CRUMBLE:
			return _crumble_state == CrumbleState.SHAKING
	return false


## Zone mortelle courante (coordonnées locales du piège) ; vide quand inoffensif.
func danger_rect() -> Rect2:
	return danger_rect_at(_time)


## Zone mortelle à un instant de l'horloge (anticipation par l'autopilote).
func danger_rect_at(t: float) -> Rect2:
	if not is_dangerous_at(t):
		return Rect2()
	match spec.kind:
		SPIKES:
			return _spike_hit_rect()
		SAW:
			var radius: float = _saw_radius() * SAW_HIT_RATIO
			return Rect2(_saw_center(t) - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		CRUSHER:
			var lethal: Rect2 = _crusher_lethal_local()
			lethal.position += spec.rect.position + _crusher_offset(t)
			return lethal
		FLAME:
			return _flame_hit_rect()
	return Rect2()


## Décalage courant du bloc de l'écraseur par rapport à sa position haute.
func crusher_offset() -> Vector2:
	return _crusher_offset(_time)


## Plateforme fragile : vrai tant qu'on peut s'y tenir (posée ou en train de trembler).
func is_solid() -> bool:
	return spec.kind == CRUMBLE and _crumble_state != CrumbleState.FALLEN


func crumble_state() -> CrumbleState:
	return _crumble_state


## Plateforme fragile : déclenche l'effondrement (appelé quand un coureur s'y pose).
func trigger() -> void:
	if spec.kind == CRUMBLE and _crumble_state == CrumbleState.SOLID:
		_set_crumble_state(CrumbleState.SHAKING)


# --- Construction --------------------------------------------------------------

func _build() -> void:
	match spec.kind:
		SPIKES:
			_area = _make_area(self)
			_hit_shape = _add_rect_shape(_area, _spike_hit_rect())
		SAW:
			_area = _make_area(self)
			var circle: CircleShape2D = CircleShape2D.new()
			circle.radius = _saw_radius() * SAW_HIT_RATIO
			_hit_shape = CollisionShape2D.new()
			_hit_shape.shape = circle
			_area.add_child(_hit_shape)
		CRUSHER:
			_crusher_body = AnimatableBody2D.new()
			_crusher_body.sync_to_physics = true
			_crusher_body.collision_layer = CollisionLayers.WORLD
			_crusher_body.collision_mask = 0
			_add_rect_shape(_crusher_body, Rect2(Vector2.ZERO, spec.rect.size))
			add_child(_crusher_body)
			_area = _make_area(_crusher_body)
			_hit_shape = _add_rect_shape(_area, _crusher_lethal_local())
		FLAME:
			_area = _make_area(self)
			_hit_shape = _add_rect_shape(_area, _flame_hit_rect())
		CRUMBLE:
			var platform: StaticBody2D = StaticBody2D.new()
			platform.collision_layer = CollisionLayers.WORLD
			platform.collision_mask = 0
			_platform_shape = _add_rect_shape(platform, spec.rect)
			add_child(platform)
			# Capteur : le dessus (pour « posé dessus ») et le volume (pour ne pas
			# réapparaître dans un coureur).
			_sensor = Area2D.new()
			_sensor.collision_layer = 0
			_sensor.collision_mask = CollisionLayers.PLAYER
			_sensor.monitorable = false
			_add_rect_shape(_sensor, spec.rect.grow_side(SIDE_TOP, 6.0))
			add_child(_sensor)


func _make_area(parent: Node) -> Area2D:
	var area: Area2D = Area2D.new()
	area.collision_layer = CollisionLayers.HAZARD
	area.collision_mask = CollisionLayers.PLAYER
	parent.add_child(area)
	return area


func _add_rect_shape(parent: Node, rect: Rect2) -> CollisionShape2D:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	parent.add_child(collision)
	return collision


# --- Cycle ---------------------------------------------------------------------

func _period() -> float:
	match spec.kind:
		CRUSHER:
			return spec.period if spec.period > 0.0 else CRUSHER_DEFAULT_PERIOD
		SAW:
			if spec.period <= 0.0 and spec.path_to != Vector2.ZERO:
				return SAW_DEFAULT_PERIOD
	return spec.period


## Secondes écoulées dans le cycle (décalage `phase` compris).
func _cycle_time(t: float) -> float:
	var p: float = _period()
	if p <= 0.0:
		return 0.0
	return fposmod(t + spec.phase * p, p)


func _apply_pose() -> void:
	match spec.kind:
		SAW:
			_hit_shape.position = _saw_center(_time)
		CRUSHER:
			_crusher_body.position = spec.rect.position + _crusher_offset(_time)


func _hurt_overlapping() -> void:
	if _area == null or not _area.is_inside_tree() or not is_dangerous():
		return
	for body: Node2D in _area.get_overlapping_bodies():
		if body is RunnerBody:
			(body as RunnerBody).kill(spec.kind)


# --- Pics ----------------------------------------------------------------------

func _spike_hit_rect() -> Rect2:
	return spec.rect.grow_individual(-SPIKE_MARGIN_X, -SPIKE_MARGIN_TOP, -SPIKE_MARGIN_X, 0.0)


# --- Scie ----------------------------------------------------------------------

func _saw_radius() -> float:
	return minf(spec.rect.size.x, spec.rect.size.y) * 0.5


## Centre de la scie : va-et-vient adouci (cosinus), départ en rect.position.
func _saw_center(t: float) -> Vector2:
	var start: Vector2 = spec.rect.get_center()
	var p: float = _period()
	if spec.path_to == Vector2.ZERO or p <= 0.0:
		return start
	var s: float = 0.5 - 0.5 * cos(TAU * _cycle_time(t) / p)
	return start + spec.path_to * s


# --- Écraseur --------------------------------------------------------------------

## Bornes des phases dans le cycle : [fin du repos, fin du tremblement, fin de la
## chute, fin de l'attente en bas, période]. La remontée occupe le reste.
func _crusher_phases() -> PackedFloat32Array:
	var p: float = _period()
	var active: float = clampf(spec.active_ratio, 0.05, 0.9) * p
	var drop: float = minf(CRUSHER_DROP, active * 0.5)
	var rest: float = p - active
	var shake: float = minf(CRUSHER_SHAKE, rest * 0.4)
	var rise: float = (rest - shake) * 0.6
	var idle: float = rest - shake - rise
	return PackedFloat32Array([idle, idle + shake, idle + shake + drop, idle + shake + active, p])


func _crusher_offset(t: float) -> Vector2:
	var tau: float = _cycle_time(t)
	var ph: PackedFloat32Array = _crusher_phases()
	if tau < ph[1]:
		return Vector2.ZERO
	if tau < ph[2]:
		var k: float = (tau - ph[1]) / maxf(ph[2] - ph[1], 0.001)
		return spec.path_to * (k * k)
	if tau < ph[3]:
		return spec.path_to
	var rise: float = (tau - ph[3]) / maxf(ph[4] - ph[3], 0.001)
	return spec.path_to * (1.0 - smoothstep(0.0, 1.0, rise))


## Partie mortelle du bloc (repère du bloc) : le bas, sans les flancs, plus une lèvre
## sous le bloc pour toucher le coureur dès le contact. Se tenir dessus est sans danger.
func _crusher_lethal_local() -> Rect2:
	var size: Vector2 = spec.rect.size
	var top: float = size.y * 0.4
	return Rect2(CRUSHER_MARGIN, top, maxf(size.x - 2.0 * CRUSHER_MARGIN, 2.0),
			size.y - top + CRUSHER_LIP)


# --- Flamme --------------------------------------------------------------------

## Durée éteinte au début de chaque cycle (l'allumage vient en fin de cycle).
func _flame_off_length() -> float:
	return (1.0 - clampf(spec.active_ratio, 0.0, 1.0)) * _period()


func _flame_lit_at(t: float) -> bool:
	if _period() <= 0.0 or spec.active_ratio >= 1.0:
		return true
	return _cycle_time(t) >= _flame_off_length()


## Avancement (0..1) de l'annonce avant allumage ; -1 hors annonce.
func _flame_telegraph_progress(t: float) -> float:
	if _flame_lit_at(t):
		return -1.0
	var off: float = _flame_off_length()
	var warn: float = minf(FLAME_TELEGRAPH, off * 0.6)
	var tau: float = _cycle_time(t)
	if tau < off - warn:
		return -1.0
	return (tau - (off - warn)) / maxf(warn, 0.001)


## Direction du jet, déduite du rectangle : plus haut que large = vertical, sinon
## horizontal. Le signe de path_to choisit le sens (y > 0 : du plafond vers le bas ;
## x < 0 : vers la gauche). Défaut : vers le haut (bouche au sol) ou vers la droite.
func _flame_direction() -> Vector2:
	if spec.rect.size.y >= spec.rect.size.x:
		return Vector2.DOWN if spec.path_to.y > 0.0 else Vector2.UP
	return Vector2.LEFT if spec.path_to.x < 0.0 else Vector2.RIGHT


## Zone de la flamme sans la buse, avec une marge sur les côtés.
func _flame_hit_rect() -> Rect2:
	var dir: Vector2 = _flame_direction()
	var r: Rect2 = spec.rect
	if dir == Vector2.UP:
		return r.grow_individual(-FLAME_MARGIN, 0.0, -FLAME_MARGIN, -FLAME_NOZZLE)
	if dir == Vector2.DOWN:
		return r.grow_individual(-FLAME_MARGIN, -FLAME_NOZZLE, -FLAME_MARGIN, 0.0)
	if dir == Vector2.RIGHT:
		return r.grow_individual(-FLAME_NOZZLE, -FLAME_MARGIN, 0.0, -FLAME_MARGIN)
	return r.grow_individual(0.0, -FLAME_MARGIN, -FLAME_NOZZLE, -FLAME_MARGIN)


# --- Plateforme fragile ----------------------------------------------------------

func _advance_crumble(delta: float) -> void:
	_crumble_time += delta
	match _crumble_state:
		CrumbleState.SOLID:
			if _runner_standing():
				trigger()
		CrumbleState.SHAKING:
			if _crumble_time >= CRUMBLE_DELAY:
				_set_crumble_state(CrumbleState.FALLEN)
		CrumbleState.FALLEN:
			if _crumble_time >= CRUMBLE_RESPAWN and not _runner_inside():
				_set_crumble_state(CrumbleState.SOLID)


func _set_crumble_state(state: CrumbleState) -> void:
	_crumble_state = state
	_crumble_time = 0.0
	if _platform_shape != null:
		_platform_shape.set_deferred(&"disabled", state == CrumbleState.FALLEN)
	queue_redraw()


func _runner_standing() -> bool:
	if _sensor == null or not _sensor.is_inside_tree():
		return false
	for body: Node2D in _sensor.get_overlapping_bodies():
		if body is RunnerBody:
			var runner: RunnerBody = body as RunnerBody
			var feet: Vector2 = to_local(runner.global_position)
			if runner.is_on_floor() and feet.y <= spec.rect.position.y + 3.0:
				return true
	return false


func _runner_inside() -> bool:
	if _sensor == null or not _sensor.is_inside_tree():
		return false
	for body: Node2D in _sensor.get_overlapping_bodies():
		if body is RunnerBody:
			return true
	return false


# --- Dessin --------------------------------------------------------------------

func _draw() -> void:
	match spec.kind:
		SPIKES:
			_draw_spikes()
		SAW:
			_draw_saw()
		CRUSHER:
			_draw_crusher()
		FLAME:
			_draw_flame()
		CRUMBLE:
			_draw_crumble()


## Pseudo-aléa déterministe (0..1) pour les détails (étincelles, éclats).
static func _hash01(n: float) -> float:
	return fposmod(sin(n * 12.9898 + 78.233) * 43758.5453, 1.0)


## Rangée de pointes dans `area` ; down = pointes vers le bas.
func _draw_teeth(area: Rect2, pitch: float, down: bool, alpha: float) -> void:
	var count: int = maxi(1, roundi(area.size.x / pitch))
	var step: float = area.size.x / float(count)
	var ink_a: Color = Color(ink, alpha)
	var glint: Color = Color(accent, alpha)
	var base_y: float = area.position.y if down else area.end.y
	var tip_y: float = area.end.y if down else area.position.y
	for i: int in count:
		var left: float = area.position.x + step * i
		var tip: Vector2 = Vector2(left + step * 0.5, tip_y)
		draw_colored_polygon(PackedVector2Array([
			Vector2(left, base_y), Vector2(left + step, base_y), tip]), ink_a)
		# Face gauche à peine éclairée (métal), puis arête chaude près de la pointe :
		# les pics restent lisibles même posés sur un toit noir.
		draw_colored_polygon(PackedVector2Array([
			tip, Vector2(left + 1.0, base_y), Vector2(tip.x, base_y)]), Color(ink.lerp(accent, 0.16), alpha))
		var edge: Vector2 = tip.lerp(Vector2(left, base_y), 0.5)
		draw_line(tip, edge, glint, 1.5)


func _draw_spikes() -> void:
	var r: Rect2 = spec.rect
	var base_h: float = clampf(r.size.y * 0.2, 2.0, 5.0)
	draw_rect(Rect2(r.position.x, r.end.y - base_h, r.size.x, base_h), ink)
	_draw_teeth(Rect2(r.position, Vector2(r.size.x, r.size.y - base_h + 0.5)), SPIKE_PITCH, false, 1.0)


func _draw_saw() -> void:
	var radius: float = _saw_radius()
	var start: Vector2 = spec.rect.get_center()
	if spec.path_to != Vector2.ZERO:
		# Rail : annonce le trajet complet de la scie.
		var finish: Vector2 = start + spec.path_to
		draw_line(start, finish, ink, 6.0)
		draw_line(start, finish, ink.lerp(accent, 0.35), 2.0)
		for end_point: Vector2 in [start, finish]:
			draw_circle(end_point, 7.0, ink)
			draw_circle(end_point, 2.5, accent)
	var c: Vector2 = _saw_center(_time)
	var angle: float = _time * SAW_SPIN
	var teeth: int = clampi(int(radius * 0.6), 10, 28)
	var step: float = TAU / float(teeth)
	var outline: PackedVector2Array = PackedVector2Array()
	for k: int in teeth:
		var a: float = angle + step * k
		outline.append(c + Vector2.from_angle(a) * radius * 0.80)
		outline.append(c + Vector2.from_angle(a + step * 0.62) * radius)
		outline.append(c + Vector2.from_angle(a + step * 0.70) * radius * 0.84)
	draw_colored_polygon(outline, ink)
	# Arête de coupe de chaque dent.
	for k: int in teeth:
		var a: float = angle + step * k
		draw_line(c + Vector2.from_angle(a + step * 0.62) * radius,
				c + Vector2.from_angle(a + step * 0.70) * radius * 0.84, accent, 1.5)
	draw_arc(c, radius * 0.62, 0.0, TAU, 32, Color(accent, 0.35), 1.5)
	# Traînées de rotation.
	draw_arc(c, radius * 0.44, angle, angle + 1.5, 12, Color(accent, 0.75), 2.0)
	draw_arc(c, radius * 0.44, angle + PI, angle + PI + 1.5, 12, Color(accent, 0.75), 2.0)
	draw_circle(c, radius * 0.17, accent)
	draw_circle(c, radius * 0.08, ink)


func _draw_crusher() -> void:
	var tau: float = _cycle_time(_time)
	var ph: PackedFloat32Array = _crusher_phases()
	var shaking: bool = tau >= ph[0] and tau < ph[1]
	var falling: bool = tau >= ph[1] and tau < ph[2]
	var down: bool = tau >= ph[2] and tau < ph[3]
	var jitter: Vector2 = Vector2.ZERO
	if shaking:
		var k: float = (tau - ph[0]) / maxf(ph[1] - ph[0], 0.001)
		jitter = Vector2(sin(_time * 95.0) * (1.0 + 2.0 * k), -absf(cos(_time * 70.0)) * 1.5 * k)
	var block: Rect2 = Rect2(spec.rect.position + _crusher_offset(_time) + jitter, spec.rect.size)
	var cx: float = block.get_center().x
	# Vérin : ancrage fixe, la tige s'allonge pendant la chute.
	var anchor_y: float = spec.rect.position.y - CRUSHER_ROD
	var rod_w: float = clampf(block.size.x * 0.18, 8.0, 16.0)
	draw_rect(Rect2(cx - rod_w * 1.4, anchor_y - 8.0, rod_w * 2.8, 10.0), ink)
	draw_rect(Rect2(cx - rod_w * 0.5, anchor_y, rod_w, block.position.y - anchor_y + 1.0), ink)
	draw_rect(Rect2(cx - rod_w * 0.5 + 2.0, anchor_y + 2.0, 1.5, maxf(block.position.y - anchor_y - 2.0, 0.0)),
			Color(accent, 0.45))
	# Corps lourd.
	var body: Rect2 = Rect2(block.position, Vector2(block.size.x, block.size.y - CRUSHER_TEETH))
	draw_rect(body, ink)
	if shaking and sin(_time * 45.0) > -0.2:
		# Annonce : le contour du bloc s'allume en même temps que le voyant.
		draw_rect(body.grow(-1.0), Color(accent, 0.9), false, 2.0)
	# Bande de danger hachurée au-dessus des dents.
	var band: Rect2 = Rect2(body.position.x + 3.0, body.end.y - 11.0, body.size.x - 6.0, 7.0)
	if band.size.x > 4.0 and body.size.y > 22.0:
		draw_rect(band, accent)
		var band_poly: PackedVector2Array = PackedVector2Array([band.position,
				Vector2(band.end.x, band.position.y), band.end, Vector2(band.position.x, band.end.y)])
		var x: float = band.position.x - band.size.y
		while x < band.end.x:
			var stripe: PackedVector2Array = PackedVector2Array([
				Vector2(x, band.end.y), Vector2(x + 5.0, band.end.y),
				Vector2(x + 5.0 + band.size.y, band.position.y), Vector2(x + band.size.y, band.position.y)])
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(stripe, band_poly):
				draw_colored_polygon(piece, ink)
			x += 10.0
	# Rivets.
	for corner: Vector2 in [body.position + Vector2(6, 6), Vector2(body.end.x - 6.0, body.position.y + 6.0)]:
		draw_circle(corner, 2.0, Color(accent, 0.5))
	# Voyant : éteint au repos, clignote pendant l'annonce, rouge-orangé pendant le coup.
	var light: Vector2 = Vector2(cx, body.position.y + minf(12.0, body.size.y * 0.3))
	var lamp_on: bool = falling or down or (shaking and sin(_time * 45.0) > -0.2)
	if lamp_on:
		draw_circle(light, 10.0, Color(accent, 0.28))
		draw_circle(light, 4.5, accent)
	else:
		draw_circle(light, 4.5, accent.darkened(0.6))
	_draw_teeth(Rect2(body.position.x, body.end.y - 0.5, body.size.x, CRUSHER_TEETH + 0.5), 14.0, true, 1.0)
	var dust: Color = ink.lightened(0.55)
	if shaking:
		# Gravats qui tombent de l'ancrage : on voit que ça va lâcher.
		for i: int in 4:
			var fall: float = fposmod(_time * 2.2 + _hash01(float(i)), 1.0)
			var dx: float = (_hash01(float(i) + 3.0) - 0.5) * block.size.x * 0.8
			draw_rect(Rect2(cx + dx, anchor_y + 4.0 + fall * 26.0, 2.0, 2.0), Color(dust, 1.0 - fall))
	if falling:
		# Traits de vitesse au-dessus du bloc.
		for i: int in 3:
			var lx: float = block.position.x + block.size.x * (0.2 + 0.3 * i)
			draw_line(Vector2(lx, block.position.y - 4.0), Vector2(lx, block.position.y - 26.0), Color(accent, 0.5), 2.0)
	if down and tau - ph[2] < 0.3:
		# Poussière d'impact.
		var k2: float = (tau - ph[2]) / 0.3
		for side: float in [-1.0, 1.0]:
			var origin: Vector2 = Vector2(block.get_center().x + side * (block.size.x * 0.5 + 4.0 + 18.0 * k2),
					block.end.y - 6.0 - 6.0 * k2)
			draw_circle(origin, 5.0 + 7.0 * k2, Color(dust, 0.75 * (1.0 - k2)))
			draw_circle(origin + Vector2(side * 10.0, 3.0), 3.0 + 5.0 * k2, Color(dust, 0.6 * (1.0 - k2)))


func _draw_flame() -> void:
	var dir: Vector2 = _flame_direction()
	var r: Rect2 = spec.rect
	var base: Vector2
	var length: float
	var width: float
	if dir == Vector2.UP or dir == Vector2.DOWN:
		base = Vector2(r.get_center().x, r.end.y if dir == Vector2.UP else r.position.y)
		length = r.size.y
		width = r.size.x
	else:
		base = Vector2(r.position.x if dir == Vector2.RIGHT else r.end.x, r.get_center().y)
		length = r.size.x
		width = r.size.y
	# Repère local : la flamme monte toujours vers -y.
	draw_set_transform(base, Vector2.UP.angle_to(dir), Vector2.ONE)
	var lit: bool = _flame_lit_at(_time)
	var warn: float = _flame_telegraph_progress(_time)
	var tau: float = _cycle_time(_time)
	var off: float = _flame_off_length()
	var flame_len: float = length - FLAME_NOZZLE
	if lit:
		var grow: float = 1.0
		if _period() > 0.0 and spec.active_ratio < 1.0:
			grow = clampf((tau - off) / FLAME_GROW, 0.3, 1.0)
		_draw_fire(flame_len * grow, width, 1.0)
	elif _period() > 0.0 and tau < 0.1:
		# Extinction : la flamme retombe (déjà inoffensive).
		_draw_fire(flame_len * (1.0 - tau / 0.1) * 0.6, width * 0.7, 0.55)
	if warn >= 0.0:
		_draw_flame_warning(flame_len, width, warn)
	_draw_nozzle(width, lit, warn)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Flamme allumée : trois couches ondulantes (rouge, orange, cœur clair) et des langues.
func _draw_fire(flame_len: float, width: float, alpha: float) -> void:
	if flame_len < 2.0:
		return
	var layers: Array[Array] = [
		[FLAME_OUTER, 0.5, 1.0, 0.0],
		[FLAME_MID.lerp(accent, 0.35), 0.34, 0.80, 1.7],
		[FLAME_CORE, 0.17, 0.50, 3.1],
	]
	for layer: Array in layers:
		var color: Color = layer[0]
		draw_colored_polygon(_flame_outline(flame_len * float(layer[2]), width * float(layer[1]), float(layer[3])),
				Color(color, alpha))
	# Langues détachées qui s'envolent au sommet.
	for j: int in 3:
		var ph: float = fposmod(_time * 2.8 + float(j) / 3.0, 1.0)
		var y: float = -FLAME_NOZZLE - flame_len * (0.72 + 0.32 * ph)
		var x: float = sin(float(j) * 2.1 + _time * 5.0) * width * 0.18
		var s: float = (1.0 - ph) * width * 0.11 + 1.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - s * 1.6), Vector2(x + s, y),
				Vector2(x, y + s), Vector2(x - s, y)]), Color(FLAME_MID, alpha * (1.0 - ph)))


## Contour d'une couche de flamme : large près de la base, pointe qui ondule.
func _flame_outline(flame_len: float, half_width: float, seed_value: float) -> PackedVector2Array:
	const STEPS: int = 9
	var flicker: float = 0.92 + 0.08 * sin(_time * 23.0 + seed_value)
	var total: float = flame_len * flicker
	var right: PackedVector2Array = PackedVector2Array()
	var left: PackedVector2Array = PackedVector2Array()
	for i: int in STEPS + 1:
		var s: float = float(i) / float(STEPS)
		var y: float = -FLAME_NOZZLE - s * total
		var profile: float = pow(maxf(sin(PI * (0.35 + 0.65 * s)), 0.0), 0.9)
		var hw: float = half_width * profile
		var sway: float = sin(_time * 17.0 + s * 6.0 + seed_value) * half_width * 0.22 * s
		if i == STEPS:
			right.append(Vector2(sway, y))
		else:
			right.append(Vector2(hw + sway, y))
			left.append(Vector2(-hw + sway * 0.8, y))
	left.reverse()
	right.append_array(left)
	return right


## Annonce : petites flammèches et étincelles qui montent de la buse.
func _draw_flame_warning(flame_len: float, width: float, progress: float) -> void:
	if sin(_time * 60.0) > -0.4:
		var lick: float = flame_len * (0.08 + 0.12 * progress)
		draw_colored_polygon(_flame_outline(lick, width * 0.2, 5.0), Color(FLAME_MID, 0.9))
	for j: int in 6:
		var ph: float = fposmod(_time * 1.9 + _hash01(float(j)), 1.0)
		var x: float = (_hash01(float(j) + 7.0) - 0.5) * width * 0.7 + sin(_time * 9.0 + float(j)) * 2.0
		var y: float = -FLAME_NOZZLE - ph * flame_len * (0.25 + 0.3 * progress)
		draw_rect(Rect2(x - 1.0, y - 1.0, 2.5, 2.5), Color(FLAME_CORE.lerp(FLAME_MID, ph), 1.0 - ph))


func _draw_nozzle(width: float, lit: bool, warn: float) -> void:
	var nw: float = clampf(width * 0.55, 16.0, 34.0)
	var half: float = nw * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(-half - 3.0, 0.0), Vector2(half + 3.0, 0.0),
			Vector2(half, -FLAME_NOZZLE + 3.0), Vector2(-half, -FLAME_NOZZLE + 3.0)]), ink)
	draw_rect(Rect2(-half - 2.0, -FLAME_NOZZLE, nw + 4.0, 4.0), ink)
	var slot: Color = EMBER
	if lit:
		slot = FLAME_CORE
	elif warn >= 0.0:
		slot = EMBER.lerp(FLAME_MID, 0.5 + 0.5 * sin(_time * 50.0) * (1.0 - warn) + warn * 0.5)
		draw_circle(Vector2(0.0, -FLAME_NOZZLE), half + 4.0, Color(FLAME_MID, 0.18 + 0.22 * warn))
	draw_rect(Rect2(-half + 3.0, -FLAME_NOZZLE + 0.5, nw - 6.0, 2.0), slot)
	# Bandes de la buse.
	draw_rect(Rect2(-half + 1.0, -FLAME_NOZZLE + 6.0, nw - 2.0, 1.0), Color(accent, 0.35))


func _draw_crumble() -> void:
	var r: Rect2 = spec.rect
	match _crumble_state:
		CrumbleState.SOLID:
			_draw_slab(r.position, clampf(_crumble_time / CRUMBLE_FADE_IN, 0.0, 1.0), 0.0)
		CrumbleState.SHAKING:
			var k: float = _crumble_time / CRUMBLE_DELAY
			var jitter: Vector2 = Vector2(sin(_time * 70.0) * (0.8 + 1.4 * k), absf(sin(_time * 53.0)) * k)
			_draw_slab(r.position + jitter, 1.0, k)
			var dust: Color = ink.lightened(0.55)
			for i: int in 5:
				var fall: float = fposmod(_time * 2.5 + _hash01(float(i)), 1.0)
				var x: float = r.position.x + _hash01(float(i) + 11.0) * r.size.x
				draw_rect(Rect2(x, r.end.y + fall * 30.0, 2.0, 2.0), Color(dust, 1.0 - fall))
		CrumbleState.FALLEN:
			if _crumble_time < CRUMBLE_FALL_ANIM:
				var k: float = _crumble_time / CRUMBLE_FALL_ANIM
				var third: float = r.size.x / 3.0
				for i: int in 3:
					var drop: float = 0.5 * 1100.0 * _crumble_time * _crumble_time * (1.0 + 0.2 * i)
					var spin: float = (float(i) - 1.0) * 0.5 * k + 0.08 * k
					var center: Vector2 = r.position + Vector2(third * (i + 0.5), r.size.y * 0.5 + drop)
					draw_set_transform(center, spin, Vector2.ONE)
					draw_rect(Rect2(-third * 0.5 + 1.0, -r.size.y * 0.5, third - 2.0, r.size.y),
							Color(ink, 1.0 - k))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# Fantôme en pointillés : la plateforme reviendra (il clignote juste avant).
			var ghost: float = 0.3
			if _crumble_time > CRUMBLE_RESPAWN - 0.5 and sin(_time * 30.0) > 0.0:
				ghost = 0.7
			_draw_dashed_rect(r, Color(ink, ghost))


## Dalle fissurée : dessus plein et plat (appui lisible), dessous déchiqueté.
func _draw_slab(origin: Vector2, alpha: float, heat: float) -> void:
	var size: Vector2 = spec.rect.size
	var flat: float = maxf(size.y - 5.0, size.y * 0.6)
	var points: PackedVector2Array = PackedVector2Array([origin, origin + Vector2(size.x, 0.0),
			origin + Vector2(size.x, flat)])
	var count: int = maxi(2, int(size.x / 9.0))
	for i: int in range(count - 1, 0, -1):
		var x: float = size.x * float(i) / float(count)
		var depth: float = (size.y - flat) * (0.3 + 0.7 * _hash01(float(i) + size.x))
		points.append(origin + Vector2(x, flat + depth))
	points.append(origin + Vector2(0.0, flat))
	draw_colored_polygon(points, Color(ink, alpha))
	var crack: Color = accent.darkened(0.45).lerp(accent, heat)
	crack.a = (0.85 + 0.15 * heat) * alpha
	for fx: float in [0.22, 0.55, 0.83]:
		var x0: float = origin.x + size.x * fx
		draw_polyline(PackedVector2Array([
			Vector2(x0, origin.y + 1.5),
			Vector2(x0 + 4.0, origin.y + size.y * 0.4),
			Vector2(x0 - 2.0, origin.y + size.y * 0.65),
			Vector2(x0 + 2.0, origin.y + flat)]), crack, 1.5)
	# Liseré clair sur l'arête : on repère une plateforme fragile de loin.
	draw_line(origin + Vector2(1.0, 1.0), origin + Vector2(size.x - 1.0, 1.0), Color(crack, crack.a * 0.6), 1.0)


func _draw_dashed_rect(r: Rect2, color: Color) -> void:
	var corners: PackedVector2Array = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y), r.position])
	for i: int in 4:
		draw_dashed_line(corners[i], corners[i + 1], color, 1.5, 6.0)
