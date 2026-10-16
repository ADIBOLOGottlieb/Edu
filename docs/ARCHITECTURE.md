# EDU — Architecture technique (proposition v0.1, à valider)

> **EDU** (*édu* : « course » / « pays » en ewe). Jeu d'action-parkour 2D à défilement horizontal pour Android, portable PC.
> Statut : **document de conception uniquement. Aucune fonctionnalité n'est implémentée à ce stade.**

---

## 0. Principes directeurs

| Principe | Conséquence concrète |
|---|---|
| Originalité | Le principe « fuir un poursuivant en parkour » est un genre, pas une propriété. Aucun asset, nom, niveau, UI ou animation ne reprend *Vector* ou un autre jeu. |
| Logique testable hors scène | Toutes les règles (machines à états, inventaire, énergie, narration, sauvegarde, boutique) vivent dans des classes `RefCounted` pures, sans dépendance au `SceneTree`. Les nœuds ne font que les brancher sur la physique et l'affichage. |
| Données séparées du code | Réglages, équipements, attaques, missions, dialogues = `Resource` (`.tres`) ou JSON validé. Changer un chiffre ne demande pas de modifier un script. |
| Entrées ≠ décisions | Le personnage consomme une *intention* (`IntentFrame`). Elle vient du clavier, du tactile, de l'IA ou d'un script de test : le corps ne sait pas qui le pilote. |
| Un seul propriétaire par donnée | Chaque état persistant a un service propriétaire unique. Les autres le lisent ou lui envoient des requêtes. |
| Bas de gamme d'abord | Rendu *Compatibility* (OpenGL ES 3), 60 Hz de physique, aucune allocation par frame dans les boucles chaudes, pooling. |
| Honnêteté | Une fonctionnalité est « terminée » seulement si elle est implémentée, testée et vérifiée sur la cible. Les placeholders sont listés comme tels. |

### Direction artistique (d'après les références fournies)
- **Silhouettes noires pleines** sur fonds clairs ou dégradés, à fort contraste. Une silhouette lisible = un état lisible : chaque pose doit être reconnaissable en ombre chinoise.
- Deux gabarits de référence : un coureur en vêtements amples (protagoniste : sweat, pantalon cargo) et un corps élancé (poursuivants / forces de sécurité, silhouettes plus rigides).
- Décor : lignes d'immeubles en aplats sur 3 à 4 plans de parallaxe ; la couleur ne vient que du ciel, des signalétiques de surveillance et des effets d'équipement.
- ⚠️ L'image de skyline fournie porte un filigrane **pngtree** : c'est une banque d'images sous licence. Elle sert **uniquement d'inspiration** et ne sera jamais importée dans le dépôt. Les décors seront produits en interne (formes procédurales puis assets originaux).
- Prototype : silhouettes en `Polygon2D` articulées (tête, torse, bras, jambes) animées par `AnimationPlayer`. **Ce ne sont pas des animations dessinées finales.**

---

## 1. Arborescence du projet

