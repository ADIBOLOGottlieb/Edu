# EDU

*Édu* : « course » / « pays » en ewe.

Jeu d'action-parkour 2D à défilement horizontal pour Android (portage PC prévu) : un jeune coursier clandestin fuit à travers une mégapole sous surveillance, avec des combats en pleine poursuite, des équipements temporaires, des refuges et des choix narratifs.

## État du projet

| Jalon | Contenu | État |
|---|---|---|
| M0 Socle | configuration, autoloads vides, actions d'entrée, tests | terminé : 11/11 tests verts (Godot 4.7.2, GUT 9.7.1, headless, Windows) ; non testé sur Android |
| M1 Mouvement de base | Idle, Run, Sprint, Jump, Fall, Landing, Slide ; clavier + tactile ; bac à sable | terminé : 65/65 tests verts, captures contrôlées ; non testé sur Android |
| M2 Parkour avancé | Vault, WallRun, WallClimb, LedgeHang, Roll, DoubleJump (capacité à débloquer) | terminé : 108/108 tests verts, captures contrôlées ; non testé sur Android |
| M3 Niveau à défilement | tronçons en données, parcours fixe / aléatoire, caméra, arrivée, profilage | terminé : 133/133 tests, 60 FPS sur PC ; non mesuré sur Android |
| M3b Parcours, figures, silhouette | (1/3) toits à altitude variable, 24 tronçons sur 5 paliers, pilote automatique ; (2/3) 9 figures de parkour ; (3/3) silhouette humaine fidèle à la référence, foulée humaine, gestuelle fluide | terminé, 169/169 tests |
| M3c Coureur 3D | mannequin humain + capture de mouvement (Quaternius, CC0) : course, sprint, saut athlétique, glissade, escalade, hissage, roulade | terminé, 175/175 tests ; branche `m3c/silhouette-3d` |
| Proposition « tour du monde » | villes et monuments, décor urbain, pièces, skins, énergie : [docs/PROPOSITION_TOUR_DU_MONDE.md](docs/PROPOSITION_TOUR_DU_MONDE.md) | validée (Lomé ville de départ, énergie 1 point / 72 min) |
| M3d Décor urbain + Lomé | objets urbains réels par type de bloc, arrière-plan en couches, Lomé (5 parcours, monument, cathédrale, palmiers) | terminé, 205/205 tests ; branche `m3d/decor-lome` |
| M4 (pièges) | pics, scies, écraseurs, flammes, plateformes fragiles ; mort et réapparition ; animations AnimationTree (course à la vraie cadence, sauts synchronisés) | terminé ; branche `m4/dangers-ennemis` (pièces et ennemis retirés à la demande) |
| M5 Poursuite | vigile (même physique, IA parkour, zone d'ombre), EncounterFSM, jauge de capture, capture non graphique ; Lomé poursuivie (parcours 2 à 5) | terminé, 269/269 tests ; branche `m5/poursuite` |
| M7 Menus, carte, sauvegarde | sauvegarde atomique versionnée, progression (étoiles, records, déblocages), réglages, menu principal, carte du monde, écrans de ville et de résultat, pause | terminé, 304/304 tests ; branche `m7/menus-carte-sauvegarde` |
| M8 Inventaire et équipement | 20 emplacements, 10 objets sans combat (protection, mobilité, vigile, discrétion, pièges), caisses dans les tronçons, bouton OBJET, effets à durée, perte à la capture | terminé, 334/334 tests ; branche `m8/inventaire` |
| M6, M9 → M13 | voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) §17 | à faire |

Le personnage est une **silhouette provisoire** dessinée par code ([docs/PLACEHOLDER_ASSETS.md](docs/PLACEHOLDER_ASSETS.md)). Aucune mission n'est jouable.

## Prérequis

- **Godot 4.7.2-stable** (version standard, pas .NET) : <https://godotengine.org/download>
- **GUT 9.7.1** dans `addons/gut/` (voir [docs/TESTING.md](docs/TESTING.md))
- Git

## Lancer

```
godot --path .
```

Ou ouvrir `project.godot` dans l'éditeur, puis F5.

## Tests

Voir [docs/TESTING.md](docs/TESTING.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Décisions](docs/DECISIONS.md)
- [Règles de jeu](docs/GAME_RULES.md)
- [Journal des modifications](CHANGELOG.md)

## Commandes de développement (clavier)

| Action | Touches |
|---|---|
| Gauche / droite | A / D, ← / → |
| Saut | Espace, W, ↑ |
| Glissade | S, ↓ |
| Sprint | Maj |
| Attaque rapide / lourde | J / K |
| Blocage | L |
| Esquive | Q |
| Utiliser l’objet / objet suivant | E / Tab (tactile : bouton OBJET ; toucher l’objet en haut à gauche pour changer) |
| Pause | Échap, P |

Parkour (aucune touche supplémentaire, pensé pour le tactile) :
- **Franchir** : courir vers un obstacle bas (12–50 px), automatique.
- **Course murale / escalade** : courir vers un mur en maintenant la direction ; Saut = saut mural.
- **Rebord** : avant ou Saut = se hisser ; arrière ou Glisse = lâcher.
- **Roulade** : Glisse au moment d'une réception dure.
- **Double saut** : Saut en l'air, si la capacité est débloquée (F4 dans le bac à sable).

Les touches correspondent à des positions physiques : sur un clavier AZERTY, « A » est la touche Q et « W » la touche Z.

## Tester sur Android (APK de test)
- Préréglage d'export : `export_presets.cfg` (« Android », paquet `com.adibologottlieb.edu`, arm64-v8a + armeabi-v7a, plein écran). Les tests, outils et sources inutilisées ne sont pas embarqués.
- Prérequis locaux : modèles d'export Godot 4.7.2 (fichier officiel `Godot_v4.7.2-stable_export_templates.tpz`, SHA-512 vérifié), SDK Android, JDK 17+ et une clé de débogage **hors du dépôt** (chemins dans les réglages de l'éditeur, jamais dans le dépôt).
- Construire : `godot --headless --path . --export-debug "Android" build/EDU-0.0.1-debug.apk` (dossier `build/` ignoré par Git).
- Installer : copier l'APK sur le téléphone, autoriser « Installer des applications inconnues » pour le gestionnaire de fichiers, ouvrir l'APK ; ou `adb install -r build/EDU-0.0.1-debug.apk` avec le débogage USB.
- Icône : `assets/icon/icon.png`, générée par `tools/make_icon.gd`.
