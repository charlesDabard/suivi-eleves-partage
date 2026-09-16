import Foundation

/// Un élève : nom affiché (Prénom Nom) et une ligne de détail libre.
public struct Eleve: Codable, Identifiable, Equatable {
    public var id: String
    public var nom: String
    public var detail: String

    public init(id: String, nom: String, detail: String) {
        self.id = id
        self.nom = nom
        self.detail = detail
    }
}

/// Statut d'une case, cyclé au clic : vide → en cours → validé → vide.
public enum Statut: String, Codable, CaseIterable {
    case vide
    case encours
    case valide

    public var label: String {
        switch self {
        case .vide: return "vide"
        case .encours: return "en cours"
        case .valide: return "validé"
        }
    }

    public var suivant: Statut {
        switch self {
        case .vide: return .encours
        case .encours: return .valide
        case .valide: return .vide
        }
    }
}

/// Une colonne de statut, au nom éditable.
public struct Colonne: Codable, Identifiable, Equatable {
    public var id: String
    public var nom: String

    public init(id: String, nom: String) {
        self.id = id
        self.nom = nom
    }
}

/// État complet persisté dans `~/Documents/SuiviEleves/state.json`.
public struct EtatSuivi: Codable, Equatable {
    public var eleves: [Eleve]
    public var colonnes: [Colonne]
    /// Clé = "eleveId:colonneId". Les cases restées « vide » ne sont pas stockées.
    public var statuts: [String: Statut]
    /// Clé = "eleveId:colonneId". Note libre attachée à une case ; absente si vide.
    public var notes: [String: String]

    public init(
        eleves: [Eleve], colonnes: [Colonne], statuts: [String: Statut],
        notes: [String: String] = [:]
    ) {
        self.eleves = eleves
        self.colonnes = colonnes
        self.statuts = statuts
        self.notes = notes
    }

    /// Les `state.json` écrits avant l'ajout des notes de cases n'ont pas la clé
    /// `notes` : décodage tolérant pour ne pas perdre l'état existant.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eleves = try c.decode([Eleve].self, forKey: .eleves)
        colonnes = try c.decode([Colonne].self, forKey: .colonnes)
        statuts = try c.decode([String: Statut].self, forKey: .statuts)
        notes = try c.decodeIfPresent([String: String].self, forKey: .notes) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case eleves, colonnes, statuts, notes
    }

    public static func cle(_ eleveId: String, _ colonneId: String) -> String {
        "\(eleveId):\(colonneId)"
    }

    public func statut(_ eleveId: String, _ colonneId: String) -> Statut {
        statuts[Self.cle(eleveId, colonneId)] ?? .vide
    }

    public func note(_ eleveId: String, _ colonneId: String) -> String {
        notes[Self.cle(eleveId, colonneId)] ?? ""
    }

    /// Pose ou retire la note d'une case. Une note vide (ou espaces) supprime la clé.
    public mutating func definirNote(_ eleveId: String, _ colonneId: String, _ texte: String) {
        let k = Self.cle(eleveId, colonneId)
        if texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes.removeValue(forKey: k)
        } else {
            notes[k] = texte
        }
    }

    /// Nombre de cases renseignées (statut posé ou note) dans une colonne. Sert à ne
    /// demander confirmation de suppression que quand il y a vraiment quelque chose à perdre.
    public func casesRemplies(colonneId: String) -> Int {
        let suffixe = ":\(colonneId)"
        let avecStatut = statuts.keys.filter { $0.hasSuffix(suffixe) }
        let avecNote = notes.keys.filter { $0.hasSuffix(suffixe) }
        return Set(avecStatut).union(avecNote).count
    }

    /// Fait avancer la case au statut suivant. Retire la clé si on revient à « vide »
    /// pour garder le JSON propre.
    public mutating func cyclerStatut(_ eleveId: String, _ colonneId: String) {
        let k = Self.cle(eleveId, colonneId)
        let prochain = statut(eleveId, colonneId).suivant
        if prochain == .vide {
            statuts.removeValue(forKey: k)
        } else {
            statuts[k] = prochain
        }
    }

    // MARK: - Sérialisation

    public func encoderJSON() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    /// Décode un état, ou `nil` si le JSON est malformé (repli sur l'état par défaut côté appelant).
    public static func decoder(_ data: Data) -> EtatSuivi? {
        try? JSONDecoder().decode(EtatSuivi.self, from: data)
    }

    // MARK: - État de départ

    /// Roster d'exemple, entièrement fictif, intégré en dur pour la démonstration.
    public static func defaut() -> EtatSuivi {
        let noms = [
            "Élève 1", "Élève 2", "Élève 3", "Élève 4", "Élève 5",
            "Élève 6", "Élève 7", "Élève 8", "Élève 9", "Élève 10",
        ]
        let details = [
            "Élève 1":
                "Exemple de détail libre : parcours, entreprise, projet, remarques.",
        ]
        let eleves = noms.enumerated().map { i, nom in
            Eleve(id: "e\(i + 1)", nom: nom, detail: details[nom] ?? "")
        }
        return EtatSuivi(eleves: eleves, colonnes: colonnesParDefaut(), statuts: [:])
    }

    /// Les 3 colonnes vierges d'origine, aussi utilisées par « réinitialiser les colonnes ».
    public static func colonnesParDefaut() -> [Colonne] {
        [
            Colonne(id: "c1", nom: "Colonne 1"),
            Colonne(id: "c2", nom: "Colonne 2"),
            Colonne(id: "c3", nom: "Colonne 3"),
        ]
    }
}
