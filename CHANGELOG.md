# Journal des modifications

Format : [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## [Non publié]

### Ajouté — M3d Décor urbain réaliste et Lomé
- **Objets urbains réels au premier plan** (silhouettes noires, touches de couleur chaude) à la place des rectangles : `BlockKind` déduit le type de chaque bloc de sa forme (immeuble, pilier, petit obstacle, mur, plateforme, plafond, poutre ; forçable par `ChunkLayout.kinds`), `PropPainter` le dessine selon le style de la ville. Moderne : bureaux, immeubles, entrepôt, climatiseurs, caisses, châteaux d'eau, cages d'escalier, conteneurs, enseignes suspendues, passerelles, poutrelles, flèches de grue. **Lomé** : maisons-boutiques à toit de tôle et enseignes peintes, balcons, claustras, étal de marché au pagne wax, bidons jaunes, pneus, zémidjan, poteaux électriques, réservoir d'eau, bâche de marché, enseigne de coiffeur.
- La collision reste le rectangle testé : le décor ne change rien au jeu (les 24 tronçons restent jouables, tests inchangés).
- **Arrière-plan en couches** (`CityBackdrop` + `CityTheme`) : ciel dégradé et soleil, horizon lointain avec les repères de la ville, quartiers intermédiaires (toits de tôle, réservoirs, paraboles, palmiers, minaret, clocher), rue proche (palmiers, poteaux et câbles, réverbères, panneaux). Un seul dessin par couche (mobile).
- **Lomé, ville de départ** : `data/cities/lome.tres` (5 parcours : Grand Marché, Boulevard du 13-Janvier, Quartier Bè, Cathédrale, Place de l'Indépendance) et `lome_theme.tres` (heure dorée sur le golfe de Guinée) ; évocations stylisées originales du Monument de l'Indépendance, de la cathédrale à deux flèches, d'une tour d'hôtel, de la plage et des cocotiers. Scène `scenes/levels/lome_run.tscn`, accessible depuis l'écran de démarrage.
- `LevelRunner.city` / `route_index` ; `tools/capture_motion.gd --city=lome --route=N` ; `tools/capture_props.gd`, `tools/capture_backdrop.gd` (planches de contrôle).
- Tests : `test_block_kind` (8), `test_prop_painter` (9 : limites, validité, couverture ≥ 85 %, bord de course plein, budget de polygones), `test_city_backdrop` (12), jouabilité des **5 parcours de Lomé** par le pilote automatique ; **205/205**.

### Limites connues — M3d
- Performances Android non mesurées (silhouette 3D + décor détaillé).
- Grandes enseignes orange très présentes à l'écran : à doser au prochain réglage artistique.
- Les monuments sont des évocations : vérification juridique à faire avant la sortie (proposition §8).


### Ajouté — M3c Coureur 3D : escalade, glissade, saut athlétique
- **Le joueur utilise maintenant la silhouette 3D** (`ModelVisual` dans `player.tscn`) ; l'ancien dessin par code reste dans la scène, masqué (`tools/capture_motion.gd --model2d` pour comparer).
- **Clips de parkour capturés** de la bibliothèque Quaternius 2 (CC0), reciblés sur le mannequin par `tools/build_parkour_anims.gd` → `parkour_anims.res` (164 Ko) : glissade (entrée, boucle, sortie), hissage par-dessus un obstacle, saut athlétique (« ninja jump »), réception accroupie, projection en arrière.
- **Glissade réelle** sous les obstacles bas ; **escalade** : course au mur, bras qui se tendent vers les prises en alternance, suspension les deux mains au rebord, puis hissage ; franchissements joués avec le clip de hissage.
- Tests : `test_runner_model_visual` (glissade capturée, gestes d'escalade) ; **175/175**.
- Proposition « tour du monde » (villes, monuments, décor urbain, pièces, skins, énergie, idées) : [docs/PROPOSITION_TOUR_DU_MONDE.md](docs/PROPOSITION_TOUR_DU_MONDE.md), **à valider**.


### Ajouté — Prototype : silhouette 3D par capture de mouvement
- `RunnerModelVisual` : mannequin humain 3D (Quaternius *Universal Animation Library*, **CC0**) rendu en noir uni dans un `SubViewport`, caméra orthographique de profil, affiché comme un sprite 2D. Animations capturées (repos, jogging, sprint, appel, suspension, réception, roulade, accroupi) fondues au changement d'état ; cadence de course calée sur la vitesse réelle ; saltos par rotation autour des hanches (`FigureAnimation.rotation`).
- Pas encore branché sur `player.tscn` : activé par `tools/capture_motion.gd -- <dossier> --model3d` pour comparaison.
- Tests : `test_runner_model_visual` (clips présents, repos, course, appel) ; **173/173**.

### Limites connues — prototype 3D
- Pose aérienne passive (bras ballants), aussi utilisée pour les franchissements ; pas de vraie glissade ni de hissage. La bibliothèque 2 (glissade, hissage, saut dynamique) utilise un autre squelette : reciblage à faire.
- Performances Android du rendu 3D en SubViewport non mesurées.


### Ajouté — M3b (3/3) Silhouette humaine et gestuelle fluide
- **Silhouette fidèle à la photo de référence**, adaptée de profil : adulte athlétique (≈ 8 têtes), cheveux courts arrondis avec frange, col de sweat relevé, sweat ample aux manches bouffantes resserrées aux poignets, grandes mains ouvertes aux doigts écartés, pantalon ample froissé au genou et à la cheville, baskets épaisses. Contours lissés (Catmull-Rom), plus de « personnage Lego ».
- Proportions et volumes en données : `SilhouetteStyle` (`data/animations/protagonist_style.tres`).
- **Cycle de foulée humain** pour la course et le sprint (appui, amorti, poussée, suspension, ramené), bras opposés coudes fléchis, rebond du bassin ; poses lissées par des **ressorts amortis**.
- **Couche de mouvement** inspirée des vidéos de référence : bras lancés à l'appel, amorti de réception proportionnel à l'impact, genoux groupés en montée et jambes tendues bras écartés en descente, inclinaison selon la vitesse et l'accélération (on se redresse en freinant), tête stabilisée.
- **Figures retravaillées d'après les vidéos** : chaque figure a une anticipation (accroupi, bras armés) et une réception amortie. Salto avant et wall flip très groupés (genoux à la poitrine), vrille, roulade, cat leap et suspension pieds plantés au mur, tic-tac avec passage de hanche, kong vault bras armés. Course plus penchée, sprint encore plus, saut avec genou d'attaque, réception profonde.
- `tools/capture_motion.gd` : filme une course du pilote automatique (images à assembler en vidéo avec ffmpeg).

### Vérifié — M3b (3/3)
- **169/169 tests verts** (239 s), dont `test_silhouette_style` (proportions, détails de la référence, vêtements amples) et `test_runner_motion` (amorti proportionnel à l'impact puis retour au repos, bras lancés à l'appel).
- Vidéo de contrôle de 25 s sur 10 tronçons (pilote automatique, aucune chute) et planche des 9 figures relues.

### Limites connues — M3b (3/3)
- Le hissage depuis un rebord n'a pas encore sa propre figure (il réutilise la pose de saut).
- Légère pause de la rotation à chaque image clé d'un salto (interpolation adoucie entre clés).
- En suspension, la jambe côté mur est dessinée sur le bloc noir et se lit mal.
- Silhouette toujours dessinée par code (provisoire) ; performances Android non mesurées.


### Ajouté — M3b (2/3) Figures de parkour
- 9 figures choisies selon le contexte à l'entrée d'un état (`Figure.choose`), signal `figure_started(nom)` :
  - **Tic-tac** (nouveau mouvement) : vite contre un mur de 50 à 150 px, appui du pied et passage par-dessus sans s'accrocher (une fois par phase aérienne, comme la course murale).
  - **Kong vault** (sprint, obstacle ≥ 30 px) : plongeon plus rapide (+10 %) et plus bas ; **speed vault** ; **lazy vault** (sous 380 px/s).
  - **Salto avant** : saut en sprint au bord du vide. **Wall flip** : salto arrière en se repoussant d'un mur. **Vrille** : au double saut.
  - **Cat leap** : arrivée accroché au rebord avec de l'élan. **Roulade** : vraie rotation complète.
- Animations **par images clés** (`FigureAnimation`, `data/animations/player_figures.tres`), synchronisées sur la physique : durée calculée sur le temps de vol réel (`Figure.expected_duration`).
- Rotation du corps entier autour des hanches et vrille (`AnimClip.rotation`, `AnimClip.spin`) ; retour à la verticale par le plus court chemin à la fin d'une figure.
- Capteurs : hauteur du haut du mur, bord du vide ; contexte : élan horizontal de la phase aérienne.
- `tools/capture_figures.gd` : planche de contrôle (une ligne par figure, 4 images).

### Vérifié — M3b (2/3)
- **162/162 tests verts** (237 s), dont 7 tests d'intégration qui déclenchent chaque figure avec le vrai corps et vérifient la rotation réelle du salto et le retour à la verticale.
- Les 24 tronçons et 3 courses aléatoires (~800 m) restent traversés sans chute ; les figures y apparaissent naturellement (kong, salto, tic-tac, roulades).
- Planche des 9 figures contrôlée visuellement.

### Limites connues — M3b (2/3)
- Speed vault et lazy vault restent peu lisibles avec le squelette provisoire (pas de corps de profil) : à reprendre avec la nouvelle silhouette (étape 3/3).

### Ajouté — M3b (1/3) Parcours complexes et progressifs sur les toits
- **Altitude variable** : chaque tronçon a un toit de sortie à `exit_y` ; les tronçons s'empilent en hauteur (on monte et on redescend de toit en toit, la rue est 1400 px plus bas). Le séquenceur garde l'altitude dans une bande.
- **24 tronçons sur 5 paliers** (0 initiation → 4 expert) : sauts entre toits, escaliers de toits, descentes avec roulade, escalade de façades, champs d'obstacles, sauts de précision sur piliers étroits, glissade puis saut, double route (passerelles hautes / obstacles bas), poutres de grue au-dessus du vide, enchaînements tunnel → descente → escalade, « gauntlet » à 4 mouvements.
- Difficulté croissante : un palier de plus tous les 5 tronçons en course aléatoire ; le parcours fixe monte du palier 0 au palier 4.
- **Validateur par graphe de franchissement** : surfaces reliées par la vraie trajectoire de saut (montée/descente) ou par l'escalade ; un chemin entrée → sortie doit exister.
- **Pilote automatique** (`AutopilotController`) : sprint, saut au bord, glissade sous plafond, roulade, saut contre un mur abordé lentement, vitesse réduite avant un atterrissage étroit. Base de l'IA des poursuivants (M5).
- **Test de jouabilité** : le pilote traverse chacun des 24 tronçons et une course aléatoire de 15 tronçons, sans chute.

### Corrigé — M3b
- La ligne d'arrivée et le mur de fin étaient placés à l'altitude 0 : sur un parcours terminant plus bas, l'arrivée ne se déclenchait jamais. Ils suivent maintenant l'altitude du dernier toit.
- Seuil de chute relatif au toit le plus bas du tronçon (et non plus une hauteur fixe).

### Vérifié — M3b (1/3)
- **140/140 tests verts** (226 s), dont la jouabilité des 24 tronçons.
- Diagnostic : 3 graines × 30 tronçons aléatoires (≈ 800 m chacune) traversées sans chute, altitude jusqu'à −520 px.
- 60 FPS (moyen, 1 % bas, minimum) sur 45 s, 8 appels de dessin (PC, Intel UHD).

### Non vérifié — M3b (1/3)
- Jouabilité **humaine** sur téléphone (le pilote a des réflexes parfaits) : difficulté ressentie à ajuster en session de jeu.

### Ajouté — M3 Niveau à défilement
- Tronçons décrits en données (`ChunkLayout`, `ChunkLibrary`, `data/levels/chunk_library.tres`) : 10 tronçons, difficulté 0 à 3.
- `ChunkSequencer` : parcours ordonné (missions) ou aléatoire à graine (course), sans répétition immédiate, difficulté croissante avec la distance.
- `LevelValidator` : vérifie sol d'entrée/sortie, trous franchissables, murs escaladables, plafonds glissables, zone de réapparition libre.
- `ChunkStreamer` : génère devant, recycle derrière, réserve de réutilisation bornée.
- `LevelRunner` : arrivée (mode ordonné), chute = replacement au début du tronçon (la défaite arrive en M6), distance.
- `RunnerCamera` : avance dans le sens du regard, recul borné.
- Scènes `fixed_run.tscn` (avec arrivée) et `endless_run.tscn` (aléatoire) ; boutons sur l'écran de démarrage.
- `CityBackdrop` et `LevelGeometry` partagés (le bac à sable n'a plus de code dupliqué).
- `tools/profile_run.gd` : profilage de la course infinie.

### Performances — M3 (PC de développement, Intel UHD, 1280×720, rendu Compatibility)
- Dessin regroupé : un élément de dessin par tronçon et un pour la skyline → **123 → 8 appels de dessin** par image.
- Course infinie 45 s à vitesse de sprint : **60 FPS moyen, 1 % bas 60, minimum 60** (deux exécutions).
- 200 tronçons générés en test : nœuds et réserve bornés ; 14 constructions pour 33 tronçons sur 60 s.
- **Non mesuré sur Android** : le critère « ≥ 55 FPS sur appareil cible » reste à vérifier au jalon M13.

### Vérifié — M3
- **133/133 tests verts**, aucune erreur, aucun avertissement.

### Retours de l'utilisateur à traiter (après M3)
- Parcours trop simples : complexité croissante demandée au fil de la progression.
- Figures de parkour plus spectaculaires et réalistes demandées.
- Le personnage ne respecte pas les images de référence (silhouette pleine, sweat à capuche, pantalon ample).

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
