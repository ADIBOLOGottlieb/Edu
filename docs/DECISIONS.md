# Journal des décisions

Une décision = un numéro, une date, un statut. On ne réécrit pas une décision : on en ajoute une nouvelle qui la remplace.

| # | Date | Décision | Raison | Statut |
|---|---|---|---|---|
| ADR-001 | 2026-10-16 | **Godot 4.7.2-stable** (dernière stable), figé dans `project.godot` | API stable, export Android maintenu | validée |
| ADR-002 | 2026-10-16 | **GUT 9.7.1** pour les tests, vendorisé dans `addons/gut/` | MIT, gratuit, exécution headless | validée |
| ADR-003 | 2026-10-16 | Narration en **JSON validé par des tests** | lisible par des auteurs, diffs Git propres | validée |
| ADR-004 | 2026-10-16 | En mode course, un **abandon volontaire compte comme un échec** | empêche de quitter pour contourner le compteur | validée |
| ADR-005 | 2026-10-16 | Après une défaite, les objets **ramassés pendant la mission** sont perdus ; ceux **apportés du refuge** sont conservés | enjeu sans punition excessive | validée |
| ADR-006 | 2026-10-16 | Rendu **Compatibility** (OpenGL ES 3) partout | téléphones d'entrée de gamme | validée |
| ADR-007 | 2026-10-16 | Les actions d'entrée sont **enregistrées par code** (`InputActions`) et non écrites dans `project.godot` | format sérialisé des événements fragile à éditer à la main ; testable ; prépare le remappage | validée (M0) |
| ADR-008 | 2026-10-16 | **Git LFS reporté** : pas d'asset binaire pour l'instant | évite une dépendance d'outil inutile ; à réévaluer au premier lot d'assets | validée (M0) |
| ADR-009 | 2026-10-16 | `untyped_declaration` = **erreur** ; addons exclus | impose le GDScript typé demandé | validée (M0) |
| ADR-010 | 2026-10-16 | Les images de référence fournies servent **d'inspiration uniquement** ; l'image de skyline (filigrane pngtree) n'est jamais importée | licence de banque d'images | validée |
| ADR-011 | 2026-10-16 | `core.longpaths=true` dans la configuration Git locale sur Windows | chemins de travail trop longs pour Git | note locale |
| ADR-012 | 2026-10-16 | La locomotion est découpée en `MovementDecider` (quel état ?) et `LocomotionMotor` (quelle vitesse ?), classes pures dans `src/core/player/`, au lieu d'un script « motor » par mouvement sous `gameplay/actors/motor/` comme prévu dans ARCHITECTURE §1 | testable sans physique ; un seul endroit par responsabilité. À réévaluer si un mouvement M2 devient trop gros | validée (M1) |
| ADR-013 | 2026-10-16 | Les valeurs par défaut de `MoveTuning` vivent dans le script ; un `.tres` ne contient que les valeurs **différentes** (comportement natif de Godot). `player_move.tres` est donc vide pour l'instant | évite deux sources de vérité ; le poursuivant (M5) aura son propre `.tres` avec ses écarts | validée (M1) |
| ADR-014 | 2026-10-16 | Mémoire tampon de 0,12 s pour la glissade et transition `LANDING → SLIDE` | découvert au contrôle visuel : un appui pendant une réception était perdu | validée (M1) |
| ADR-016 | 2026-10-16 | Capteurs de parkour par **requêtes de rayons** depuis le code (`ParkourSensors`), pas de RayCast2D dans la scène | aucune configuration par niveau ; mêmes capteurs pour le joueur et les poursuivants ; testé avec la vraie physique | validée (M2) |
| ADR-017 | 2026-10-16 | Franchissement **automatique** (pas de bouton) dès qu'un obstacle de 12 à 50 px est devant et qu'on court vers lui | commandes tactiles réduites ; le saut garde la priorité pour qui veut sauter | validée (M2) |
| ADR-018 | 2026-10-16 | Ressources aériennes rechargées **au sol** : 1 course murale, 1,2 s d'escalade, 1 double saut ; rebord = recharge l'escalade et le double saut | empêche l'escalade infinie d'un même mur | validée (M2) |
| ADR-019 | 2026-10-16 | Glisse pendant une réception **dure** → roulade ; pendant une réception **douce** → glissade | complète ADR-014 ; la roulade est la réponse au risque de chute | validée (M2) |
| ADR-020 | 2026-10-16 | `ProfileService` porte `class_name ProfileServiceNode` ; les scènes qui doivent tourner aussi dans les outils `-s` le récupèrent par `/root/ProfileService` | en mode `-s`, Godot instancie les autoloads mais n'enregistre pas leurs identifiants globaux (compilation refusée) | validée (M2) |
| ADR-021 | 2026-10-16 | Suspension : le corps est **replacé** contre le rebord (correction bornée par la fenêtre de saisie, ≤ ~30 px) | mains alignées sur le rebord quel que soit le tick de détection. La règle « pas de téléportation » des poursuivants (M5) vise les déplacements arbitraires, pas cet ajustement local | validée (M2) |
| ADR-022 | 2026-10-16 | Tronçons décrits par des **rectangles en données** (`ChunkLayout`), sol à y = 0 en entrée et en sortie | enchaînement libre ; édition sans code ; validation automatique. Limite assumée : pas de variation d'altitude entre tronçons (à revoir pour des parcours sur les toits) | validée (M3) |
| ADR-023 | 2026-10-16 | Réserve de tronçons par identifiant, bornée (2 par tronçon), tronçons retirés de l'arbre hors champ | mémoire constante quelle que soit la distance | validée (M3) |
| ADR-024 | 2026-10-16 | Chute hors du niveau = replacement au début du tronçon, en attendant défaite / capture (M6) | jouable dès maintenant sans préjuger des règles de défaite | provisoire (M3) |
| ADR-025 | 2026-10-16 | Dessin regroupé : un `_draw` par tronçon, un pour la skyline, au lieu d'un `Polygon2D` par bloc | 123 → 8 appels de dessin par image, essentiel sur mobile d'entrée de gamme | validée (M3) |
| ADR-026 | 2026-10-17 | **Altitude variable** : `ChunkLayout.exit_y`, tronçons empilés en hauteur, bande d'altitude dans le séquenceur | remplace la limite d'ADR-022, à la demande de l'utilisateur (parcours sur les toits plus complexes) | validée (M3b) |
| ADR-027 | 2026-10-17 | Validation par **graphe de franchissement** (trajectoire de saut réelle, escalade, rebord de poutre) | les règles « trou / mur » au niveau du sol ne suffisent plus avec l'altitude | validée (M3b) |
| ADR-028 | 2026-10-17 | Chaque tronçon livré doit être **traversé par le pilote automatique** dans les tests | preuve de jouabilité en conditions réelles ; a révélé le bogue de l'arrivée en altitude. Coût : la suite passe à ~4 min | validée (M3b) |
| ADR-029 | 2026-10-17 | 5 paliers de difficulté (0 à 4), un palier tous les 5 tronçons en course aléatoire | progression demandée par l'utilisateur ; le palier 4 arrive vers 550 m | validée (M3b) |
| ADR-015 | 2026-10-16 | Silhouette provisoire **procédurale** (dessin par code + poses en données) plutôt qu'un AnimationPlayer avec des sprites vides | aucun asset disponible ; garde la séparation données / logique ; jetable | validée (M1) |
