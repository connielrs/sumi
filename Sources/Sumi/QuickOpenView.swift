import SwiftUI

/// Buscador de archivos .md recientes y de la misma carpeta (⌘K).
struct QuickOpenView: View {
    let palette: Palette
    let currentURL: URL?
    let onClose: () -> Void

    // State directo porque @State necesita Xcode para compilar.
    private let queryState = State(initialValue: "")
    private let selectionState = State(initialValue: 0)
    private let candidatesState = State<[URL]>(initialValue: [])
    @FocusState private var focused: Bool

    private var query: String {
        get { queryState.wrappedValue }
        nonmutating set { queryState.wrappedValue = newValue }
    }
    private var selection: Int {
        get { selectionState.wrappedValue }
        nonmutating set { selectionState.wrappedValue = newValue }
    }
    private var candidates: [URL] {
        get { candidatesState.wrappedValue }
        nonmutating set { candidatesState.wrappedValue = newValue }
    }

    private static let extensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    private var results: [URL] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return candidates }
        return candidates.filter { $0.path.lowercased().contains(q) }
    }

    var body: some View {
        let p = palette
        ZStack(alignment: .top) {
            p.color(p.bg).opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(p.color(p.faint))
                    TextField("Buscar en recientes y en esta carpeta", text: queryState.projectedValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .foregroundStyle(p.color(p.text))
                        .focused($focused)
                        .onSubmit(openSelection)
                        .onKeyPress(.downArrow) { move(1); return .handled }
                        .onKeyPress(.upArrow) { move(-1); return .handled }
                        .onKeyPress(.escape) { onClose(); return .handled }
                }
                .padding(.horizontal, 18)
                .frame(height: 56)

                Rectangle().fill(p.color(p.line)).frame(height: 1)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(query.isEmpty ? "RECIENTES Y EN ESTA CARPETA" : "RESULTADOS")
                                .font(.system(size: 11, weight: .semibold))
                                .kerning(0.6)
                                .foregroundStyle(p.color(p.faint))
                                .padding(.horizontal, 12)
                                .padding(.top, 6)
                                .padding(.bottom, 4)
                            if results.isEmpty {
                                Text("No hay archivos .md con ese nombre. Prueba con otra palabra.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(p.color(p.muted))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 24)
                            }
                            ForEach(Array(results.enumerated()), id: \.element) { index, url in
                                row(url, selected: index == selection, p)
                                    .id(index)
                                    .onTapGesture { open(url) }
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 380)
                    .fixedSize(horizontal: false, vertical: true)
                    .onChange(of: selection) { _, value in proxy.scrollTo(value) }
                }

                Rectangle().fill(p.color(p.line)).frame(height: 1)

                HStack(spacing: 18) {
                    hint("↵", "abrir", p)
                    hint("↑↓", "moverse", p)
                    hint("esc", "cerrar", p)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            .frame(width: 620)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(p.color(p.dark ? "#242427" : p.bg))
                    .shadow(color: .black.opacity(0.18), radius: 30, y: 16)
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.color(p.line)))
            .padding(.top, 96)
        }
        .onAppear {
            candidates = Self.findCandidates(near: currentURL)
            focused = true
        }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    private func row(_ url: URL, selected: Bool, _ p: Palette) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(p.color(p.faint))
            Text(url.lastPathComponent)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(p.color(p.text))
            Spacer(minLength: 12)
            Text(Self.shortPath(url.deletingLastPathComponent()))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(p.color(p.faint))
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 9).fill(p.color(selected ? p.sel : p.bg)).opacity(selected ? 0.7 : 0))
        .contentShape(Rectangle())
    }

    private func hint(_ key: String, _ label: String, _ p: Palette) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(p.color(p.line)))
                .foregroundStyle(p.color(p.muted))
            Text(label)
        }
        .font(.system(size: 12))
        .foregroundStyle(p.color(p.faint))
    }

    private func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    private func openSelection() {
        guard results.indices.contains(selection) else { return }
        open(results[selection])
    }

    private func open(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        onClose()
    }

    static func shortPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    static func findCandidates(near current: URL?) -> [URL] {
        var seen = Set<String>()
        var list: [URL] = []
        func add(_ url: URL) {
            let key = url.standardizedFileURL.path
            guard extensions.contains(url.pathExtension.lowercased()), !seen.contains(key) else { return }
            seen.insert(key)
            list.append(url)
        }
        NSDocumentController.shared.recentDocumentURLs.forEach(add)
        if let folder = current?.deletingLastPathComponent(),
           let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                                    options: [.skipsHiddenFiles]) {
            files.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .forEach(add)
        }
        return list
    }
}
