class_name CollisionLayers
extends RefCounted
## Couches de collision du jeu (valeurs de bits). Une seule source de vérité :
## pièges, pièces, ennemis et attaques s'y réfèrent par leur nom.

## Sol, murs, toits (LevelGeometry).
const WORLD: int = 1
## Corps du joueur (player.tscn).
const PLAYER: int = 2
## Zones mortelles des pièges (pics, scies, écraseurs, flammes) : détectent PLAYER.
const HAZARD: int = 4
## Corps des ennemis : détectés par l'attaque du joueur.
const ENEMY: int = 8
## Zone d'attaque du joueur (active seulement pendant les ticks « actifs »).
const PLAYER_ATTACK: int = 16
## Pièces à ramasser : détectent PLAYER.
const PICKUP: int = 32
## Projectiles ennemis : détectent PLAYER et WORLD.
const ENEMY_PROJECTILE: int = 64
