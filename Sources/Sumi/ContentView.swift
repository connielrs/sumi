import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?

    @AppStorage(Pref.tema) private var tema = "sistema"
    @AppStorage(Pref.letra) private var letra = "sans"
    @AppStorage(Pref.tamano) private var tamano = 17.0
    @AppStorage(Pref.ancho) private var ancho = "medio"
    @AppStorage(Pref.iconos) private var iconos = "hover"
    @AppStorage(Pref.letraEditor) private var letraEditor = "mono"
    @AppStorage(Pref.indiceAuto) private var indiceAuto = true
    @AppStorage(Pref.recordar) private var recordar = true

    @Environment(\.colorScheme) private var scheme

    // Estado de la ventana. Se usa State directo porque @State necesita Xcode para compilar.
    private let editingState: State<Bool>
    private let showIndexState = State(initialValue: false)
    private let showQuickOpenState = State(initialValue: false)
    private let hoveringBarState = State(initialValue: false)
    private let jumpState = State<JumpRequest?>(initialValue: nil)
    private let currentHeadingState = State(initialValue: 0)
    private let windowBox = State(initialValue: WindowBox())

    private var editing: Bool {
        get { editingState.wrappedValue }
        nonmutating set { editingState.wrappedValue = newValue }
    }
    private var showIndex: Bool {
        get { showIndexState.wrappedValue }
        nonmutating set { showIndexState.wrappedValue = newValue }
    }
    private var showQuickOpen: Bool {
        get { showQuickOpenState.wrappedValue }
        nonmutating set { showQuickOpenState.wrappedValue = newValue }
    }
    private var hoveringBar: Bool {
        get { hoveringBarState.wrappedValue }
        nonmutating set { hoveringBarState.wrappedValue = newValue }
    }
    private var jump: JumpRequest? {
        get { jumpState.wrappedValue }
        nonmutating set { jumpState.wrappedValue = newValue }
    }
    private var currentHeading: Int {
        get { currentHeadingState.wrappedValue }
        nonmutating set { currentHeadingState.wrappedValue = newValue }
    }

    init(document: Binding<MarkdownDocument>, fileURL: URL?) {
        _document = document
        self.fileURL = fileURL
        let opensInEdit = UserDefaults.standard.string(forKey: Pref.abrirEn) == "editar"
        editingState = State(initialValue: opensInEdit || document.wrappedValue.text.isEmpty)
    }

    private var palette: Palette { Palette.resolve(tema, scheme) }
    private var outline: [OutlineItem] { Outline.items(in: document.text) }

    var body: some View {
        let p = palette
        VStack(spacing: 0) {
            topBar(p)
            Rectangle().fill(p.color(p.line)).frame(height: 1)
            HStack(spacing: 0) {
                if showIndex {
                    IndexSidebar(items: outline, current: currentHeading, palette: p) { item in
                        currentHeading = item.id
                        jump = JumpRequest(index: item.id)
                    }
                    Rectangle().fill(p.color(p.line)).frame(width: 1)
                }
                Group {
                    if editing {
                        EditorView(text: $document.text, palette: p, mono: letraEditor == "mono",
                                   outline: outline, jump: jump)
                    } else {
                        ReaderView(markdown: document.text, palette: p,
                                   fontFamily: Reading.cssFont(letra), fontSize: tamano,
                                   column: Reading.column(ancho),
                                   baseURL: fileURL?.deletingLastPathComponent(),
                                   positionKey: fileURL?.path, rememberPosition: recordar,
                                   jump: jump,
                                   onCurrentHeading: { index in
                                       if index != currentHeading { currentHeading = index }
                                   })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            statusBar(p)
        }
        .background(p.color(p.bg))
        .ignoresSafeArea(.container, edges: .top)
        .overlay {
            if showQuickOpen {
                QuickOpenView(palette: p, currentURL: fileURL) { showQuickOpen = false }
            }
        }
        .preferredColorScheme(Palette.forcedScheme(tema))
        .background(WindowReader(box: windowBox.wrappedValue))
        .onReceive(NotificationCenter.default.publisher(for: .sumiToggleEdit)) { _ in
            if windowBox.wrappedValue.isKey { editing.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sumiToggleIndex)) { _ in
            if windowBox.wrappedValue.isKey { withAnimation(.easeOut(duration: 0.18)) { showIndex.toggle() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sumiQuickOpen)) { _ in
            if windowBox.wrappedValue.isKey { showQuickOpen = true }
        }
        .onAppear {
            if indiceAuto && outline.count >= 4 { showIndex = true }
        }
    }

    // MARK: Barra de arriba

    private func topBar(_ p: Palette) -> some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 150, height: 1)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Text(fileURL?.lastPathComponent ?? "Sin título.md")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(p.color(p.text))
                if let folder = fileURL?.deletingLastPathComponent().lastPathComponent {
                    Text(folder)
                        .font(.system(size: 13))
                        .foregroundStyle(p.color(p.faint))
                }
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                BarButton(symbol: "sidebar.left", help: "Índice (⌘\\)", active: showIndex, palette: p) {
                    withAnimation(.easeOut(duration: 0.18)) { showIndex.toggle() }
                }
                BarButton(symbol: "magnifyingglass", help: "Abrir rápido (⌘K)", active: false, palette: p) {
                    showQuickOpen = true
                }
                BarButton(symbol: "pencil", help: editing ? "Volver a leer (⌘E)" : "Editar (⌘E)",
                          active: editing, palette: p) {
                    editing.toggle()
                }
                SettingsLink {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(BarButtonStyle(palette: p, active: false))
                .help("Ajustes (⌘,)")
            }
            .frame(width: 150, alignment: .trailing)
            .opacity(iconos == "siempre" || hoveringBar ? 1 : 0)
            .animation(.easeOut(duration: 0.18), value: hoveringBar)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
        )
        .onHover { hoveringBar = $0 }
    }

    private func statusBar(_ p: Palette) -> some View {
        HStack {
            Text(editing ? "Editando" : "Leyendo")
            Spacer()
            Text(editing ? "Se guarda solo · ⌘E para volver a leer" : "⌘E para editar")
        }
        .font(.system(size: 12))
        .foregroundStyle(p.color(p.faint))
        .padding(.horizontal, 18)
        .frame(height: 30)
    }
}

