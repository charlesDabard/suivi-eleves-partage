# Suivi Élèves

Petite app macOS native pour suivre des élèves en direct pendant un cours. Un tableau, des colonnes de statut cliquables, une note par case. Elle vit dans la barre de menus (pas d'icône dans le Dock), se compile sans Xcode, et range tout dans un fichier JSON lisible.

---

## Fonctionnalités

| Élément | Ce que ça fait |
| --- | --- |
| Icône dans la barre de menus (toque) | Clic gauche : ouvre ou ferme la fenêtre. Clic droit (ou ctrl+clic) : menu « Ouvrir le dossier des données » et « Quitter ». |
| Fenêtre | Flottante, positionnée sous l'icône. Elle se masque au clic à l'extérieur, sauf si elle est épinglée. `Échap` la ferme. |
| Cadenas | Épingle la fenêtre : elle reste ouverte même quand tu cliques ailleurs (pratique pendant un cours). |
| Nom de l'élève | Éditable directement dans la ligne. |
| Détail de l'élève | Deuxième ligne éditable, multi-lignes (parcours, entreprise, remarques). |
| Case de statut | Un clic fait tourner l'état : vide → en cours → validé → vide. Gris, ambre, vert. |
| Note de case | Icône note dans chaque case. Un clic ouvre un petit éditeur, la note est enregistrée à la fermeture. La note s'affiche directement dans la case quand elle existe. |
| `+ élève` | Ajoute une ligne élève. |
| Croix au survol d'une ligne | Supprime l'élève (et ses cases). |
| `+ colonne` | Ajoute une colonne de statut, dont le nom est éditable dans l'en-tête. |
| Croix dans l'en-tête | Supprime la colonne. Une confirmation n'est demandée que si des statuts ou des notes seraient réellement perdus. |
| `↺` | Réinitialise les colonnes : retour aux 3 colonnes vierges, statuts et notes effacés, élèves conservés. |
| Croix en bas à droite | Ferme la fenêtre. |

Quelques détails utiles :

- La fenêtre se souvient de sa taille et de son état épinglé entre deux lancements.
- Une seule instance tourne à la fois : relancer l'app réactive la fenêtre existante au lieu d'en empiler une deuxième.
- Les raccourcis d'édition standard marchent dans les champs : `Cmd+C`, `Cmd+V`, `Cmd+X`, `Cmd+A`, `Cmd+Z`.
- `Ctrl` + clic maintenu n'importe où dans la fenêtre la déplace.

---

## Installation

Prérequis : macOS 13 (Ventura) ou plus récent, et les Command Line Tools (`xcode-select --install`). Xcode n'est pas nécessaire.

```bash
git clone https://github.com/charlesDabard/suivi-eleves-partage.git
cd suivi-eleves-partage
./build.sh
open SuiviEleves.app
```

Pour l'installer dans `/Applications` et la relancer proprement :

```bash
./reinstall.sh
```

`reinstall.sh` ferme toutes les instances, reconstruit, installe `Suivi Élèves.app` (avec repli sur `~/Applications` si `/Applications` n'est pas accessible), puis lance une seule instance.

> Si le build échoue avec `plugin for module 'SwiftUIMacros' not found`, c'est une limitation récente des Command Line Tools (SDK 27 sans Xcode) qui casse les macros SwiftUI. `build.sh` gère ça tout seul : il retente automatiquement avec un SDK précédent s'il en trouve un installé.

---

## Où sont mes données

Tout est dans un seul fichier, lisible et modifiable à la main :

```
~/Documents/SuiviEleves/state.json
```

Le dossier est accessible depuis le menu de l'icône : clic droit → « Ouvrir le dossier des données ». L'écriture est automatique (débouncée d'une demi-seconde) et forcée à la fermeture. Pour repartir de zéro, il suffit de supprimer ce fichier.

Le roster livré au premier lancement est **fictif** (Élève 1 à Élève 10), il sert juste de démonstration : remplace-le par tes vrais élèves dans l'app.

---

## Vérification

La logique métier (modèle, cycle des statuts, notes, sérialisation JSON) est couverte par un petit programme de test, sans dépendance :

```bash
swift run SelfCheck
```

Il affiche une ligne `OK` par vérification et se termine par `RESULTAT: OK`.

---

## Structure du projet

```
Sources/
  SuiviElevesCore/   logique pure et testable (modèle, statuts, notes, JSON)
  SuiviEleves/       l'app : AppKit + SwiftUI (barre de menus, fenêtre, tableau)
  SelfCheck/         vérifications logiques, lancées par swift run SelfCheck
Resources/
  Info.plist         bundle de l'app
docs/                specs de design
build.sh             compile et assemble SuiviEleves.app (signature ad-hoc)
reinstall.sh         build + installation dans /Applications + relance
```

---

## Notes techniques

- **100 % natif** : Swift Package Manager, AppKit pour la barre de menus et la fenêtre, SwiftUI pour l'interface.
- **Pas de compte, pas de réseau, pas de iCloud** : aucune donnée ne quitte la machine.
- **Signature ad-hoc**, pas de notarisation : c'est une app interne, à lancer depuis le dossier ou `/Applications`.
- **App en français** : les libellés de l'interface sont en français.
