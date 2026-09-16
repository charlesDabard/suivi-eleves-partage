import SuiviElevesCore
import SwiftUI

// MARK: - Palette (couleurs fixes, identiques à l'outil HTML)

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private enum Palette {
    static let bg = Color(hex: 0xF6F6F7)
    static let card = Color.white
    static let line = Color(hex: 0xE6E7EB)
    static let ink = Color(hex: 0x111827)
    static let muted = Color(hex: 0x6B7280)
    static let headerBg = Color(hex: 0xFBFBFC)
    static let accent = Color(hex: 0x4F46E5)

    static let videBg = Color(hex: 0xFAFAFB)
    static let videDot = Color(hex: 0xCBD5E1)
    static let coursBg = Color(hex: 0xFEF3C7)
    static let coursDot = Color(hex: 0xF59E0B)
    static let coursInk = Color(hex: 0x92400E)
    static let valideBg = Color(hex: 0xDCFCE7)
    static let valideDot = Color(hex: 0x22C55E)
    static let valideInk = Color(hex: 0x166534)

    static func bg(_ s: Statut) -> Color {
        switch s {
        case .vide: return videBg
        case .encours: return coursBg
        case .valide: return valideBg
        }
    }

    static func ink(_ s: Statut) -> Color {
        switch s {
        case .vide: return Color(hex: 0x9CA3AF)
        case .encours: return coursInk
        case .valide: return valideInk
        }
    }
}

private let colWidth: CGFloat = 150
/// Gouttière du bouton « + colonne » à droite de l'en-tête, réservée aussi dans
/// les lignes pour que les colonnes de l'en-tête et du corps restent alignées.
private let plusGutter: CGFloat = 22

// MARK: - Vue racine

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var confirmResetColonnes = false
    /// Colonne dont la suppression attend confirmation (nil = aucun dialogue ouvert).
    @State private var colonneASupprimer: Colonne?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suivi élèves")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Palette.ink)

            tableCard

            bottomBar
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.bg)
        // La titlebar invisible réserve un inset en haut : on l'ignore pour que
        // le titre démarre au ras de la fenêtre.
        .ignoresSafeArea(.container, edges: .top)
        // Clic dans le vide (titre, fond, marges) : défocalise le champ texte
        // actif, sinon un en-tête de colonne resté focus avale les frappes.
        .contentShape(Rectangle())
        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
        .confirmationDialog(
            "Supprimer la colonne « \(colonneASupprimer?.nom ?? "") » ?",
            isPresented: Binding(
                get: { colonneASupprimer != nil },
                set: {
                    ouvert in if !ouvert {
                        colonneASupprimer = nil
                    }
                }
            ),
            presenting: colonneASupprimer
        ) { colonne in
            Button("Supprimer (\(Self.libelleCases(store.etat.casesRemplies(colonneId: colonne.id))))", role: .destructive) {
                store.supprimerColonne(colonne.id)
                colonneASupprimer = nil
            }
            Button("Annuler", role: .cancel) { colonneASupprimer = nil }
        } message: { _ in
            Text("Les statuts et les notes de cette colonne seront effacés. Les autres colonnes et les élèves ne bougent pas.")
        }
        .onExitCommand { store.closeAction?() }
    }

    /// Supprime sans rien demander une colonne vierge ; ne fait confirmer que si des
    /// statuts ou des notes seraient réellement perdus.
    private func demanderSuppression(_ colonne: Colonne) {
        if store.etat.casesRemplies(colonneId: colonne.id) == 0 {
            store.supprimerColonne(colonne.id)
        } else {
            colonneASupprimer = colonne
        }
    }

    private static func libelleCases(_ n: Int) -> String {
        n <= 1 ? "\(n) case renseignée" : "\(n) cases renseignées"
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($store.etat.eleves) { $eleve in
                        eleveRow($eleve)
                        Divider()
                    }
                }
            }
        }
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Palette.line, lineWidth: 1)
        )
        .frame(maxHeight: .infinity)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("ÉLÈVE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Palette.muted)
                .kerning(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
            ForEach($store.etat.colonnes) { $colonne in
                Divider()
                // TextField et ✕ sont côte à côte (et non superposés) : le bouton ne
                // peut donc pas voler un clic destiné à la fin du nom de colonne.
                HStack(spacing: 2) {
                    TextField("", text: $colonne.nom)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Palette.muted)
                        .frame(maxWidth: .infinity)
                    Button {
                        demanderSuppression(colonne)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Palette.muted.opacity(0.7))
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Supprimer cette colonne (ses statuts et notes aussi)")
                }
                .frame(width: colWidth)
                .padding(.horizontal, 4)
            }
            Divider()
            Button {
                store.ajouterColonne()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Palette.muted)
                    .frame(width: plusGutter, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Ajouter une colonne")
        }
        .frame(height: 34)
        .background(Palette.headerBg)
    }

    private func eleveRow(_ eleve: Binding<Eleve>) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                TextField("Prénom Nom", text: eleve.nom)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.ink)
                TextField("détail…", text: eleve.detail, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(Palette.muted)
                    .lineLimit(1 ... 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) {
                Button {
                    store.supprimerEleve(eleve.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Palette.muted)
                }
                .buttonStyle(.plain)
                .help("Supprimer cet élève")
                .padding(.trailing, 6)
            }

            ForEach(store.etat.colonnes) { colonne in
                Divider()
                StatutCell(eleveId: eleve.id, colonneId: colonne.id)
                    .frame(width: colWidth)
            }
            Color.clear.frame(width: plusGutter)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                store.ajouterEleve()
            } label: {
                Text("+ élève")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.muted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            }
            .buttonStyle(.plain)

            Button {
                confirmResetColonnes = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12))
                    .foregroundColor(Palette.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            }
            .buttonStyle(.plain)
            .help("Réinitialiser les colonnes (retour aux 3 colonnes vierges)")
            .confirmationDialog(
                "Revenir aux 3 colonnes par défaut ?",
                isPresented: $confirmResetColonnes
            ) {
                Button("Réinitialiser (efface statuts et notes)", role: .destructive) {
                    store.reinitialiserColonnes()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Toutes les colonnes, tous les statuts et toutes les notes de cases seront effacés. Les élèves sont conservés.")
            }

            Text("enregistré dans ~/Documents/SuiviEleves/state.json")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: 0x9CA3AF))

            Spacer()

            Button {
                store.windowPinned.toggle()
            } label: {
                Image(systemName: store.windowPinned ? "lock.fill" : "lock.open")
                    .font(.system(size: 13))
                    .foregroundColor(store.windowPinned ? Palette.accent : Palette.muted)
            }
            .buttonStyle(.plain)
            .help(store.windowPinned ? "Fenêtre épinglée (ne se ferme pas au clic extérieur)" : "Épingler la fenêtre")

            Button {
                store.closeAction?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Palette.muted)
            }
            .buttonStyle(.plain)
            .help("Fermer")
        }
    }
}