```
Edu/
├── project.godot
├── export_presets.cfg              # Android (puis Windows/Linux)
├── .gitignore  .gitattributes      # .godot/ ignoré, LFS pour PNG/OGG/WAV
├── README.md  CHANGELOG.md
├── docs/
│   ├── ARCHITECTURE.md             # ce document
│   ├── DECISIONS.md                # journal des décisions (ADR courts)
│   ├── GAME_RULES.md               # définitions de règles (mort, énergie, perte d'objets…)
│   ├── NARRATIVE_RULES.md          # chaque variable narrative et ce qui la modifie
│   ├── MONETIZATION.md             # catalogue, règles, conditions d'activation prod
│   ├── PLACEHOLDER_ASSETS.md       # liste des assets provisoires à remplacer
│   └── TESTING.md                  # commandes de test
├── addons/
│   └── gut/                        # framework de test GUT (MIT, gratuit)
├── src/
│   ├── autoload/                   # singletons (services globaux), voir §2
│   │   ├── event_bus.gd
│   │   ├── save_service.gd
│   │   ├── settings_service.gd
│   │   ├── scene_router.gd
│   │   ├── time_service.gd
│   │   ├── profile_service.gd      # progression, refuges, améliorations
│   │   ├── attempt_service.gd      # tentatives / énergie (mode course)
│   │   ├── narrative_service.gd
│   │   ├── inventory_service.gd
│   │   └── monetization_service.gd
│   ├── core/                       # logique pure (RefCounted), sans nœud
│   │   ├── fsm/
│   │   │   ├── state_machine.gd            # FSM générique à table de transitions
│   │   │   └── transition_table.gd
│   │   ├── player/
│   │   │   ├── player_state.gd             # enum + métadonnées (priorité, catégorie)
│   │   │   ├── player_fsm_rules.gd         # transitions autorisées
│   │   │   └── intent_frame.gd
│   │   ├── encounter/
│   │   │   ├── encounter_state.gd          # RUNNING…MISSION_COMPLETED
│   │   │   └── encounter_fsm.gd
│   │   ├── combat/
│   │   │   ├── damage_resolver.gd
│   │   │   └── attack_token_pool.gd        # limite d'attaquants simultanés
│   │   ├── inventory/
│   │   │   ├── inventory.gd
│   │   │   └── effect_stack.gd             # règles de cumul
│   │   ├── attempts/
│   │   │   ├── attempt_ledger.gd
│   │   │   └── clock.gd                    # interface d'horloge injectable
│   │   ├── narrative/
│   │   │   ├── narrative_state.gd
│   │   │   ├── condition_evaluator.gd
│   │   │   └── dialogue_runner.gd
│   │   ├── save/
│   │   │   ├── save_schema.gd              # versions + migrations
│   │   │   └── save_validator.gd           # bornes, types, valeurs par défaut
│   │   └── store/
│   │       ├── store_provider.gd           # interface abstraite
│   │       ├── fake_store_provider.gd      # dev/tests
│   │       ├── entitlement_ledger.gd       # droits accordés après validation
│   │       └── purchase_validator.gd       # interface (local → serveur)
│   ├── gameplay/                   # nœuds qui branchent la logique sur le moteur
│   │   ├── actors/
│   │   │   ├── runner_body.gd              # CharacterBody2D commun joueur / IA
│   │   │   ├── runner_body.tscn
│   │   │   ├── motor/                      # un script par mouvement
│   │   │   │   ├── ground_motor.gd  air_motor.gd  slide_motor.gd
│   │   │   │   ├── vault_motor.gd  wall_motor.gd  ledge_motor.gd
│   │   │   │   └── roll_dodge_motor.gd
│   │   │   ├── sensors/                    # RayCast2D / ShapeCast2D groupés
│   │   │   │   └── parkour_sensors.gd
│   │   │   ├── visual/
│   │   │   │   ├── runner_visual.gd        # lit l'état, joue l'animation
│   │   │   │   └── silhouette_rig.tscn     # prototype Polygon2D
│   │   │   ├── player/  player.tscn  player.gd
│   │   │   └── pursuer/ pursuer.tscn pursuer.gd
│   │   ├── controllers/
│   │   │   ├── controller.gd               # base : produit un IntentFrame
│   │   │   ├── human_controller.gd         # InputMap (clavier + tactile)
│   │   │   ├── pursuer_ai_controller.gd
│   │   │   └── scripted_controller.gd      # tests / cinématiques
│   │   ├── combat/
│   │   │   ├── hitbox.gd  hurtbox.gd       # Area2D
│   │   │   ├── health_component.gd
│   │   │   └── combat_component.gd
│   │   ├── encounter/
│   │   │   └── encounter_director.gd       # pilote l'EncounterFSM dans la scène
│   │   ├── equipment/
│   │   │   ├── equipment_runtime.gd        # active / expire les effets
│   │   │   └── effects/                    # un script par effet
│   │   │       ├── armor_effect.gd  shield_effect.gd  boost_effect.gd
│   │   │       ├── camo_effect.gd  hack_effect.gd  hideout_effect.gd
│   │   │       ├── overcharge_effect.gd  pulse_weapon_effect.gd
│   │   │       ├── energy_lance_effect.gd  missile_effect.gd
│   │   └── level/
│   │       ├── level_runner.gd             # défilement, chunks, fin de niveau
│   │       ├── chunk.gd  chunk_streamer.gd
│   │       ├── stealth_zone.gd             # Area2D : perte de trace
│   │       ├── pickup.gd                   # objet ramassable
│   │       ├── nav_hint.gd                 # marqueurs de saut pour l'IA
│   │       └── checkpoint.gd
│   ├── ui/
│   │   ├── main_menu/  settings/  hud/  touch_controls/
│   │   ├── inventory_panel/  dialogue_box/  choice_panel/
│   │   ├── result_screen/  refuge/  store/  purchase_confirm/
│   │   └── notifications/toast.gd
│   └── data_types/                 # définitions de Resource (class_name)
│       ├── move_tuning.gd          # vitesses, gravités, timings
│       ├── animation_set.gd        # état → animation, vitesse, boucle
│       ├── attack_data.gd          # startup / active / recovery, dégâts
│       ├── enemy_data.gd  difficulty_profile.gd
│       ├── equipment_data.gd
│       ├── mission_data.gd  refuge_data.gd  upgrade_data.gd
│       └── store_item_data.gd
├── data/                           # instances de données (aucun code)
│   ├── tuning/        player_move.tres  pursuer_move.tres
│   ├── animations/    player_anims.tres
│   ├── attacks/       light.tres  heavy.tres  pursuer_grab.tres
│   ├── enemies/       enforcer.tres  drone.tres
│   ├── equipment/     armor.tres … overcharge.tres (10 fichiers)
│   ├── missions/      m01_falsification.tres
│   ├── narrative/
│   │   ├── variables.json          # déclaration + bornes de chaque variable
│   │   ├── characters.json
│   │   └── dialogues/m01.json
│   └── store/catalog.tres
├── scenes/
│   ├── boot.tscn  main_menu.tscn  refuge.tscn
│   ├── levels/  m01_district.tscn
│   └── sandbox/                    # scènes de test manuel
│       ├── movement_sandbox.tscn   combat_sandbox.tscn
│       ├── pursuit_sandbox.tscn    inventory_sandbox.tscn
│       └── store_sandbox.tscn
├── assets/  (sprites/, audio/, fonts/, shaders/) — originaux uniquement
└── tests/
    ├── unit/            # logique pure : rapide, sans scène
    └── integration/     # scènes instanciées en headless
```

