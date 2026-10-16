# Journal des modifications

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Non publié]

### Ajouté — M2 Parkour avancé
- États **Vault, WallRun, WallClimb, LedgeHang, Roll, DoubleJump** (13 états implémentés sur 22).
- `ParkourSensors` : rayons de détection (mur à la poitrine, obstacle bas avec mesure de hauteur, rebord dans une fenêtre de saisie), sans nœud à placer dans les niveaux.
- Franchissement automatique des obstacles de 12 à 50 px en courant (impulsion calculée sur la hauteur mesurée, élan conservé, pas d'immobilisation à l'arrivée).
- Course murale (élan converti en montée, une fois par phase aérienne) → escalade (1,2 s d'endurance, rechargée au sol ou à un rebord) → chute ; saut mural depuis l'une ou l'autre, avec 0,18 s sans contrôle aérien.
- Suspension au rebord : immobile, se hisse (Saut ou avant), lâche (Glisse ou arrière), pas de reprise pendant 0,3 s.
- Roulade : Glisse pendant une réception **dure** (annule l'immobilisation et conserve la vitesse de course).
- **Double saut soumis à la capacité `double_jump`** (`AbilitySet`, portée par `ProfileService`) : refusé tant qu'elle n'est pas débloquée, une seule fois par phase aérienne.
- `jump_started(kind)` distingue `&"ground"`, `&"double"`, `&"wall"`, `&"ledge"`.
- Bac à sable : mur escaladable, mur trop haut ; F4 débloque ou verrouille le double saut.
- `tools/capture_sandbox.gd` capture les 13 états.

### Modifié — M2
- Glisse pendant une réception dure donne une roulade (et non plus une glissade) ; la réception douce garde la glissade (ADR-014 complété par ADR-019).
- `LocomotionMotor.on_enter(from, to, …)` et `MovementDecider.can_exit(state, intent, …)` : nouvelles signatures.
- `ProfileService` a un `class_name ProfileServiceNode` (ADR-020).

### Vérifié — M2
- **108/108 tests verts**, deux exécutions consécutives (dont 7 tests d'intégration parkour avec le vrai moteur physique), aucune erreur de script.
- Captures fenêtrées des 13 états contrôlées visuellement ; le coureur s'est aussi accroché seul au bord de la fosse (géométrie non prévue pour ce test).

### Non vérifié — M2
- Android (tactile réel, multi-touch, performances). Ressenti : valeurs de départ non ajustées en jeu.
- Pentes et plateformes mobiles : non testées (le niveau n'en contient pas encore).

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
