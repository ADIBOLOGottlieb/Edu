# EDU

*Édu* : « course » / « pays » en ewe.

Jeu d'action-parkour 2D à défilement horizontal pour Android (portage PC prévu) : un jeune coursier clandestin fuit à travers une mégapole sous surveillance, avec des combats en pleine poursuite, des équipements temporaires, des refuges et des choix narratifs.

## État du projet

| Jalon | Contenu | État |
|---|---|---|
| M0 Socle | configuration, autoloads vides, actions d'entrée, tests | terminé : 11/11 tests verts (Godot 4.7.2, GUT 9.7.1, headless, Windows) ; non testé sur Android |
| M1 Mouvement de base | Idle, Run, Sprint, Jump, Fall, Landing, Slide ; clavier + tactile ; bac à sable | terminé : 65/65 tests verts, captures contrôlées ; non testé sur Android |
| M2 → M13 | voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) §17 | à faire |

Le personnage est une **silhouette provisoire** dessinée par code ([docs/PLACEHOLDER_ASSETS.md](docs/PLACEHOLDER_ASSETS.md)). Aucune mission n'est jouable.

## Prérequis

- **Godot 4.7.2-stable** (version standard, pas .NET) : <https://godotengine.org/download>
- **GUT 9.7.1** dans `addons/gut/` (voir [docs/TESTING.md](docs/TESTING.md))
- Git

## Lancer

```
godot --path .
```

Ou ouvrir `project.godot` dans l'éditeur, puis F5.

## Tests

Voir [docs/TESTING.md](docs/TESTING.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Décisions](docs/DECISIONS.md)
- [Règles de jeu](docs/GAME_RULES.md)
- [Journal des modifications](CHANGELOG.md)

## Commandes de développement (clavier)

| Action | Touches |
|---|---|
| Gauche / droite | A / D, ← / → |
| Saut | Espace, W, ↑ |
| Glissade | S, ↓ |
| Sprint | Maj |
| Attaque rapide / lourde | J / K |
| Blocage | L |
| Esquive | Q |
| Utiliser / objet suivant | E / Tab |
| Pause | Échap, P |

Les touches correspondent à des positions physiques : sur un clavier AZERTY, « A » est la touche Q et « W » la touche Z.
