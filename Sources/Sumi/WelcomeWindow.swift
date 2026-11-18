import SwiftUI
import UniformTypeIdentifiers

/// Muestra la pantalla de inicio cuando la app se abre sin ningún archivo.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var welcome: NSWindow?

    private var launching = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI crea un documento "Sin título" al abrir la app sin archivo, sin consultar al delegado.
        // Mientras la app arranca, ese documento vacío se cierra apenas aparece y se muestra la pantalla de inicio.
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, self.launching, let window = note.object as? NSWindow else { return }
            if self.closeIfBlankUntitled(window) { self.showWelcome() }
        }
        // Se espera un momento por si la app se abrió con un archivo (doble clic en Finder).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            NSApp.windows.forEach { _ = self.closeIfBlankUntitled($0) }
            self.showWelcomeIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.launching = false }
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let closing = note.object as? NSWindow, closing !== self.welcome else { return }
            // Al cerrar el último documento, vuelve la pantalla de inicio.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.showWelcomeIfNeeded() }
        }
    }

    /// Cierra la ventana si es un documento nuevo, sin archivo y sin cambios. Devuelve si la cerró.
    private func closeIfBlankUntitled(_ window: NSWindow) -> Bool {
        guard window !== welcome,
              let document = NSDocumentController.shared.document(for: window),
              document.fileURL == nil, !document.isDocumentEdited else { return false }
        window.alphaValue = 0
        document.close()
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWelcome() }
        return false
    }

    private var hasDocumentWindows: Bool {
        NSApp.windows.contains { $0.isVisible && $0 !== welcome && $0.canBecomeMain && !($0 is NSPanel) }
    }

    private func showWelcomeIfNeeded() {
        if !hasDocumentWindows { showWelcome() }
    }

    func showWelcome() {
        if let welcome {
            welcome.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Sumi"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 460)
        window.contentView = NSHostingView(rootView: WelcomeView(close: { [weak self] in self?.closeWelcome() }))
        window.center()
        welcome = window
        window.makeKeyAndOrderFront(nil)
    }

    func closeWelcome() {
        welcome?.close()
        welcome = nil
    }
}

/// Pantalla de inicio: soltar un archivo, abrirlo con el Finder o elegir uno reciente.
struct WelcomeView: View {
    let close: () -> Void

    @AppStorage(Pref.tema) private var tema = "sistema"
    @Environment(\.colorScheme) private var scheme

    // State directo porque @State necesita Xcode para compilar.
    private let targetedState = State(initialValue: false)
    private let showQuickOpenState = State(initialValue: false)
    private let windowBox = State(initialValue: WindowBox())

    private var targeted: Bool {
        get { targetedState.wrappedValue }
        nonmutating set { targetedState.wrappedValue = newValue }
    }
    private var showQuickOpen: Bool {
        get { showQuickOpenState.wrappedValue }
        nonmutating set { showQuickOpenState.wrappedValue = newValue }
    }

    private static let extensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    private var recents: [URL] {
        Array(NSDocumentController.shared.recentDocumentURLs
            .filter { Self.extensions.contains($0.pathExtension.lowercased()) }
            .prefix(5))
    }

    var body: some View {
        let p = Palette.resolve(tema, scheme)
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(p.color(p.faint))
                Text("Suelta un archivo .md aquí")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(p.color(p.text))
                HStack(spacing: 4) {
                    Text("o ábrelo con")
                    KeyCap(text: "⌘O", palette: p)
                    Text(", o busca uno con")
                    KeyCap(text: "⌘K", palette: p)
                }
                .font(.system(size: 13))
                .foregroundStyle(p.color(p.muted))
                Button(action: openPanel) {
                    Text("Abrir archivo…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(p.color(p.bg))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(p.color(p.text)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Abrir archivo")
                .padding(.top, 6)
            }
            .frame(width: 460)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(p.color(targeted ? p.accent : p.line),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .background(RoundedRectangle(cornerRadius: 16).fill(p.color(p.hover)).opacity(targeted ? 1 : 0))
            )

            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ABIERTOS HACE POCO")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(0.6)
                        .foregroundStyle(p.color(p.faint))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                    ForEach(recents, id: \.self) { url in
                        RecentRow(url: url, palette: p) { open([url]) }
                    }
                }
                .frame(width: 460)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(p.color(p.bg))
        .ignoresSafeArea()
        .onDrop(of: [.fileURL], isTargeted: targetedState.projectedValue, perform: handleDrop)
        .overlay {
            if showQuickOpen {
                QuickOpenView(palette: p, currentURL: nil) { showQuickOpen = false }
            }
        }
        .background(WindowReader(box: windowBox.wrappedValue))
        .onReceive(NotificationCenter.default.publisher(for: .sumiQuickOpen)) { _ in
            if windowBox.wrappedValue.isKey { showQuickOpen = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            // Si se abrió un documento (desde aquí o desde Abrir rápido), la pantalla de inicio se cierra.
            guard let window = note.object as? NSWindow, window !== windowBox.wrappedValue.window,
                  NSDocumentController.shared.document(for: window) != nil else { return }
            close()
        }
        .preferredColorScheme(Palette.forcedScheme(tema))
    }

    private func openPanel() {
        NSDocumentController.shared.openDocument(nil)
    }

    private func open(_ urls: [URL]) {
        for url in urls {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, Self.extensions.contains(url.pathExtension.lowercased()) else { return }
                DispatchQueue.main.async { open([url]) }
            }
        }
        return accepted
    }
}

private struct KeyCap: View {
    let text: String
    let palette: Palette

    var body: some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.color(palette.line)))
    }
}

private struct RecentRow: View {
    let url: URL
    let palette: Palette
    let action: () -> Void
    private let hoveringState = State(initialValue: false)

    var body: some View {
        let p = palette
        Button(action: action) {
            HStack(spacing: 12) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13.5))
                    .foregroundStyle(p.color(p.text))
                Spacer(minLength: 12)
                Text(QuickOpenView.shortPath(url.deletingLastPathComponent()))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(p.color(p.faint))
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(p.color(p.hover)).opacity(hoveringState.wrappedValue ? 1 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveringState.wrappedValue = $0 }
    }
}
