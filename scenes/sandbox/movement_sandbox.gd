extends Node2D
## Bac à sable des jalons M1-M2 : obstacle bas, tunnel bas (glissade obligatoire),
## plateformes (réception dure), fosse (rebord), mur escaladable, mur trop haut.
## La géométrie est décrite par des rectangles pour rester lisible et modifiable.

## Rectangles de collision du niveau : position = coin haut-gauche, y = 0 = sol.
const BLOCKS: Array[Rect2] = [
	Rect2(-440, -600, 40, 800),  # mur de gauche
	Rect2(-400, 0, 2500, 200),  # sol, partie 1
	Rect2(500, -40, 120, 40),  # obstacle bas : franchissement automatique
	Rect2(900, -400, 360, 352),  # plafond du tunnel : 48 px de hauteur libre
	Rect2(1560, -110, 140, 16),  # plateforme basse
	Rect2(1780, -230, 160, 16),  # plateforme haute : chute ≈ 230 px → réception dure
	Rect2(2100, 100, 160, 100),  # fond de la fosse (100 px de profondeur)
	Rect2(2260, 0, 2000, 200),  # sol, partie 2
	Rect2(2700, -260, 80, 260),  # mur : course murale → escalade → rebord ; chute dure de l'autre côté
	Rect2(4000, -900, 60, 900),  # mur trop haut : l'escalade s'épuise
]

@onready var _player: RunnerBody = $Player
@onready var _overlay: MovementDebugOverlay = $DebugOverlay


func _ready() -> void:
	add_child(CityBackdrop.new())
	for rect: Rect2 in BLOCKS:
		add_child(LevelGeometry.make_block(rect))
	_overlay.body = _player
	var profile: ProfileServiceNode = get_node_or_null(^"/root/ProfileService") as ProfileServiceNode
	if profile != null:
		_player.abilities = profile.abilities
	_attach_camera()


## F4 : débloque / verrouille le double saut (test de la capacité).
func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F4:
		if not _player.abilities.unlock(AbilitySet.DOUBLE_JUMP):
			_player.abilities.lock(AbilitySet.DOUBLE_JUMP)


func _attach_camera() -> void:
	var camera: Camera2D = Camera2D.new()
	camera.position = Vector2(160, -120)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	_player.add_child(camera)
	camera.make_current()
