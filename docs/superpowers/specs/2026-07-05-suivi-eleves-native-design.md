# Suivi Élèves (app native macOS) : design

> Révisé le 2026-07-05 pour correspondre à l'app réellement construite (tableau simple,
> 100% natif SwiftUI). Remplace la première version de la spec (modèle riche avec post-its
> et types de colonnes), abandonnée quand Charles a demandé « un tableau simple, c'est tout ».

## Contexte

Outil de suivi d'élèves en direct pendant les cours. D'abord un HTML autoportant
(`_outils/suivi-eleves.html`, `localStorage`), puis reconstruit en app native menu bar
« comme QuickNotes » à la demande de Charles. Choix explicite (widget) : **100% natif
Swift/SwiftUI** avec un **JSON visible sur disque**, plutôt qu'un wrapper WebView.

## Architecture

Projet autonome, calqué sur `APP - QuickNotes`.

- **Swift Package Manager**, macOS 13+, sans Xcode (Command Line Tools suffisent).
- Trois cibles :
  - `SuiviElevesCore` : logique pure `Codable` (aucune dépendance UI, donc testable).
  - `SuiviEleves` : exécutable AppKit + SwiftUI (l'app).
  - `SelfCheck` : petit exécutable de vérification logique sans XCTest (`swift run SelfCheck`).
- **App menu bar** : `NSStatusItem` (icône `checklist`), pas d'icône Dock (`LSUIElement` +
  `setActivationPolicy(.accessory)`). Clic gauche → fenêtre flottante (`NSWindow` `.floating`,
  titlebar masquée, `fullSizeContentView`) positionnée sous l'icône. Clic droit / ctrl-clic →
  menu (ouvrir le dossier des données, quitter). Moniteur de clic global : auto-masquage au clic
  extérieur sauf si la fenêtre est épinglée (cadenas). Calqué sur `AppDelegate` de QuickNotes.
- **build.sh** : `swift build -c release` + assemblage de `SuiviEleves.app` + signature ad-hoc.
  Arg `--show` (`open SuiviEleves.app --args --show`) ou env `SUIVI_SHOW_ON_LAUNCH` : affiche la
  fenêtre au centre dès le lancement (première fois / vérification).

## Modèle (`SuiviElevesCore`)

```swift
struct Eleve: Codable, Identifiable, Equatable { var id: String; var nom: String; var detail: String }
enum Statut: String, Codable, CaseIterable { case vide, encours, valide }   // label, suivant
struct Colonne: Codable, Identifiable, Equatable { var id: String; var nom: String }
struct EtatSuivi: Codable, Equatable {
    var eleves: [Eleve]
    var colonnes: [Colonne]                 // exactement 3
    var statuts: [String: Statut]           // clé "eleveId:colonneId", cases "vide" non stockées
}
```

- `cle(_:_:)`, `statut(_:_:)`, `cyclerStatut(_:_:)` (retire la clé quand on revient à `vide`),
  `encoderJSON()` (pretty, sortedKeys), `decoder(_:)` (nil si malformé),
  `defaut()` (10 élèves fictifs d'exemple, détail générique pré-rempli sur le premier).

## Persistance (`Store`)

- Fichier unique `~/Documents/SuiviEleves/state.json`, JSON lisible.
- Chargement au démarrage ; repli sur `defaut()` si absent ou illisible ; écriture du fichier de
  départ à l'init.
- Autosave **debouncé 500 ms** (Combine `PassthroughSubject`, comme `NotesStore.wireDebouncedSave`).
  Toute mutation de `etat` déclenche la sauvegarde. `flush()` immédiat à la fermeture/sortie.
- Taille de fenêtre et épinglage persistés dans `UserDefaults`.

## Interface (`ContentView`, SwiftUI)

- Tableau pleine fenêtre : colonne **Élève** (nom + ligne détail éditables, détail multi-lignes)
  puis **3 colonnes de statut** aux en-têtes renommables. Chaque case est cliquable et cycle
  **vide → en cours → validé** (mêmes couleurs que l'HTML : gris / ambre / vert).
- Barre du bas : `+ élève`, chemin du fichier, cadenas d'épinglage, bouton fermer. `Échap` ferme.
- Suppression d'un élève : bouton au survol de sa cellule.

## Vérification

- `SelfCheck` (`swift run SelfCheck`) : roster par défaut, cycle de statut, round-trip JSON,
  JSON malformé → nil, labels, absence de tiret cadratin.
- Pas de test UI automatisé (pas de Xcode sur la machine ; `screencapture`/`ImageRenderer`
  bloqués sans permission « Enregistrement de l'écran »). Vérification visuelle par Charles au
  lancement (`open SuiviEleves.app --args --show`).

## Hors scope

- Post-its, import de roster, types de colonnes multiples, export JSON : retirés (tableau simple).
- Raccourci clavier global, synchronisation réseau/iCloud, notarisation / App Store (signature
  ad-hoc, usage perso, comme QuickNotes).
