class_name ProfileServiceNode
extends Node
## Autoload « ProfileService ». Le class_name (différent du nom d'autoload)
## permet un accès typé via /root/ProfileService, y compris depuis les outils
## et les tests lancés avec -s, où les identifiants d'autoload n'existent pas.
##
## ProfileService — progression de l'histoire, capacités débloquées, refuges,
## améliorations, monnaie gagnée en jeu. Ne gère ni l'énergie ni les achats.
## Statut : capacités en mémoire (M2). Persistance au jalon M7, refuges au jalon M11.

## Capacités du protagoniste (ex. double saut), partagées avec son RunnerBody.
var abilities: AbilitySet = AbilitySet.new()