// MARK: - Case de statut

private struct StatutCell: View {
    @EnvironmentObject var store: Store
    let eleveId: String
    let colonneId: String

    @State private var noteVisible = false
    @State private var brouillon = ""

    var body: some View {
        let s = store.etat.statut(eleveId, colonneId)
        let note = store.etat.note(eleveId, colonneId)
        VStack(spacing: 2) {
            Button {
                store.cycler(eleveId, colonneId)
            } label: {
                HStack(spacing: 7) {
                    dot(s)
                    Text(s.label)
                        .font(.system(size: 12, weight: s == .vide ? .regular : .semibold))
                        .foregroundColor(Palette.ink(s))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // La note vit dans la case, lisible sans aucun clic ; cliquer dessus
            // ouvre l'éditeur.
            if !note.isEmpty {
                Button {
                    brouillon = note
                    noteVisible = true
                } label: {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.muted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Modifier la note")
                .padding(.horizontal, 8)
                .padding(.bottom, 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg(s))
        .overlay(alignment: .topTrailing) {
            if note.isEmpty {
                Button {
                    brouillon = note
                    noteVisible = true
                } label: {
                    Image(systemName: "note.text")
                        .font(.system(size: 10))
                        .foregroundColor(Palette.muted.opacity(0.4))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Ajouter une note à cette case")
                .padding(2)
            }
        }
        .popover(isPresented: $noteVisible, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Note")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                TextEditor(text: $brouillon)
                    .font(.system(size: 12))
                    .frame(width: 230, height: 110)
                HStack {
                    Button("Effacer") {
                        brouillon = ""
                        noteVisible = false
                    }
                    Spacer()
                    Button("OK") { noteVisible = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(10)
            // La note est enregistrée à la fermeture du popover, quel que soit
            // le chemin (OK, Effacer, clic ailleurs, Échap).
            .onDisappear { store.definirNote(eleveId, colonneId, brouillon) }
        }
    }

    @ViewBuilder
    private func dot(_ s: Statut) -> some View {
        if s == .vide {
            Circle()
                .stroke(Palette.videDot, lineWidth: 2)
                .frame(width: 8, height: 8)
        } else {
            Circle()
                .fill(s == .encours ? Palette.coursDot : Palette.valideDot)
                .frame(width: 9, height: 9)
        }
    }
}
