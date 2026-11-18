import SwiftUI

@main
struct SumiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Sin esto, al abrir la app sola macOS muestra de inmediato el panel para elegir archivo.
        UserDefaults.standard.register(defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
    }

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
                .frame(minWidth: 520, minHeight: 400)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 760)
        .commands { SumiCommands() }

        Settings {
            SettingsView()
        }
    }
}

/// Avisos del menú. Solo los atiende la ventana que está al frente.
extension Notification.Name {
    static let sumiToggleEdit = Notification.Name("sumi.toggleEdit")
    static let sumiToggleIndex = Notification.Name("sumi.toggleIndex")
    static let sumiQuickOpen = Notification.Name("sumi.quickOpen")
}

struct SumiCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Abrir rápido…") { NotificationCenter.default.post(name: .sumiQuickOpen, object: nil) }
                .keyboardShortcut("k")
        }
        CommandGroup(after: .textEditing) {
            Button("Buscar…") {
                let item = NSMenuItem()
                item.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
                NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: item)
            }
            .keyboardShortcut("f")
        }
        CommandGroup(before: .toolbar) {
            Button("Leer o editar") { NotificationCenter.default.post(name: .sumiToggleEdit, object: nil) }
                .keyboardShortcut("e")
            Button("Mostrar u ocultar índice") { NotificationCenter.default.post(name: .sumiToggleIndex, object: nil) }
                .keyboardShortcut("\\")
            Divider()
        }
    }
}

/// Guarda la ventana de una vista, para saber si es la que está al frente.
final class WindowBox {
    weak var window: NSWindow?
    /// La ventana del documento que está al frente. Se usa la principal porque a veces
    /// ninguna ventana queda como "key" (por ejemplo, justo después de cambiar a editar).
    var isKey: Bool {
        guard let window else { return false }
        if window.isKeyWindow || window.isMainWindow { return true }
        let front = NSApp.orderedWindows.first { $0.isVisible && $0.canBecomeMain }
        return front === window
    }
}

struct WindowReader: NSViewRepresentable {
    let box: WindowBox

    final class ReaderNSView: NSView {
        var box: WindowBox?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            box?.window = window
        }
    }

    func makeNSView(context: Context) -> ReaderNSView {
        let view = ReaderNSView()
        view.box = box
        return view
    }

    func updateNSView(_ view: ReaderNSView, context: Context) {
        view.box = box
        if box.window == nil { box.window = view.window }
    }
}
