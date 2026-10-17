# Proposition — EDU, le tour du monde en parkour

Statut : **validée** le 2026-10-17 (Lomé ville de départ, énergie 1 point / 72 min). M3d réalisé. Rien de ce document n'est implémenté,
sauf mention contraire. Il reprend l'idée de l'utilisateur, l'adapte au jeu et la
découpe en jalons.

## 1. L'idée en une phrase

**EDU** (« la course » en ewe) : un traceur traverse les toits et les rues de grandes
villes du monde, de Lomé à Rio, poursuivi, en enchaînant de vraies figures de parkour ;
chaque ville a ses obstacles, ses monuments, sa musique et son histoire.

## 2. Carte du monde et villes

Le joueur choisit sa ville sur une **carte du monde**. Chaque ville est une *carte*
jouable composée de plusieurs parcours (5 à 8), du plus facile au plus dur.

| Ville | Monument en arrière-plan | Obstacles typiques (premier plan) | Mécanique mise en avant |
|---|---|---|---|
| **Lomé** (Togo), ville de départ | Monument de l'Indépendance | toits de tôle, étals du grand marché, zémidjans garés, palmiers, câbles électriques | apprentissage : course, saut, glissade |
| **Cotonou** (Bénin) | Statue de l'Amazone | marché Dantokpa (bâches, caisses), passerelles, échafaudages | franchissements enchaînés |
| **Abidjan** (Côte d'Ivoire) | tours du Plateau ; basilique de Yamoussoukro en ville bonus | ponts sur la lagune, chantiers, grues, façades vitrées | escalade, course murale |
| **Dakar** (Sénégal) | Monument de la Renaissance africaine | corniche, rochers, bus colorés (« cars rapides ») | vent latéral sur la corniche |
| **Rio de Janeiro** (Brésil) | Christ Rédempteur (voir §8) | favelas en escaliers, toits étroits, Copacabana | sauts de précision, dénivelés |
| Puis, par mises à jour | Paris, New York, Le Caire, Tokyo, Nairobi, Marrakech… | métro aérien, taxis, néons, souks | une mécanique nouvelle par ville |

Débloquer une ville : terminer la précédente **ou** atteindre un nombre d'étoiles.
Chaque parcours donne 1 à 3 étoiles (arrivée, temps, figures).

**Amélioration proposée — « EDU » veut aussi dire apprendre** : dans chaque ville,
des *cartes postales* à collectionner (cachées sur les parcours) racontent en deux
phrases l'histoire du monument, du quartier ou d'une figure locale. Un album les
réunit. C'est un vrai point différenciant et une raison de rejouer.

## 3. Décor urbain réaliste (style Vector)

Aujourd'hui les obstacles sont des rectangles noirs. Proposition :

- **Premier plan en silhouette noire** (comme Vector et le coureur) mais avec des
  **formes réelles** : climatiseurs, châteaux d'eau, cheminées, antennes, garde-corps,
  panneaux publicitaires, échafaudages, grues, escaliers de secours, conteneurs,
  bus, voitures, barrières, abribus.
- **Chaque bloc de tronçon reçoit un type d'objet** (`ChunkLayout` : `kind` =
  climatiseur, conteneur, toit, mur, poutre…) : la collision reste le rectangle testé,
  l'image devient l'objet réel. Les 24 tronçons et leurs tests de jouabilité restent
  valables.
- **Arrière-plans en couches** (parallaxe) aux couleurs de la ville et de l'heure :
  rues, immeubles, puis la ligne d'horizon avec le monument.
- **Sources d'images** : objets 3D CC0 (même filière que le coureur, rendus en
  silhouette) ou dessins originaux. Jamais d'images de banques ni de captures d'autres jeux.

## 4. Points, pièces et skins

- À chaque parcours le joueur gagne des **pièces** : arrivée + distance + **points de
  style** (figures, enchaînements sans pause, multiplicateur de combo) + bonus « sans
  mort » + cartes postales trouvées.