struct BarButton: View {
    let symbol: String
    let help: String
    let active: Bool
    let palette: Palette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(BarButtonStyle(palette: palette, active: active))
        .help(help)
        .accessibilityLabel(help)
    }
}

struct BarButtonStyle: ButtonStyle {
    let palette: Palette
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        HoverLabel(label: configuration.label, pressed: configuration.isPressed, palette: palette, active: active)
    }
}

private struct HoverLabel<Label: View>: View {
    let label: Label
    let pressed: Bool
    let palette: Palette
    let active: Bool
    private let hoveringState = State(initialValue: false)

    var body: some View {
        let hovering = hoveringState.wrappedValue
        label
            .foregroundStyle(palette.color(active ? palette.accent : (hovering ? palette.text : palette.faint)))
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(palette.color(palette.hover))
                    .opacity(active || hovering || pressed ? 1 : 0)
            )
            .onHover { hoveringState.wrappedValue = $0 }
    }
}

// MARK: Índice

struct IndexSidebar: View {
    let items: [OutlineItem]
    let current: Int
    let palette: Palette
    let onSelect: (OutlineItem) -> Void

    private var visible: [OutlineItem] { items.filter { $0.level <= 3 } }
    private var minLevel: Int { visible.map(\.level).min() ?? 1 }

    var body: some View {
        let p = palette
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                Text("EN ESTE DOCUMENTO")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(p.color(p.faint))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                if visible.isEmpty {
                    Text("Este documento no tiene títulos.")
                        .font(.system(size: 13))
                        .foregroundStyle(p.color(p.muted))
                        .padding(.horizontal, 10)
                }
                ForEach(visible) { item in
                    Button { onSelect(item) } label: {
                        Text(item.title.isEmpty ? "Sin título" : item.title)
                            .font(.system(size: 13, weight: item.id == current ? .medium : .regular))
                            .foregroundStyle(p.color(item.id == current ? p.text : p.muted))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 10 + CGFloat(item.level - minLevel) * 12)
                            .padding(.trailing, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(p.color(p.hover))
                                    .opacity(item.id == current ? 1 : 0)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 28)
        }
        .frame(width: 240)
    }
}
