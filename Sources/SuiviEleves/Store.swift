import AppKit
import Combine
import Foundation
import SuiviElevesCore

/// Source de vérité de l'app. Charge/écrit `state.json`, expose l'état à SwiftUI,
/// et sauvegarde toute mutation avec un débounce (calqué sur `NotesStore` de QuickNotes).
final class Store: ObservableObject {
    /// Toute mutation (via l'UI) déclenche une sauvegarde debouncée.
    @Published var etat: EtatSuivi {
        didSet { saveSubject.send(()) }
    }

    /// Fenêtre épinglée : reste ouverte au clic extérieur (cadenas fermé).
    @Published var windowPinned: Bool {
        didSet { defaults.set(windowPinned, forKey: pinnedKey) }
    }

    let folderURL: URL
    let fileURL: URL

    /// Settée par l'AppDelegate : permet à la vue de masquer la fenêtre.
    var closeAction: (() -> Void)?

    static let minWindowSize = CGSize(width: 560, height: 360)
    static let maxWindowSize = CGSize(width: 1500, height: 1100)
    static let defaultWindowSize = CGSize(width: 900, height: 640)

    private let saveSubject = PassthroughSubject<Void, Never>()
    private var saveCancellable: AnyCancellable?
    private let defaults = UserDefaults.standard
    private let pinnedKey = "windowPinned"
    private let winWKey = "windowWidth"
    private let winHKey = "windowHeight"

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folderURL = docs.appendingPathComponent("SuiviEleves", isDirectory: true)
        fileURL = folderURL.appendingPathComponent("state.json")
        windowPinned = defaults.object(forKey: pinnedKey) as? Bool ?? false

        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let dejaLa = FileManager.default.fileExists(atPath: fileURL.path)
        if dejaLa, let data = try? Data(contentsOf: fileURL), let e = EtatSuivi.decoder(data) {
            etat = e
        } else {
            // Premier lancement (ou fichier illisible) : roster de départ.
            etat = EtatSuivi.defaut()
        }

        wireDebouncedSave()

        // didSet ne se déclenche pas pendant l'init : on écrit le fichier de départ ici.
        if !dejaLa {
            persist()
        }
    }

    private func wireDebouncedSave() {
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.persist() }
    }

    private func persist() {
        guard let data = try? etat.encoderJSON() else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Écriture immédiate (à la fermeture / à la sortie).
    func flush() {
        persist()
    }

    // MARK: - Taille de fenêtre persistée

    var windowSize: CGSize {
        get {
            let w = defaults.object(forKey: winWKey) as? Double ?? Double(Self.defaultWindowSize.width)
            let h = defaults.object(forKey: winHKey) as? Double ?? Double(Self.defaultWindowSize.height)
            return CGSize(
                width: min(max(w, Self.minWindowSize.width), Self.maxWindowSize.width),
                height: min(max(h, Self.minWindowSize.height), Self.maxWindowSize.height)
            )
        }
        set {
            defaults.set(Double(newValue.width), forKey: winWKey)
            defaults.set(Double(newValue.height), forKey: winHKey)
        }
    }

    // MARK: - Mutations UI

    func cycler(_ eleveId: String, _ colonneId: String) {
        etat.cyclerStatut(eleveId, colonneId)
    }

    func ajouterEleve() {
        let id = "e-\(Int(Date().timeIntervalSince1970 * 1000))"
        etat.eleves.append(Eleve(id: id, nom: "", detail: ""))
    }

    func supprimerEleve(_ id: String) {
        etat.eleves.removeAll { $0.id == id }
        etat.statuts = etat.statuts.filter { !$0.key.hasPrefix("\(id):") }
        etat.notes = etat.notes.filter { !$0.key.hasPrefix("\(id):") }
    }

    func ajouterColonne() {
        let id = "c-\(Int(Date().timeIntervalSince1970 * 1000))"
        etat.colonnes.append(Colonne(id: id, nom: "Colonne \(etat.colonnes.count + 1)"))
    }

    func supprimerColonne(_ id: String) {
        etat.colonnes.removeAll { $0.id == id }
        etat.statuts = etat.statuts.filter { !$0.key.hasSuffix(":\(id)") }
        etat.notes = etat.notes.filter { !$0.key.hasSuffix(":\(id)") }
    }

    /// Retour aux 3 colonnes vierges d'origine : tous les statuts et notes de cases
    /// sont effacés, les élèves sont conservés. Appelé après confirmation UI.
    func reinitialiserColonnes() {
        etat.colonnes = EtatSuivi.colonnesParDefaut()
        etat.statuts = [:]
        etat.notes = [:]
    }

    func definirNote(_ eleveId: String, _ colonneId: String, _ texte: String) {
        etat.definirNote(eleveId, colonneId, texte)
    }
}