---

## 2. Services globaux (autoloads) et responsabilités

Ordre de chargement = ordre de dépendance (un service ne dépend que des précédents).

| # | Service | Possède | Ne fait **pas** |
|---|---|---|---|
| 1 | `EventBus` | Signaux transverses seulement (UI ↔ gameplay). | Aucun état. Les signaux locaux restent locaux. |
| 2 | `TimeService` | Horloge murale UTC, horloge monotone de session, détection des retours en arrière de l'horloge. | Aucune règle métier. |
| 3 | `SaveService` | Lecture et écriture atomiques, versions, migrations, sauvegarde de secours. | N'interprète pas les données : chaque service sérialise sa propre section. |
| 4 | `SettingsService` | Audio, langue, disposition et opacité du tactile, vibrations, qualité. | — |
| 5 | `SceneRouter` | Transitions de scène, écran de chargement, passage de paramètres. | Aucune logique de mission. |
| 6 | `ProfileService` | Progression de l'histoire, refuges, améliorations, monnaie gagnée en jeu. | Énergie (→ 7), droits achetés (→ 10). |
| 7 | `AttemptService` | Échecs du mode course, période de récupération. | Santé du personnage (locale à la partie). |
| 8 | `NarrativeService` | Variables narratives, décisions, dialogues vus, calcul des fins. | Lancement des missions (il expose des requêtes). |
| 9 | `InventoryService` | Inventaire persistant (20 emplacements + extensions). | Effets actifs (portés par `EquipmentRuntime` pendant la partie). |
| 10 | `MonetizationService` | Catalogue, achats, droits accordés, publicités récompensées. | **Ne touche jamais au gameplay** : il publie des droits que les autres services consultent. |

---

## 3. Personnage : machine à états, animation et entrées

### 3.1 Chaîne de responsabilités

```
Controller (Human | AI | Scripted)
      │  IntentFrame  (axe, saut appuyé/maintenu, sprint, glissade, attaque légère/lourde,
      ▼                  blocage, esquive, utiliser l'objet n)
RunnerBody (CharacterBody2D)
      ├─ PlayerFSM (logique pure) ← ParkourSensors (contacts mur / rebord / obstacle)
      ├─ Motor actif (un seul à la fois, choisi par l'état)
      ├─ CombatComponent / HealthComponent
      └─ émet state_changed(from, to)
              ▼
RunnerVisual (lit l'état + AnimationSet → AnimationPlayer)
```
- La **physique pilote l'animation**, jamais l'inverse. Les fenêtres d'action (attaque active, contre, invulnérabilité) sont comptées en *ticks de physique* d'après `AttackData`. L'animation est ajustée sur la durée de l'état. C'est déterministe, donc testable en headless.
- Exception unique : des pistes de *méthode* de l'AnimationPlayer peuvent déclencher du cosmétique (son, particules), jamais une hitbox.

### 3.2 États, catégories et priorités

Une seule FSM plate : un seul état actif, donc deux animations incompatibles ne peuvent pas tourner en même temps.

| Prio | Catégorie | États | Interruptible par |
|---|---|---|---|
| 100 | SYSTEM | Capture, Death, Victory | rien (sortie scriptée seulement) |
| 90 | ESCAPE | Escape | SYSTEM |
| 80 | REACTION | Hit, Stagger | SYSTEM |
| 60 | COMBAT | Attack, Block, Dodge | REACTION+, ou Dodge pendant la fenêtre d'annulation |
| 40 | TRAVERSAL | Vault, WallRun, WallClimb, LedgeHang, Slide, Roll | REACTION+ ; Jump dans les fenêtres prévues |
| 20 | AIR | Jump, DoubleJump, Fall, Landing | TRAVERSAL+, COMBAT (attaque aérienne : à valider) |
| 0 | GROUND | Idle, Run, Sprint | tout |

