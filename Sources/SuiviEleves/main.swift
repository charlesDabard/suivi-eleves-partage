import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// App menu bar : pas d'icône Dock, vit dans la barre de menus.
app.setActivationPolicy(.accessory)
app.run()