- **Skins** (apparence uniquement, **jamais d'avantage de jeu**) :
  - achetables en **pièces** : tenues de base, couleurs, accessoires (casquette,
    capuche, sac, bandeau) ;
  - **premium en euros** : tenues de ville (maillot de foot local, tenue de carnaval de
    Rio, motifs wax stylisés…), traînées de mouvement, animations de victoire.
- Prix toujours affichés en euros TTC, confirmation explicite avant achat, **aucun
  objet aléatoire payant** (pas de « coffres ») : règle déjà fixée pour la v1.

## 5. Énergie (vies)

Règle demandée : **5 morts → énergie épuisée → recharge en 6 h**, énergie achetable en euros.

Adaptation proposée (même esprit, moins frustrante, mieux notée sur les stores) :
- 5 points d'énergie ; une mort en coûte 1 ; **1 point revient toutes les 72 min**
  (plein en 6 h), au lieu d'attendre 6 h d'un coup ;
- recharge **achetable en euros** (plein immédiat) ;
- **passe « énergie illimitée »** (achat unique ou mensuel), apprécié des joueurs réguliers ;
- l'entraînement et les parcours déjà terminés à 3 étoiles ne coûtent rien ;
- option à décider : une recharge gratuite par jour contre une publicité volontaire.

⚠ Écart avec le jalon M9 existant (« 9 / 10 échecs ») : la nouvelle règle (5 / 6 h)
la remplacerait. À confirmer.

## 6. Autres idées pour rendre le jeu attractif

1. **Poursuite** (déjà prévue en M5) : un poursuivant par ville (vigile, drone, rival).
2. **Défi du jour** : un parcours aléatoire commun à tous, classement mondial.
3. **Fantôme** : courir contre son meilleur passage (ou celui d'un ami).
4. **Classements** par ville et par pays.
5. **Événements** liés aux fêtes nationales (27 avril au Togo, 1er août au Bénin…),
   avec un skin offert.
6. **Quêtes et succès** : « 10 kong vaults sans toucher le sol », « finir Lomé sans mourir »…
7. **Musique locale** par ville (afrobeat, coupé-décalé, mbalax, samba), artistes
   locaux sous licence.
8. **Mode photo** et **rediffusion** de sa meilleure figure, partageable.
9. **Histoire** (déjà prévue en M10) : le coureur fait le tour du monde pour une raison
   (retrouver quelqu'un, gagner la course légendaire « EDU »).
10. **Accessibilité** : vibrations, aide au timing, daltonisme, commandes à une main.

## 7. Découpage en jalons (proposition)

| Jalon | Contenu |
|---|---|
| **M3c** Coureur 3D *(fait, branche `m3c/silhouette-3d`)* | mannequin humain + capture de mouvement, glissade et escalade réelles |
| **M3d** Décor urbain + Lomé | objets réels par type de bloc, arrière-plans en couches, première ville jouable |
| M4 à M6 | combat, poursuite, défaite (inchangés) |
| **M7** Sauvegarde + menus + **carte du monde** | choix de la ville, étoiles, déblocage |
| **M7b** Pièces + skins en pièces | gains par parcours, garde-robe, skins appliqués au mannequin 3D |
| M8 | inventaire (inchangé) |
| **M9** Énergie | règle 5 / 72 min / 6 h (si validée) |
| M10, M11 | narration, refuges |
| **M12** Boutique | skins premium, énergie, passe ; **fournisseur factice** d'abord (règle déjà fixée) |
| M13 | Android ; achats réels activés seulement après validation |
| **M14+** | Cotonou, Abidjan, Dakar, Rio… une ville par mise à jour |

## 8. Points juridiques à vérifier (avant toute sortie commerciale)

- Plusieurs monuments sont des **œuvres récentes protégées par le droit d'auteur**
  (auteurs vivants ou décédés depuis moins de 70 ans) : par exemple le Monument de la
  Renaissance africaine, la statue de l'Amazone, la basilique de Yamoussoukro, le
  Monument de l'Indépendance du Togo.
- L'image du **Christ Rédempteur** est gérée par l'archidiocèse de Rio, qui demande
  une autorisation pour les usages commerciaux.
- Proposition : des **évocations stylisées originales** (silhouettes simplifiées, pas
  des copies fidèles) et une **vérification par un juriste**, pays par pays (liberté de
  panorama), avant la sortie ; demander les autorisations si nécessaire.
- Achats en euros : facturation obligatoire des stores (Google Play), règles de
  protection des mineurs et d'affichage des prix dans l'UE.

## 9. Décisions attendues

1. Valider la liste et l'ordre des villes (Lomé en ville de départ ?).
2. Valider la règle d'énergie adaptée (1 point / 72 min) ou garder « 6 h d'un coup ».
3. Valider l'ajout des jalons M3d, M7b, M14+.
4. Choisir le prochain jalon : **M3d (décor urbain + Lomé)** recommandé.
