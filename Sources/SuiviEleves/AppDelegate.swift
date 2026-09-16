import AppKit
import SuiviElevesCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private let store = Store()
    private var clickMonitor: Any?
    private var dragMonitor: Any?

    func applicationDidFinishLaunching(_: Notification) {
        // Instance unique : si une autre est déjà ouverte, on la réactive et on quitte
        // (jamais deux fenêtres/icônes empilées). Pour repartir propre : reinstall.sh.
        let bundleId = Bundle.main.bundleIdentifier ?? "com.charlesdabard.SuiviEleves"
        let autres = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { $0 != NSRunningApplication.current }
        if let dejaOuverte = autres.first {
            dejaOuverte.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }

        setupMainMenu()
        setupStatusItem()
        setupWindow()
        setupClickMonitor()
        setupDragMonitor()
        // Affiche la fenêtre au centre dès le lancement si demandé
        // (arg `--show` via `open --args --show`, ou variable d'env).
        let arguments = CommandLine.arguments
        if arguments.contains("--show")
            || ProcessInfo.processInfo.environment["SUIVI_SHOW_ON_LAUNCH"] != nil
        {
            showWindowCentered()
        }
    }

    // MARK: - Menu principal (invisible mais câble Cmd+C/V/X/A)

    /// Une app `.accessory` n'a pas de barre de menus : sans menu principal, les
    /// raccourcis d'édition ne sont reliés à rien. On installe donc un menu Édition
    /// dont les raccourcis passent par la responder chain jusqu'au champ focalisé.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Masquer Suivi Élèves",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quitter Suivi Élèves",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Édition")
        editMenu.addItem(withTitle: "Annuler", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Rétablir", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(.separator())
        editMenu.addItem(
            withTitle: "Tout sélectionner",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Icône barre de menus

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // `checklist` est réservé à l'app de todo : ici la toque dit « scolaire »
            // et sa silhouette pleine reste nette à 18pt en barre de menus.
            let img = NSImage(
                systemSymbolName: "graduationcap.fill", accessibilityDescription: "Suivi élèves"
            )
            img?.isTemplate = true
            button.image = img
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    /// Clic gauche : toggle la fenêtre. Clic droit / ctrl-clic : menu de l'icône.
    @objc private func handleClick(_: Any?) {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isRight {
            showStatusItemMenu()
        } else {
            toggleWindow()
        }
    }

    private func showStatusItemMenu() {
        let menu = NSMenu()
        let reveal = NSMenuItem(
            title: "Ouvrir le dossier des données",
            action: #selector(revealData),
            keyEquivalent: ""
        )
        reveal.target = self
        menu.addItem(reveal)
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quitter Suivi élèves",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func revealData() {
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
    }

    // MARK: - Auto-masquage au clic extérieur

    private func setupClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.window.isVisible, !self.store.windowPinned {
                self.hideWindow()
            }
        }
    }

    // MARK: - Déplacement de la fenêtre au ctrl+drag

    /// Ctrl + clic gauche maintenu n'importe où dans la fenêtre : déplace la fenêtre.
    /// L'événement est avalé, donc ctrl+clic ne simule plus le clic droit à
    /// l'intérieur de la fenêtre (le clic droit deux doigts reste disponible).
    private func setupDragMonitor() {
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self = self, event.window === self.window,
                  event.modifierFlags.contains(.control)
            else { return event }
            self.window.performDrag(with: event)
            return nil
        }
    }

    // MARK: - Fenêtre

    private func setupWindow() {
        let hosting = NSHostingController(rootView: ContentView().environmentObject(store))
        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        // La fenêtre reste sur son Space (pas de `.canJoinAllSpaces`), mais
        // `.moveToActiveSpace` la fait venir sur le Space courant quand elle est
        // ordonnée au premier plan (clic sur l'icône menubar).
        win.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        win.isReleasedWhenClosed = false
        win.hidesOnDeactivate = false
        win.minSize = Store.minWindowSize
        win.maxSize = Store.maxWindowSize
        win.setContentSize(store.windowSize)
        win.delegate = self
        win.standardWindowButton(.closeButton)?.isHidden = true
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true

        window = win
        store.closeAction = { [weak self] in self?.hideWindow() }
    }

    private func hideWindow() {
        window.orderOut(nil)
        store.flush()
    }

    private func toggleWindow() {
        if window.isVisible, window.isOnActiveSpace {
            hideWindow()
        } else {
            positionWindowUnderStatusItem()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showWindowCentered() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("WINDOW_ID=\(window.windowNumber)")
        fflush(stdout)
    }

    private func positionWindowUnderStatusItem() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let rectInWindow = button.convert(button.bounds, to: nil)
        let rectOnScreen = buttonWindow.convertToScreen(rectInWindow)

        let size = window.frame.size
        var origin = NSPoint(x: rectOnScreen.midX - size.width / 2, y: rectOnScreen.minY - size.height - 6)
        let anchor = NSPoint(x: rectOnScreen.midX, y: rectOnScreen.minY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        }
        window.setFrameOrigin(origin)
    }

    // MARK: - NSWindowDelegate

    func windowDidResize(_: Notification) {
        store.windowSize = window.contentRect(forFrameRect: window.frame).size
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        hideWindow()
        return false
    }

    func applicationWillTerminate(_: Notification) {
        store.flush()
    }
}
