# Tests

## Installation de GUT (une fois)

GUT 9.7.1 est **déjà vendorisé** dans `addons/gut/` : rien à installer. Pour le mettre à jour, remplacer ce dossier par `addons/gut/` de l'archive source du tag voulu (<https://github.com/bitwes/Gut/releases>), puis noter le changement dans `DECISIONS.md`.

## Première ouverture (cache d'import)

GUT déclare des `class_name` (ex. `GutTest`) que Godot doit indexer avant de lancer les tests :

```
godot --headless --path . --import
```

## Lancer tous les tests

```
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

La configuration vient de `.gutconfig.json` : tous les fichiers `tests/**/test_*.gd`. Code de sortie 0 = tout est vert.

Un seul fichier :

```
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_input_actions.gd
```

## Organisation

| Dossier | Contenu | Règle |
|---|---|---|
| `tests/unit/` | logique pure, configuration | aucune attente sur la physique, rapide |
| `tests/integration/` | scènes instanciées, séquences d'entrées scriptées | à partir du jalon M1 |

## Tests actuels (M0)

| Fichier | Vérifie |
|---|---|
| `test_project_settings.gd` | nom, rendu Compatibility, résolution, 60 Hz, scène principale, 11 autoloads chargés |
| `test_input_actions.gd` | 12 actions présentes avec au moins une touche ; idempotence ; une liaison personnalisée n'est jamais écrasée ; action supprimée recréée |
| `test_boot_scene.gd` | la scène de démarrage s'instancie et affiche « EDU » |

## Tests du jalon M1 (mouvement de base)

| Fichier | Vérifie |
|---|---|
| `unit/test_player_state.gd` | 22 états déclarés, noms, priorités conformes à l'architecture |
| `unit/test_player_fsm.gd` | transition autorisée → 1 seul signal ; état identique ignoré ; transitions hors table refusées (y compris DoubleJump non débloqué et états des jalons futurs) ; priorité : une glissade ne s'interrompt pas tant qu'elle n'a pas fini ; tous les états M1 atteignables et sans impasse |
| `unit/test_movement_decider.gd` | course / sprint, zone morte, saut mémorisé, *coyote time*, apex → chute, réception douce / dure, glissade (vitesse mini, durée, plafond bas, annulation par saut, bord de plateforme), glissade mémorisée pendant une réception |
| `unit/test_locomotion_motor.gd` | accélérations et vitesses max, demi-tour instantané (course) / progressif (sprint), gravité et plafond de chute, saut à hauteur variable, pas de contrôle pendant la glissade, vitesse mini sous plafond, élan conservé en l'air |
| `unit/test_player_animations.gd` | un clip par état M1, repli `idle` pour les autres, ressource de réglages chargeable |
| `integration/test_runner_body.gd` | corps réel dans un monde physique : chute → **une seule** réception ; chute haute → réception dure ; saut → **un seul** `jump_started` et **un seul** `landed`, hauteur ≈ 144 px ; demi-tour ; sprint ; tunnel bas : glissade de bout en bout, forme debout désactivée sous le plafond, relevé à la sortie |

## Tests du jalon M2 (parkour avancé)

| Fichier | Vérifie |
|---|---|
| `unit/test_ability_set.gd` | rien de débloqué par défaut ; signaux seulement sur changement ; capacité inconnue refusée ; chargement qui ignore les entrées inconnues |
| `unit/test_parkour_rules.gd` | double saut : refusé si verrouillé, une fois, priorité au saut *coyote* ; franchissement : fenêtre de hauteur, vitesse, direction, priorité au saut, fin sans immobilisation, impulsion juste suffisante ; mur : vitesse mini, une course par phase aérienne, conversion de l'élan, escalade jusqu'à épuisement, lâcher, saut mural et verrouillage du contrôle ; rebord : saisie depuis chaque état aérien, jamais au sol, délai de reprise, durée mini, se hisser / lâcher, impulsion qui dépasse le rebord ; roulade : sur réception dure seulement, durée, plafond, vitesse ; toutes les décisions présentes dans la table |
| `integration/test_parkour.gd` | vrai corps et vraie géométrie : franchissement sans arrêt ; double saut refusé verrouillé ; double saut débloqué (2 signaux `ground` puis `double`, > 200 px, pas de 3ᵉ saut) ; course murale → rebord → hissé debout sur le mur ; suspension immobile puis lâcher sans reprise ; mur trop haut : une seule escalade puis chute ; roulade juste après une réception dure |

> Note : `wait_physics_frames(1)` de GUT peut laisser passer plus d'un tick de physique. Les tests d'intégration déclenchent donc leurs appuis d'après l'état du corps, jamais d'après un numéro de frame.

## Bac à sable (vérification manuelle)

```
godot --path . res://scenes/sandbox/movement_sandbox.tscn
```

ou bouton « Bac à sable : mouvement » sur l'écran de démarrage.

Parcours : obstacle bas (franchi automatiquement), tunnel bas (glisser obligatoirement), plateformes (redescendre de la haute = réception dure), fosse (rebord saisissable), mur de 260 px (course murale → escalade → rebord ; Glisse à la redescente = roulade), mur de 900 px en fin de parcours (l'escalade s'épuise). Le panneau en haut à gauche affiche l'état, la priorité, la durée, la vitesse et l'état du double saut (F3 masque le panneau, F4 débloque / verrouille le double saut).

Commandes tactiles sur PC : Projet → Paramètres → Input Devices → Pointing → *Emulate Touch From Mouse*, et `force_visible` sur le nœud `TouchControls`. Le multi-touch réel n'est vérifiable que sur un appareil Android.

## Captures automatiques

```
godot --path . -s tools/capture_sandbox.gd -- C:/chemin/absolu/vers/captures
```

Ouvre une fenêtre, joue le parcours avec un `ScriptedController` et enregistre une image par état (idle, run, sprint, slide, jump, fall, landing).

## Vérification manuelle (M0)

1. Ouvrir le projet dans Godot 4.7.2 : aucune erreur dans le panneau Sortie.
2. F5 : écran clair avec « EDU — version 0.0.1 — socle M0 ».
3. Projet → Paramètres → Autoload : 11 entrées dans l'ordre de `docs/ARCHITECTURE.md` §2.
