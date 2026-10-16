# Règles de jeu (définitions de référence)

Ce fichier est la **seule** définition des règles ci-dessous. Le code et les tests s'y réfèrent. Toute modification passe par une nouvelle entrée de `DECISIONS.md`.

## R1 — Échec d'une tentative (mode course)

Une tentative du **mode course** est un échec lorsqu'elle atteint l'état `MISSION_FAILED`, quelle qu'en soit la cause :
- capture sans évasion ;
- défaite ;
- **abandon volontaire** en cours de partie (ADR-004) ;
- fermeture de l'application pendant une tentative : l'échec est enregistré au démarrage suivant (marqueur `attempt_in_progress`).

Ne sont **pas** des échecs : les missions de l'histoire principale, les sorties depuis le refuge ou les menus.

## R2 — Récupération

- 10 échecs dans le mode course → nouvelles tentatives bloquées pendant **6 heures**, à compter du 10ᵉ échec.
- À la fin de la période, le compteur repart à 0.
- Le temps est mesuré en UTC. Un retour en arrière de l'horloge n'accorde jamais de temps.
- Limite connue : une horloge locale modifiable **ne prévient pas** la fraude.

## R3 — Perte d'objets après une défaite (ADR-005)

- Objets ramassés **pendant** la mission (`lost_on_defeat = true`) : perdus.
- Objets **apportés du refuge** : conservés.
- Effets actifs : tous expirent à la fin de la mission, victoire ou défaite.

## R4 — Santé ≠ énergie

La santé du personnage est locale à une mission et repart au maximum à chaque mission. Elle n'a aucun lien avec le compteur d'échecs (R1–R2).

*Statut : règles définies, implémentation aux jalons M6 (défaite), M8 (objets) et M9 (énergie).*
