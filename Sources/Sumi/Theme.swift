import SwiftUI
import AppKit

/// Nombres de los ajustes guardados.
enum Pref {
    static let tema = "tema"               // sistema, claro, oscuro, sepia
    static let letra = "letra"             // sans, serif
    static let tamano = "tamano"           // tamaño del texto al leer
    static let ancho = "ancho"             // angosto, medio, ancho
    static let iconos = "iconos"           // hover, siempre
    static let letraEditor = "letraEditor" // mono, sans
    static let abrirEn = "abrirEn"         // leer, editar
    static let indiceAuto = "indiceAuto"
    static let recordar = "recordar"
}

struct Palette: Equatable {
    var bg: String
    var line: String
    var hover: String
    var text: String
    var muted: String
    var faint: String
    var accent: String
    var code: String
    var sel: String
    var dark: Bool

    static let claro = Palette(bg: "#FFFFFF", line: "#ECEBE8", hover: "#F1F1EF", text: "#1D1D1F", muted: "#5E5E63",
                               faint: "#737378", accent: "#2563EB", code: "#F4F4F2", sel: "#DCE6FB", dark: false)
    static let oscuro = Palette(bg: "#1B1B1D", line: "#2C2C2F", hover: "#2A2A2D", text: "#E8E8EA", muted: "#A9A9AE",
                                faint: "#8E8E93", accent: "#7AA2FF", code: "#26262A", sel: "#2D3B5C", dark: true)
    static let sepia = Palette(bg: "#F7F1E6", line: "#E4DBC9", hover: "#EDE4D3", text: "#3B3226", muted: "#65594A",
                               faint: "#776A59", accent: "#9A5B2E", code: "#EEE5D4", sel: "#EAD9BC", dark: false)

    static func resolve(_ tema: String, _ scheme: ColorScheme) -> Palette {
        switch tema {
        case "claro": return .claro
        case "oscuro": return .oscuro
        case "sepia": return .sepia
        default: return scheme == .dark ? .oscuro : .claro
        }
    }

    static func forcedScheme(_ tema: String) -> ColorScheme? {
        switch tema {
        case "claro", "sepia": return .light
        case "oscuro": return .dark
        default: return nil
        }
    }

    func color(_ hex: String) -> Color { Color(nsColor: NSColor(hex: hex)) }
    func ns(_ hex: String) -> NSColor { NSColor(hex: hex) }
}

extension NSColor {
    convenience init(hex: String) {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }
}

enum Reading {
    static func cssFont(_ letra: String) -> String {
        letra == "serif" ? "'New York', ui-serif, Georgia, serif" : "-apple-system, system-ui, sans-serif"
    }

    static func column(_ ancho: String) -> Int {
        switch ancho {
        case "angosto": return 600
        case "ancho": return 800
        default: return 680
        }
    }
}

/// Pedido para saltar a un título del índice.
struct JumpRequest: Equatable {
    let id = UUID()
    let index: Int
}
