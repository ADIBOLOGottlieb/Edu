# Assets provisoires à remplacer

Rien de cette liste n'est un asset final. Ce sont des formes simples dessinées par code, pour rendre le gameplay lisible pendant le développement.

## Personnage

| Élément | Implémentation actuelle | À produire |
|---|---|---|
| Silhouette du protagoniste | `RunnerVisual` + `SilhouetteStyle` : silhouette humaine dessinée par code (contours lissés, sweat ample, pantalon froissé, baskets, mains ouvertes), poses en données lissées par ressorts ; membres arrière en gris foncé | sprites ou squelette 2D dessinés, silhouette « sweat + pantalon ample » (références fournies) |
| Poses des 13 états M1 + M2 | `data/animations/player_anims.tres` : angles et amplitudes procéduraux | animations dessinées image par image ou squelettales |
| 9 autres états (dodge, attack, block, hit, stagger, escape, capture, death, victory) | aucun clip : affichent la pose `idle` (repli) | une animation chacun, au jalon où l'état est implémenté |

État des animations par état :

| État | Prototype | Animation finale |
|---|---|---|
| Idle, Run, Sprint, Jump, Fall, Landing, Slide | ✅ pose procédurale | ❌ |
| DoubleJump, Roll, Vault, WallRun, WallClimb, LedgeHang | ✅ pose procédurale (la roulade et la course murale restent peu lisibles : le squelette provisoire ne pivote pas le corps entier) | ❌ |
| Dodge, Attack, Block, Hit, Stagger, Escape, Capture, Death, Victory | ❌ (repli idle) | ❌ |

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
