# Journal des modifications

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Non publié]

### Ajouté — M0 Socle
- `project.godot` : nom EDU, Godot 4.7, rendu Compatibility, 1280×720 paysage, physique à 60 Hz, typage strict des déclarations (erreur), avertissements « unsafe » activés.
- 11 autoloads squelettes (`src/autoload/`). Seul `InputService` a un comportement : il enregistre les actions de jeu.
- `InputActions` : 12 actions et leurs touches clavier par défaut, enregistrement idempotent.
- Scène de démarrage provisoire `scenes/boot.tscn`.
- Tests GUT : configuration du projet, actions d'entrée, scène de démarrage.
- Documentation : architecture, décisions, règles de jeu, tests.

### Non fait / reporté
- GUT n'est pas encore copié dans `addons/gut/` (téléchargement à valider).
- Tests **non exécutés** : Godot n'est pas installé sur la machine de développement.
- `export_presets.cfg` Android : reporté au jalon M13 (nécessite le SDK Android).
