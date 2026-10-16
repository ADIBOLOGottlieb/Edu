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
| ADR-015 | 2026-10-16 | Silhouette provisoire **procédurale** (dessin par code + poses en données) plutôt qu'un AnimationPlayer avec des sprites vides | aucun asset disponible ; garde la séparation données / logique ; jetable | validée (M1) |
