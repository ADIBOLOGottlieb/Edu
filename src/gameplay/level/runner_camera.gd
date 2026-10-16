class_name RunnerCamera
extends Camera2D
## Caméra de course : suit la cible avec une avance dans le sens du regard,
## lissée, et ne recule jamais de plus de max_backtrack derrière le point le
## plus avancé atteint (limit_left mobile).

@export var target: Node2D
## Décalage horizontal vers l'avant du coureur (px).
@export var look_ahead: float = 220.0
## Vitesse de bascule de l'avance quand le coureur se retourne (par seconde).
@export var look_ahead_speed: float = 3.0
## Décalage vertical : le coureur est affiché sous le centre de l'écran.
@export var vertical_offset: float = -120.0
## Recul maximal du centre de la caméra derrière le point le plus avancé (px).
@export var max_backtrack: float = 320.0

var _ahead: float = 0.0
var _furthest_x: float = -INF


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0
	if target != null:
		global_position = target.global_position + Vector2(0.0, vertical_offset)
		_furthest_x = target.global_position.x
	make_current()


## Centre minimal autorisé de la caméra (le recul est borné).
func min_center_x() -> float:
	return _furthest_x - max_backtrack


func _process(delta: float) -> void:
	if target == null:
		return
	var facing: float = 1.0
	var body: RunnerBody = target as RunnerBody
	if body != null:
		facing = float(body.facing)
	_ahead = lerpf(_ahead, look_ahead * facing, 1.0 - exp(-look_ahead_speed * delta))
	_furthest_x = maxf(_furthest_x, target.global_position.x)
	var desired: Vector2 = target.global_position + Vector2(_ahead, vertical_offset)
	desired.x = maxf(desired.x, min_center_x())
	global_position = desired
	var half_width: float = get_viewport_rect().size.x * 0.5 / zoom.x
	limit_left = int(min_center_x() - half_width)
