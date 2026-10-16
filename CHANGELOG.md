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

- GUT 9.7.1 vendorisé dans `addons/gut/` (archive source du tag `v9.7.1`, licence MIT).
- Fichiers `.uid` générés par Godot 4.7, versionnés.

### Vérifié
- `godot --headless --import` : aucune erreur de script.
- Tests GUT : **11/11 verts**, 63 assertions, code de sortie 0 (Godot 4.7.2-stable officiel, SHA-512 vérifié, Windows 11).
- Lancement du jeu en headless pendant 120 frames : aucune erreur.

### Non fait / reporté
- Ouverture dans l'éditeur graphique et affichage de l'écran de démarrage : non vérifiés visuellement.
- `export_presets.cfg` Android : reporté au jalon M13 (nécessite le SDK Android). Rien n'est testé sur Android.
