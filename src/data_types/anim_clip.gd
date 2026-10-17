class_name AnimClip
extends Resource
## Pose procédurale de la silhouette provisoire pour un état.
## PROVISOIRE : sera remplacé par des animations dessinées (docs/PLACEHOLDER_ASSETS.md).
## Angles en radians, positifs vers l'avant du personnage.

## Inclinaison du buste.
@export var lean: float = 0.0
## 0 = debout, 1 = complètement accroupi.
@export_range(0.0, 1.0) var crouch: float = 0.0
## Angle moyen des cuisses et des bras.
@export var leg_base: float = 0.0
@export var arm_base: float = 0.0
## Amplitude du cycle de foulée et du balancement des bras.
@export var stride: float = 0.0
@export var arm_swing: float = 0.0
## Flexion des genoux (0 à 1).
@export_range(0.0, 1.0) var knee_bend: float = 0.15
## Cycles par seconde à la vitesse de course (mis à l'échelle par la vitesse réelle).
@export var cycle_hz: float = 0.0
## Rotation du corps entier autour des hanches (radians, positif = vers l'avant) : saltos.
@export var rotation: float = 0.0
## Vrille autour de l'axe vertical (radians) : rendue par un écrasement horizontal.
@export var spin: float = 0.0