Règle d'interruption : une requête vers B depuis A est acceptée si `(A→B) ∈ table` **et** (`prio(B) > prio(A)` **ou** A est dans sa fenêtre d'annulation **ou** A est terminé).
- `DoubleJump` est soumis à `ProfileService.has_ability(&"double_jump")`.
- `Landing` se ramifie selon la vitesse verticale d'impact : réception douce → Run ; dure → Roll si l'esquive est maintenue, sinon `Landing` long avec perte d'élan.
- Changement de direction : demi-tour instantané en Idle/Run ; décélération progressive en Sprint ; aucun changement en Slide, Vault ou WallRun.
- Mémoire tampon d'entrée (≈ 100 ms) et *coyote time* (≈ 80 ms) dans `MoveTuning`.

### 3.3 Signaux du personnage
```gdscript
signal state_changed(from: StringName, to: StringName)
signal jump_started(kind: StringName)          # &"ground", &"double", &"wall"
signal landed(impact_speed: float)
signal attack_started(attack: AttackData)
signal dodge_finished()
signal captured(by: Node2D)
signal escaped()
signal defeated()
```

### 3.4 Séparation des données
- `MoveTuning` : vitesses, accélérations, gravité montée/descente, hauteurs de saut, durées de glissade, de roulade et de course murale, *coyote*, mémoire tampon.
- `AnimationSet` : `Dictionary[StringName, AnimEntry]` (nom d'animation, vitesse, boucle, synchronisation sur la durée de l'état).
- Joueur et poursuivants partagent `RunnerBody`, avec des `MoveTuning` et des `AnimationSet` différents.

---

## 4. Niveau de course et défilement
- `LevelRunner` assemble des **chunks** (`PackedScene` de largeur fixe) en avance de 2 chunks et libère ceux qui sont 1 chunk derrière, avec un pool par type.
- Caméra `Camera2D` avec avance dans le sens de la course et lissage ; elle ne recule jamais au-delà d'une borne.
- Chaque chunk déclare ses points d'entrée et de sortie, ses `NavHint` (saut, escalade, glissade) pour l'IA, et ses zones furtives.
- Missions d'histoire : chunks fixes et ordonnés. Mode course : enchaînement aléatoire **à graine** (reproductible pour les tests et les bugs).

---

## 5. Poursuite et confrontation

### 5.1 `EncounterFSM` (une par mission)

