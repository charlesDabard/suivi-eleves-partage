import Foundation
import SuiviElevesCore

// Vérification de la logique pure (sans XCTest, machine en Command Line Tools).
// Lancer : swift run SelfCheck

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    print((cond ? "OK   " : "FAIL ") + msg)
    if !cond {
        failures += 1
    }
}

let d = EtatSuivi.defaut()
check(d.eleves.count == 10, "10 élèves")
check(d.colonnes.count == 3, "3 colonnes")
check(d.eleves.first?.nom == "Élève 1", "1er élève = Élève 1")
check(d.eleves.first?.detail.contains("Exemple") == true, "détail du 1er élève = exemple générique")
check(d.eleves[1].detail == "", "2e élève sans détail par défaut")
check(!d.eleves.contains { $0.detail.contains("—") || $0.nom.contains("—") }, "aucun tiret cadratin")

var e = EtatSuivi.defaut()
let id = e.eleves[0].id
let c = e.colonnes[0].id
check(e.statut(id, c) == .vide, "statut de départ = vide")
e.cyclerStatut(id, c); check(e.statut(id, c) == .encours, "clic 1 -> en cours")
e.cyclerStatut(id, c); check(e.statut(id, c) == .valide, "clic 2 -> validé")
e.cyclerStatut(id, c); check(e.statut(id, c) == .vide, "clic 3 -> vide")
check(e.statuts[EtatSuivi.cle(id, c)] == nil, "case revenue à vide retirée du dictionnaire")
check(EtatSuivi.cle("e1", "c2") == "e1:c2", "clé statut = eleveId:colonneId")

var e2 = EtatSuivi.defaut()
e2.cyclerStatut(e2.eleves[1].id, e2.colonnes[2].id)
e2.eleves[3].detail = "groupe A"
do {
    let data = try e2.encoderJSON()
    check(EtatSuivi.decoder(data) == e2, "round-trip JSON identique")
} catch {
    check(false, "encodage JSON a échoué: \(error)")
}

check(EtatSuivi.decoder(Data("{ pas du json".utf8)) == nil, "JSON malformé -> nil (repli)")
check(Statut.encours.label == "en cours", "label statut")

// Notes de cases
var n = EtatSuivi.defaut()
let ne = n.eleves[0].id
let nc = n.colonnes[1].id
check(n.note(ne, nc) == "", "note de départ vide")
n.definirNote(ne, nc, "test")
check(n.note(ne, nc) == "test", "note posée puis relue")
n.definirNote(ne, nc, "   \n")
check(n.notes[EtatSuivi.cle(ne, nc)] == nil, "note blanche/espaces retirée du dictionnaire")

// Un state.json d'avant les notes (clé `notes` absente) doit se décoder tel quel.
do {
    var ancien = EtatSuivi.defaut()
    ancien.cyclerStatut(ancien.eleves[0].id, ancien.colonnes[0].id)
    let data = try ancien.encoderJSON()
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    json.removeValue(forKey: "notes")
    let sansNotes = try JSONSerialization.data(withJSONObject: json)
    let relu = EtatSuivi.decoder(sansNotes)
    check(relu != nil, "state.json legacy (sans clé notes) accepté")
    check(relu?.notes.isEmpty == true, "state.json legacy -> notes vides")
    check(relu?.statuts == ancien.statuts, "state.json legacy -> statuts préservés")
} catch {
    check(false, "préparation du state.json legacy a échoué: \(error)")
}

/// Colonnes par défaut, réutilisées par « réinitialiser »
let defCols = EtatSuivi.colonnesParDefaut()
check(defCols.map(\.id) == ["c1", "c2", "c3"], "colonnes par défaut = c1/c2/c3")
check(EtatSuivi.defaut().colonnes == defCols, "defaut() utilise les colonnes par défaut")

/// Round-trip avec notes
var e3 = EtatSuivi.defaut()
e3.definirNote(e3.eleves[2].id, e3.colonnes[0].id, "à revoir lundi")
do {
    let data = try e3.encoderJSON()
    check(EtatSuivi.decoder(data) == e3, "round-trip JSON avec notes identique")
} catch {
    check(false, "encodage JSON avec notes a échoué: \(error)")
}

/// Comptage des cases d'une colonne : décide si la suppression demande confirmation.
var e4 = EtatSuivi.defaut()
let c1 = e4.colonnes[0].id
let c2 = e4.colonnes[1].id
check(e4.casesRemplies(colonneId: c1) == 0, "colonne vierge -> 0 case remplie")
e4.cyclerStatut(e4.eleves[0].id, c1)
check(e4.casesRemplies(colonneId: c1) == 1, "1 statut posé -> 1 case remplie")
e4.definirNote(e4.eleves[0].id, c1, "note sur la même case")
check(e4.casesRemplies(colonneId: c1) == 1, "statut + note sur la même case -> compté 1 fois")
e4.definirNote(e4.eleves[1].id, c1, "note seule")
check(e4.casesRemplies(colonneId: c1) == 2, "note seule sur une autre case -> 2")
check(e4.casesRemplies(colonneId: c2) == 0, "les cases d'une colonne ne comptent pas pour une autre")
// Le suffixe ne doit pas confondre une colonne avec une autre dont l'id la contient.
var e5 = EtatSuivi(
    eleves: [Eleve(id: "e1", nom: "X", detail: "")],
    colonnes: [Colonne(id: "c1", nom: "A"), Colonne(id: "xc1", nom: "B")],
    statuts: ["e1:xc1": .valide]
)
check(e5.casesRemplies(colonneId: "c1") == 0, "id 'c1' ne capte pas les cases de 'xc1'")
check(e5.casesRemplies(colonneId: "xc1") == 1, "id 'xc1' capte bien sa propre case")
e5.definirNote("e1", "c1", "n")
check(e5.casesRemplies(colonneId: "c1") == 1, "cas conforme accepté après le cas de refus")

print(failures == 0 ? "\nRESULTAT: OK" : "\nRESULTAT: \(failures) ECHEC")
exit(Int32(failures == 0 ? 0 : 1))
