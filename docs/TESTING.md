# Tests

## Installation de GUT (une fois)

1. Télécharger **GUT 9.7.1** : <https://github.com/bitwes/Gut/releases/tag/v9.7.1>
2. Copier le dossier `addons/gut/` de l'archive dans `addons/gut/` du projet.
3. GUT est vendorisé (copié dans le dépôt) pour que tout le monde teste avec la même version.

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

## Vérification manuelle (M0)

1. Ouvrir le projet dans Godot 4.7.2 : aucune erreur dans le panneau Sortie.
2. F5 : écran clair avec « EDU — version 0.0.1 — socle M0 ».
3. Projet → Paramètres → Autoload : 11 entrées dans l'ordre de `docs/ARCHITECTURE.md` §2.
