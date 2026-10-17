class_name EquipmentData
extends Resource
## Un équipement (docs/ARCHITECTURE.md §7.2), adapté au jeu sans combat (ADR-047) :
## chaque objet a un effet de parkour ou d'évasion réel, sans violence.

enum Category { DEFENSE, MELEE, RANGED, MOBILITY, STEALTH, TECH, UTILITY }
## REFRESH : même objet actif → chrono plein. REPLACE : même catégorie active →
## l'ancien expire, le nouveau démarre. REJECT : même catégorie active → refusé.
enum StackRule { REFRESH, REPLACE, REJECT }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.UTILITY
## Durée de l'effet (s, temps de jeu). Très courte pour un effet instantané.
@export var duration: float = 10.0
@export var stack_rule: StackRule = StackRule.REFRESH
## Objets dont l'effet actif empêche l'activation (et réciproquement).
@export var incompatible_with: Array[StringName] = []
## Charges consommées par l'effet (ex. bouclier : 2 prises) ; 0 = illimité pendant la durée.
@export var charges: int = 0
## Intensité de l'effet (multiplicateur de vitesse, part de jauge retirée…).
@export var power: float = 1.0
## Perdu après une défaite s'il a été ramassé pendant le parcours (ADR-005).
@export var lost_on_defeat: bool = true
## Forme de l'icône dessinée par code (&"vest", &"shield", &"bolt"…).
@export var icon: StringName = &""
