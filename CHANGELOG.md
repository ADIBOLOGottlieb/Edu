# Journal des modifications

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Non publié]

### Ajouté — M1 Mouvement de base
- Machine à états explicite (`PlayerFSM`) : 22 états déclarés, table de transitions blanche (`PlayerFsmRules`), priorités par catégorie, sortie anticipée uniquement quand l'état a fini (`exit_allowed`).
- États implémentés : **Idle, Run, Sprint, Jump, Fall, Landing (douce / dure), Slide**. Les 15 autres sont déclarés mais inaccessibles.
- `MovementDecider` (choix de l'état) et `LocomotionMotor` (vitesse) : logique pure, testée sans moteur physique.
- `RunnerBody` (CharacterBody2D commun joueur / IA) : signaux `state_changed`, `jump_started`, `landed` ; formes de collision debout / glissade synchronisées avec l'état ; détection du plafond avant de se relever.
- Entrées : `IntentFrame` rempli par un `Controller` — `HumanController` (clavier + tactile via l'InputMap), `ScriptedController` (tests). Mémoire tampon du saut et de la glissade, *coyote time*.
- Réglages dans `data/tuning/player_move.tres`, poses dans `data/animations/player_anims.tres` (générés par `tools/generate_default_data.gd`).
- Silhouette **provisoire** dessinée par code (`RunnerVisual`) — voir `docs/PLACEHOLDER_ASSETS.md`.
- Boutons tactiles multi-touch avec zone sûre (`TouchControls`).
- Bac à sable `scenes/sandbox/movement_sandbox.tscn` + panneau de débogage ; bouton d'accès depuis l'écran de démarrage.
- Outil `tools/capture_sandbox.gd` : capture une image par état.

### Corrigé pendant M1
- Un appui sur Glisse pendant une réception était perdu (le joueur percutait le mur du tunnel). Ajout d'une mémoire tampon de glissade et de la transition `LANDING → SLIDE`.

### Vérifié — M1
- **65/65 tests verts** (dont 6 d'intégration avec le vrai moteur physique), aucune erreur de script, Godot 4.7.2 headless.
- Bac à sable lancé 300 frames en headless sans erreur ; captures fenêtrées des 7 états contrôlées visuellement (Windows, Intel UHD, rendu Compatibility).

### Non vérifié — M1
- Aucun test sur appareil Android (tactile réel, multi-touch, encoches, performances).
- Ressenti de jeu (vitesses, gravité) : valeurs de départ, non ajustées par des sessions de jeu.

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
