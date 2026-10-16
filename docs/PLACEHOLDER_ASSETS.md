# Assets provisoires à remplacer

Rien de cette liste n'est un asset final. Ce sont des formes simples dessinées par code, pour rendre le gameplay lisible pendant le développement.

## Personnage

| Élément | Implémentation actuelle | À produire |
|---|---|---|
| Silhouette du protagoniste | `RunnerVisual` : cercles et segments épais, noirs, dessinés par code ; membres arrière en gris foncé | sprites ou squelette 2D dessinés, silhouette « sweat + pantalon ample » (références fournies) |
| Poses des 7 états M1 (idle, run, sprint, jump, fall, landing, slide) | `data/animations/player_anims.tres` : angles et amplitudes procéduraux | animations dessinées image par image ou squelettales |
| 15 autres états (double_jump, roll, vault, wall_run, wall_climb, ledge_hang, dodge, attack, block, hit, stagger, escape, capture, death, victory) | aucun clip : affichent la pose `idle` (repli) | une animation chacun, au jalon où l'état est implémenté |

État des animations par état :

| État | Prototype | Animation finale |
|---|---|---|
| Idle, Run, Sprint, Jump, Fall, Landing, Slide | ✅ pose procédurale | ❌ |
| tous les autres | ❌ (repli idle) | ❌ |

## Interface

| Élément | Actuel | À produire |
|---|---|---|
| Boutons tactiles | disques semi-transparents + texte (`TouchControls.ButtonFace`) | icônes dessinées, retour visuel et haptique |
| Panneau de débogage | `Label` brut | (outil de dev, pas d'asset final) |
| Écran de démarrage | texte + bouton par défaut de Godot | menu principal (jalon M7) |

## Décor

| Élément | Actuel | À produire |
|---|---|---|
| Sol, plafonds, plateformes | `Polygon2D` noirs pleins | tuiles / chunks dessinés (jalon M3) |
| Skyline | rectangles gris générés (graine fixe), 1 plan de parallaxe | 3 à 4 plans de parallaxe originaux ; **ne pas** utiliser l'image pngtree fournie en référence (ADR-010) |

## Audio

Aucun son pour l'instant.