| De \ vers | RUNNING | PURSUIT | COMBAT | ESCAPE_WINDOW | CAPTURED | MISSION_FAILED | MISSION_COMPLETED |
|---|---|---|---|---|---|---|---|
| RUNNING | — | poursuivant actif | — | — | — | abandon | arrivée |
| PURSUIT | trace perdue / abandon | — | contact | — | prise directe (règle de mission) | — | arrivée |
| COMBAT | — | — | — | avantage obtenu | jauge de capture pleine | — | — |
| ESCAPE_WINDOW | fuite réussie | rattrapé | re-contact | — | délai écoulé + au sol | — | — |
| CAPTURED | — | — | dernière chance (QTE, si la règle l'autorise) | — | — | fin de cinématique | — |

États terminaux : `MISSION_FAILED`, `MISSION_COMPLETED`. Toute transition absente de la table est **refusée et journalisée** (testé).

```gdscript
signal encounter_state_changed(from: int, to: int, reason: StringName)
signal pursuer_engaged(pursuer: Node2D)
signal pursuer_lost_track(pursuer: Node2D)
signal pursuer_neutralized(pursuer: Node2D)
signal escape_window_opened(duration: float)
signal mission_ended(result: MissionResult)
```

### 5.2 IA des poursuivants
- Même corps physique que le joueur. **Aucune téléportation, aucune traversée de collision.** Le *rubber-banding* ne peut que moduler la vitesse dans les bornes de son `MoveTuning`.
- `PursuerAIController` : arbre de décision simple (FSM : Chase, Engage, Attack, Recover, Search, GiveUp) qui produit un `IntentFrame`.
- Obstacles : raycasts avant + `NavHint` du chunk. Échec de franchissement → chute ou détour, sans *warp*.
- Perte de trace : dans une `StealthZone` ou sous Camouflage, le poursuivant ne connaît plus que la **dernière position vue** et la fouille pendant `search_time`.
- Réaction aux esquives et aux objets : esquive réussie → recovery prolongée ; Piratage → coupure de capteurs (drones) ; Missile ou Impulsion → Stagger.
- Abandon : `MissionData.pursuit_rules` (distance, durée, zone sûre, variable narrative).
- Difficulté : `DifficultyProfile` (vitesse max, réactivité, fréquence d'attaque, taille des fenêtres de contre).
- Plusieurs adversaires : `AttackTokenPool`, avec au plus *N* attaquants simultanés (2 par défaut) ; les autres encerclent.
- Neutralisés : restent hors service jusqu'au prochain checkpoint ou chunk, selon `EnemyData.respawn_rule` (`never`, `next_checkpoint`, `after_seconds`). Pas de réapparition implicite.

### 5.3 Combat
- `AttackData` : `startup`, `active`, `recovery` (en ticks), `damage`, `poise_damage`, `cancel_window`, `hitbox_shape`, `knockback`.
- Attaque rapide / lourde ; Block (réduit les dégâts, consomme la stabilité) ; **contre** = Block déclenché dans les `parry_window` ticks avant l'impact → l'attaquant passe en Stagger et la fenêtre de fuite s'ouvre.
- Invulnérabilité post-impact (0,6 s par défaut) gérée par `HealthComponent`.
- Interruption : un coup reçu pendant `startup` annule l'attaque (sauf armure de l'attaque lourde).
- Hitbox activée **uniquement** pendant les ticks `active`, à partir de `AttackData`.

---

## 6. Santé, capture et défaite
- **Santé** (`HealthComponent`) : locale à une partie, remise à zéro à chaque mission. **Aucun lien avec l'énergie.**
- **Jauge de capture** : se remplit pendant le contact, les prises et les coups ; se vide en fuite. Pleine → `CAPTURED`.
- `CAPTURED` sans évasion → cinématique stylisée **non graphique** (fondu en silhouettes, menottes lumineuses, aucune violence explicite) → `MISSION_FAILED` → `AttemptService.record_failure()` (si mode course) → écran de résultat.

---

## 7. Inventaire et équipements

### 7.1 Inventaire (`core/inventory/inventory.gd`)
- `capacity = BASE_CAPACITY (20) + Σ extensions` ; les extensions proviennent de `ProfileService` (gagnées) ou de `MonetizationService` (droits validés).
- 1 objet = 1 emplacement (pas d'empilement dans un emplacement, conformément à la spécification).
- `try_add(item) -> AddResult` : `OK` | `FULL` | `INVALID`. En cas de `FULL`, l'objet **reste au sol**, un toast s'affiche et rien n'est supprimé.
- Signaux : `item_added(slot, id)`, `item_removed(slot, id, reason)`, `inventory_full(rejected_id)`, `capacity_changed(n)`.

### 7.2 `EquipmentData` (Resource)
`id`, `display_name`, `icon`, `category` (`DEFENSE`, `MELEE`, `RANGED`, `MOBILITY`, `STEALTH`, `TECH`, `UTILITY`), `duration` (10 s par défaut), `effect_script`, `stack_rule`, `incompatible_with: Array[StringName]`, `anims` (activation / boucle / expiration / désactivation), `lost_on_defeat: bool`.

| Équipement | Catégorie | Effet (gameplay réel) |
|---|---|---|
| Armure | DEFENSE | −50 % de dégâts |
| Bouclier | DEFENSE | bloque *N* coups, puis se brise |
| Lance énergétique | MELEE | remplace l'attaque rapide (portée ×1,6) |
| Arme à impulsion | RANGED | onde de recul → Stagger dans un rayon donné |
| Missile fictif | RANGED | projectile guidé, Stagger + neutralisation d'un drone |
| Accélérateur | MOBILITY | vitesse max ×1,25 |
| Camouflage | STEALTH | les poursuivants perdent la trace (sauf contact) |
| Kit de piratage | TECH | coupe drones, caméras et portes du chunk |
| Cachette mobile | STEALTH | immobile + invisible ; annulé si l'on bouge |
| Surcharge d'énergie | UTILITY | recharge la stabilité et réduit la jauge de capture |

### 7.3 Cumul (`stack_rule`)
- `REFRESH` (défaut) : même objet déjà actif → le chrono revient à la durée pleine ; l'objet est consommé.
- `REPLACE` : même **catégorie** active → l'ancien expire proprement (animation de désactivation), le nouveau démarre.
- `REJECT` : activation refusée, l'objet est conservé, message affiché.
- Incompatibilités explicites (ex. Cachette mobile × Accélérateur) → `REJECT`.

### 7.4 Temps et interruptions
- Les chronos d'effet utilisent le **temps de jeu** (`process_mode` pausable) : pause, menu ou mise en arrière-plan Android (`NOTIFICATION_APPLICATION_PAUSED`) → le chrono est gelé.
- Changement de chunk ou de scène au sein d'une mission : les effets sont transportés. Fin de mission : tous les effets expirent.
- Perte après défaite : les objets **ramassés pendant la mission** et marqués `lost_on_defeat` sont perdus ; les objets apportés du refuge sont conservés (**à valider**, §16).

---

## 8. Tentatives et énergie (mode course)

**Définition unique d'un échec** (`docs/GAME_RULES.md`) : *une tentative du mode course qui atteint l'état `MISSION_FAILED`*. Un abandon volontaire en cours de partie compte comme un échec (sinon il suffirait de quitter pour éviter le compteur — **à valider**). Une fermeture forcée de l'application est enregistrée au démarrage suivant grâce à un marqueur `attempt_in_progress`.

- 10 échecs → `LOCKED` pendant 6 h à partir du 10ᵉ échec. Fin → compteur remis à 0.
- Source de temps : `Time.get_unix_time_from_system()` (UTC, survit aux redémarrages) + `Time.get_ticks_msec()` (monotone dans la session).
- Retour en arrière de l'horloge détecté (`now < last_seen_utc`) → on **n'accorde aucun temps** et on conserve le temps restant stocké.
- Changement de date ou de fuseau : sans effet, tout est en UTC.
- Limite documentée : **une horloge locale modifiable ne prévient pas la fraude.** Une protection réelle demanderait un temps serveur, prévu comme interface `Clock`, pas implémenté.
- Sauvegarde corrompue : bornage (`0 ≤ échecs ≤ 10`, `0 ≤ restant ≤ 6 h`) ; une valeur invalide → valeur sûre la plus proche, avec journal.
- Histoire principale : **non soumise** à ce compteur.

```gdscript
signal attempts_changed(failures: int, max_failures: int)
signal lockout_started(ends_at_utc: int)
signal lockout_ended()
```

---

## 9. Refuges et améliorations
- `RefugeData` : PNJ présents, stock, améliorations disponibles (conditionnées par des variables narratives).
- `UpgradeData` : `id`, coût en monnaie gagnée en jeu, prérequis, effet (`MoveTuning` modifié, capacité débloquée, emplacement d'inventaire).
- Les améliorations s'appliquent par **modificateurs**, sans écraser les `.tres` de base.

---

## 10. Narration

- Données : `data/narrative/*.json` (lisible par des auteurs, versionné, validé par test). Format d'un nœud :
  `{ id, speaker, text_fr, next | choices[] }` ; un choix = `{ id, text_fr, conditions[], effects[] }`.
- Variables (`variables.json`) : `trust.<allié>` (−100..100), `public_trust`, `surveillance` (0..5), `resources`, drapeaux `flag.*`. Chaque variable déclare ses bornes ; tout effet sur une variable non déclarée **fait échouer le test de validation**.
- `NARRATIVE_RULES.md` : pour chaque choix, la liste exacte de ses effets. **Aucun choix ne modifie l'histoire sans règle écrite.**
- Dialogues vus : ensemble d'identifiants dans la sauvegarde → bouton « Passer » proposé uniquement pour le déjà-vu (le choix reste affiché).
- Fins : Réforme, Révolution, Victoire autoritaire, plus une fin secrète ; conditions déclarées en données, évaluées par `ConditionEvaluator`.
- Les personnages (6 minimum) et l'écriture des 3 actes feront l'objet d'une étape dédiée, avec le document narratif.

```gdscript
signal variable_changed(key: StringName, old: Variant, new: Variant)
signal decision_recorded(choice_id: StringName)
signal dialogue_started(id: StringName)  signal dialogue_finished(id: StringName)
```

---

## 11. Sauvegarde locale
- Fichier `user://save.json` : `{ schema_version, written_at_utc, sections: { profile, attempts, narrative, inventory, entitlements_cache, settings } }`.
- Écriture atomique : `save.tmp` → vérification de relecture → renommage ; l'ancien fichier devient `save.bak`.
- Somme de contrôle : détection de **corruption** uniquement, pas d'anti-triche.
- Migrations : `SaveSchema.migrate(data, from_version)` testées une par une.
- **Aucune donnée de paiement** n'est sauvegardée : seulement des identifiants de produit et l'état du droit (le reçu brut reste chez la plateforme).

---

## 12. Interface mobile
- Toutes les commandes passent par l'**InputMap** (`move_left`, `jump`, `slide`, `attack_light`…). Clavier et manette pour PC, `TouchControls` pour Android : le portage PC n'a rien à réécrire.
- Disposition tactile : moitié gauche = déplacement (boutons ← →, ou glisser), moitié droite = Saut / Glissade / Attaque / Esquive ; bouton d'objet rapide. Taille ≥ 48 dp, opacité réglable.
- Multi-touch via `InputEventScreenTouch` (index de doigt), sans émulation de souris.
- *Safe area* : `DisplayServer.get_display_safe_area()` pour les encoches.
- Base 1280×720, étirement `canvas_items`, aspect `expand`.

---

## 13. Monétisation (conception : **aucune transaction réelle**)

### 13.1 Modèle
| Offre | Type plateforme | Remarque |
|---|---|---|
| Campagne initiale | gratuite | toujours jouable sans payer |
| Extensions narratives | **non consommable** | restaurable |
| Tenues / personnalisations | **non consommable** | cosmétique uniquement |
| Extensions d'inventaire (+5) | **non consommable** | plafond défini (ex. 40) |
| Récupération d'énergie | **consommable** | alternative gratuite : attendre ou regarder une pub récompensée |
| Pub récompensée | — | **toujours** à l'initiative du joueur, plafond par jour |
| Suppression des pubs | **non consommable** | restaurable ; les pubs récompensées restent proposées (volontaires) |
| Objets aléatoires payants | **exclus de la v1** | — |

### 13.2 Architecture
```
UI Boutique ── demande ──► MonetizationService ──► StoreProvider (interface)
     ▲                         │                       ├─ FakeStoreProvider (dev/tests)
     │                         │                       ├─ GooglePlayStoreProvider (plus tard)
     │                         ▼                       └─ AppStoreProvider (plus tard)
     └── droits ◄── EntitlementLedger ◄── PurchaseValidator (interface)
                                             ├─ FakeValidator (dev)
                                             └─ ServerValidator (prod : serveur requis)
```
- `StoreProvider` : `query_products(ids)`, `purchase(id)`, `acknowledge / consume(token)`, `restore()`, plus des signaux (`purchase_updated`, `purchase_failed(code)`).
- **Un achat n'est accordé qu'après `PurchaseValidator.validate()` réussi.** La réponse brute du client ne suffit jamais.
- Prix : **toujours** le prix localisé renvoyé par la plateforme (`formatted_price`) ; aucun prix codé en dur. Pas de prix reçu → bouton d'achat désactivé.
- Confirmation obligatoire : article, prix réel, type (consommable ou permanent), bouton explicite. Aucun achat sans geste explicite du joueur.
- Erreurs gérées : réseau, annulation, achat en attente (*pending*), déjà possédé, produit indisponible, **remboursement / révocation** (le droit est retiré à la synchronisation suivante).
- Gameplay découplé : le gameplay demande `has_entitlement(&"inv_ext_1")`, il ne connaît pas la boutique.

### 13.3 Conditions d'activation en production (non remplies aujourd'hui)
1. Compte Google Play Console, application créée, produits déclarés.
2. Plugin officiel gratuit **Godot Google Play Billing** intégré et testé (export Android Gradle).
3. **Serveur de validation** (Google Play Developer API) : à choisir et à héberger.
4. Tests sur appareil réel avec des comptes testeurs de licence, scénarios achat, annulation, attente, remboursement et restauration.
5. Politique de confidentialité, conformité familles / âge, consentement publicitaire (UMP / RGPD) si un SDK pub est retenu.
6. iOS : StoreKit 2, compte Apple Developer, validation serveur App Store. **Non prévu avant le portage iOS.**

Aucune clé API n'est inventée ; aucune configuration réelle n'est livrée.

---

## 14. Tests automatisés
- Framework : **GUT 9.x** (Godot 4, MIT). Exécution headless :
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- **Unitaires** (logique pure) : table de la FSM joueur, table de l'EncounterFSM, priorités et interruptions, inventaire (vide, plein, doublons, extensions), cumul et expirations simultanées, échecs 9 / 10, verrouillage actif ou terminé, redémarrage simulé, retour en arrière de l'horloge, sauvegarde corrompue et migrations, conditions narratives, validation des JSON, boutique factice (succès, annulation, erreur réseau, remboursement, restauration).
- **Intégration** (scènes headless + `ScriptedController`) : séquences d'entrées → états attendus ; poursuite → combat → fuite ; ramassage avec inventaire plein.
- **Manuel** : scènes `sandbox/` avec affichage de débogage (état courant, priorité, ticks restants).
- ⚠️ **Godot n'est pas installé sur cette machine** : je ne pourrai lancer ni l'éditeur ni les tests tant qu'il n'est pas installé (voir §16).

---

## 15. Risques techniques

| Risque | Impact | Atténuation |
|---|---|---|
| Godot absent localement | aucun test vérifiable | installer Godot 4.x stable (version à figer) ; pas de « terminé » sans exécution |
| Désynchronisation animation / physique | coups fantômes, injustice | timings en ticks de physique dans les données ; animation asservie |
| IA bloquée sur obstacles procéduraux | poursuite cassée | `NavHint` obligatoires par chunk + test de franchissement par chunk |
| Latence et précision tactiles | ressenti mou | mémoire tampon d'entrée, zones larges, test sur appareil réel bas de gamme |
| Performances bas de gamme | chutes de FPS | rendu Compatibility, pooling, `CPUParticles2D`, atlas, profilage dès M3 |
| Horloge locale modifiable | contournement de l'énergie | documenté ; refus des retours en arrière ; serveur plus tard |
| Sauvegarde corrompue | perte de progression | écriture atomique, `.bak`, validateur avec bornes |
| Achats mal validés | fraude / litiges | validation serveur obligatoire avant la production |
| Politiques Play Store (énergie, pubs, mineurs) | rejet de l'application | pas de lootbox, alternatives gratuites, consentement |
| Contenu politique | réception sensible | univers entièrement fictif, plusieurs points de vue crédibles |
| Ressemblance avec *Vector* | risque juridique | DA silhouette propre, aucun asset ni level design repris |
| Assets de banque d'images (pngtree) | licence | jamais importés ; assets originaux |
| Dérive de périmètre | projet jamais fini | jalons courts, critères d'acceptation |

---

## 16. Décisions à valider avant de coder
1. **Version de Godot** : 4.x stable la plus récente au moment de l'installation, figée dans `project.godot` et le README.
2. **Framework de test** : GUT (proposé) ou GdUnit4.
3. **Format narratif** : JSON validé (proposé) ou Resources `.tres`.
4. **Abandon volontaire = échec** dans le mode course (proposé : oui).
5. **Perte après défaite** : objets ramassés pendant la mission perdus, objets du refuge conservés (proposé).
6. **Rendu** : Compatibility (proposé, bas de gamme Android).

---

## 17. Ordre d'implémentation et critères d'acceptation

Chaque jalon = une branche, une PR, une entrée au `CHANGELOG`, des tests verts **exécutés**.

| Jalon | Contenu | Critères d'acceptation |
|---|---|---|
| **M0** Socle | `project.godot`, InputMap, autoloads vides, GUT, `.gitignore`, README, `TESTING.md` | le projet s'ouvre sans erreur ; `gut_cmdln` passe en headless (test bidon) |
| **M1** Mouvement de base | RunnerBody, IntentFrame, HumanController (clavier + tactile), Idle/Run/Sprint/Jump/Fall/Landing/Slide, rig silhouette, `movement_sandbox` | tests de transitions verts ; aucun état incompatible simultané ; signaux `jump_started` / `landed` émis une seule fois par événement |
| **M2** Parkour avancé | Vault, WallRun, WallClimb, LedgeHang, Roll, DoubleJump soumis à un déblocage | tests par mouvement via ScriptedController ; DoubleJump refusé si non débloqué |
| **M3** Niveau | chunks, streaming, caméra, arrivée, profilage | ≥ 55 FPS sur appareil cible (à mesurer) ; aucune fuite de nœuds après 10 min |
| **M4** Combat | Hitbox/Hurtbox, AttackData, rapide/lourde, Block, contre, Dodge, Hit, Stagger, i-frames | hitbox active uniquement pendant les ticks `active` (test) ; contre dans la fenêtre seulement |
| **M5** Poursuite | PursuerAI, EncounterFSM, StealthZone, AttackTokenPool, Capture/Escape | tests de toutes les transitions autorisées et refus des autres ; aucun déplacement IA hors physique |
| **M6** Défaite / résultat | HealthComponent, jauge de capture, cinématique non graphique, écran de résultat | séquence capture → échec → écran testée |
| **M7** Sauvegarde + menus | SaveService, Settings, menu principal, SceneRouter | tests corruption / migration / atomicité ; réglages persistants |
| **M8** Inventaire + équipements | 20 emplacements, 10 effets réels, cumul, chronos pausables, HUD | tests vide / plein / doublons / expirations simultanées / pause / perte après défaite |
| **M9** Énergie | AttemptService, horloge injectable, UI de temps restant | tests 9 / 10 échecs, verrouillage actif ou terminé, redémarrage, horloge reculée |
| **M10** Narration + mission 1 | moteur de dialogue, variables, choix, « Passer », mission jouable avec conséquence visible | validation JSON ; décision sauvegardée ; conséquence observable en jeu |
| **M11** Refuges | refuge, améliorations, PNJ conditionnés | amélioration appliquée par modificateur, persistante |
| **M12** Boutique démo | StoreProvider, FakeStore, validateur factice, catalogue, confirmation, erreurs | tests succès / annulation / réseau / attente / remboursement / restauration ; aucun droit sans validation |
| **M13** Android | export, plugin de facturation (non activé), perf sur appareil | APK installé et joué sur appareil réel |
