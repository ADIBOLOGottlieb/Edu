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

## Bac à sable (vérification manuelle)

```
godot --path . res://scenes/sandbox/movement_sandbox.tscn
```

ou bouton « Bac à sable : mouvement » sur l'écran de démarrage.

Parcours : marche (sauter), tunnel bas (glisser obligatoirement), plateformes (redescendre de la haute = réception dure), fosse. Le panneau en haut à gauche affiche l'état, la priorité, la durée, la vitesse (F3 pour masquer).

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
