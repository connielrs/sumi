import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(Pref.tema) private var tema = "sistema"
    @AppStorage(Pref.letra) private var letra = "sans"
    @AppStorage(Pref.tamano) private var tamano = 17.0
    @AppStorage(Pref.ancho) private var ancho = "medio"
    @AppStorage(Pref.iconos) private var iconos = "hover"
    @AppStorage(Pref.letraEditor) private var letraEditor = "mono"
    @AppStorage(Pref.abrirEn) private var abrirEn = "leer"
    @AppStorage(Pref.indiceAuto) private var indiceAuto = true
    @AppStorage(Pref.recordar) private var recordar = true

    @Environment(\.colorScheme) private var scheme
    // State directo porque @State necesita Xcode para compilar.
    private let isDefaultState = State(initialValue: false)
    private let defaultErrorState = State<String?>(initialValue: nil)

    private var isDefault: Bool {
        get { isDefaultState.wrappedValue }
        nonmutating set { isDefaultState.wrappedValue = newValue }
    }
    private var defaultError: String? {
        get { defaultErrorState.wrappedValue }
        nonmutating set { defaultErrorState.wrappedValue = newValue }
    }

    private let sample = """
    # Un lector para mis .md

    Abrir un archivo, leerlo tranquila y, si hace falta, corregir algo sin cambiar de app.

    - Abrir cualquier .md con doble clic.
    - Pasar a editar con `⌘E`.
    - Guardar solo, sin preguntar.
    """

    var body: some View {
        let p = Palette.resolve(tema, scheme)
        HStack(spacing: 0) {
            Form {
                Section("Apariencia") {
                    Picker("Tema", selection: $tema) {
                        Text("Sistema").tag("sistema")
                        Text("Claro").tag("claro")
                        Text("Oscuro").tag("oscuro")
                        Text("Sepia").tag("sepia")
                    }
                    Picker("Letra para leer", selection: $letra) {
                        Text("Sans").tag("sans")
                        Text("Serif").tag("serif")
                    }
                    .pickerStyle(.segmented)
                    Stepper(value: $tamano, in: 14...22, step: 1) {
                        LabeledContent("Tamaño del texto", value: "\(Int(tamano)) px")
                    }
                    Picker("Ancho del texto", selection: $ancho) {
                        Text("Angosto").tag("angosto")
                        Text("Medio").tag("medio")
                        Text("Ancho").tag("ancho")
                    }
                    .pickerStyle(.segmented)
                    Picker("Letra para editar", selection: $letraEditor) {
                        Text("Mono").tag("mono")
                        Text("Sans").tag("sans")
                    }
                    .pickerStyle(.segmented)
                    Picker(selection: $iconos) {
                        Text("Al pasar el mouse").tag("hover")
                        Text("Siempre").tag("siempre")
                    } label: {
                        Text("Íconos de la barra")
                        Text("Si eliges la primera opción, quedan escondidos hasta que pasas el mouse por arriba")
                    }
                }
                Section("Al abrir un archivo") {
                    Picker("Abrir en", selection: $abrirEn) {
                        Text("Leer").tag("leer")
                        Text("Editar").tag("editar")
                    }
                    .pickerStyle(.segmented)
                    Toggle(isOn: $indiceAuto) {
                        Text("Mostrar el índice si es largo")
                        Text("Se abre solo cuando el archivo tiene cuatro títulos o más")
                    }
                    Toggle(isOn: $recordar) {
                        Text("Recordar dónde quedé")
                        Text("Vuelve al mismo punto al reabrir un archivo")
                    }
                }
                Section {
                    LabeledContent {
                        if isDefault {
                            Label("Es la predeterminada", systemImage: "checkmark")
                                .foregroundStyle(.green)
                        } else {
                            Button("Usar como predeterminada", action: makeDefault)
                        }
                    } label: {
                        Text("Abrir los .md con Sumi")
                        if let defaultError {
                            Text(defaultError).foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Archivos")
                } footer: {
                    Text("Los cambios se guardan solos mientras escribes.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 500)

            VStack(alignment: .leading, spacing: 10) {
                Text("VISTA PREVIA")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                ReaderView(markdown: sample, palette: p, fontFamily: Reading.cssFont(letra),
                           fontSize: tamano * 0.85, column: Int(Double(Reading.column(ancho)) * 0.55),
                           baseURL: nil)
                    .background(p.color(p.bg))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.color(p.line)))
                    .allowsHitTesting(false)
            }
            .padding(20)
            .frame(width: 380)
        }
        .frame(height: 620)
        .preferredColorScheme(Palette.forcedScheme(tema))
        .onAppear(perform: refreshDefault)
    }

    private func refreshDefault() {
        let current = NSWorkspace.shared.urlForApplication(toOpen: .markdownText)
        isDefault = current?.standardizedFileURL.path == Bundle.main.bundleURL.standardizedFileURL.path
    }

    private func makeDefault() {
        defaultError = nil
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpen: .markdownText) { error in
            DispatchQueue.main.async {
                if error != nil {
                    defaultError = "No se pudo cambiar. Inténtalo con la app instalada en Aplicaciones."
                }
                refreshDefault()
            }
        }
    }
}
