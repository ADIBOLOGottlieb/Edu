class_name BloodBurst
extends Node2D
## Éclaboussure de sang à la mort par un piège (ADR-052) : une gerbe de gouttes
## (CPUParticles2D, léger sur mobile) et une tache au sol qui s'estompe, puis
## l'effet se libère seul. Intensité selon le piège (scie et écraseur plus forts).
## Désactivable dans les Réglages (« Effets de sang »). Pas de sang à la capture.

const BLOOD_DARK: Color = Color(0.38, 0.02, 0.03)
const BLOOD: Color = Color(0.62, 0.04, 0.05)
## Durée de vie de l'effet (s), tache comprise.
const LIFETIME: float = 3.2
const STAIN_FADE: float = 1.2

## Intensité par cause (nombre de gouttes, vitesse).
const STRENGTH: Dictionary[StringName, Vector2] = {
	&"spikes": Vector2(36.0, 260.0),
	&"saw": Vector2(60.0, 420.0),
	&"crusher": Vector2(70.0, 360.0),
	&"flame": Vector2(18.0, 180.0),
}

var cause: StringName = &"spikes"
## Côté vers lequel part la gerbe (-1 gauche, 1 droite).
var direction: float = 1.0

var _age: float = 0.0
var _stain: PackedVector2Array = PackedVector2Array()
var _stain_sizes: PackedFloat32Array = PackedFloat32Array()


## Effet à `at` (monde), ajouté sous `parent`. Retourne null si la cause n'en a pas.
static func spawn(parent: Node, at: Vector2, death_cause: StringName, facing: int) -> BloodBurst:
	if not STRENGTH.has(death_cause) or parent == null:
		return null
	var burst: BloodBurst = BloodBurst.new()
	burst.cause = death_cause
	burst.direction = -float(facing) if facing != 0 else 1.0
	burst.position = at
	parent.add_child(burst)
	return burst


func _ready() -> void:
	z_index = 5
	var strength: Vector2 = STRENGTH.get(cause, Vector2(36.0, 260.0))
	var drops: CPUParticles2D = CPUParticles2D.new()
	drops.name = "Drops"
	drops.one_shot = true
	drops.explosiveness = 0.92
	drops.amount = int(strength.x)
	drops.lifetime = 0.9
	drops.position = Vector2(0.0, -40.0)
	drops.direction = Vector2(direction * 0.6, -1.0)
	drops.spread = 70.0
	drops.initial_velocity_min = strength.y * 0.45
	drops.initial_velocity_max = strength.y
	drops.gravity = Vector2(0.0, 1400.0)
	drops.scale_amount_min = 2.0
	drops.scale_amount_max = 5.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, BLOOD)
	ramp.set_color(1, Color(BLOOD_DARK, 0.0))
	drops.color_ramp = ramp
	add_child(drops)
	drops.emitting = true
	# Tache au sol : quelques disques irréguliers, dessinés une fois.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([int(position.x), int(position.y)])
	for i: int in int(strength.x / 6.0) + 4:
		_stain.append(Vector2(rng.randf_range(-34.0, 34.0) + direction * 14.0, rng.randf_range(-2.0, 1.0)))
		_stain_sizes.append(rng.randf_range(2.5, 7.5))
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	if _age > LIFETIME - STAIN_FADE:
		modulate.a = clampf((LIFETIME - _age) / STAIN_FADE, 0.0, 1.0)


func _draw() -> void:
	for i: int in _stain.size():
		draw_circle(_stain[i], _stain_sizes[i], BLOOD_DARK)
