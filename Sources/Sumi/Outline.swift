import Foundation
import Markdown

struct OutlineItem: Identifiable, Equatable {
    let id: Int        // posición entre todos los títulos del documento
    let level: Int
    let title: String
    let line: Int      // línea donde está, empieza en 1
}

private struct HeadingCollector: MarkupWalker {
    var items: [OutlineItem] = []

    mutating func visitHeading(_ heading: Heading) {
        items.append(OutlineItem(id: items.count,
                                 level: heading.level,
                                 title: heading.plainText,
                                 line: heading.range?.lowerBound.line ?? 1))
    }
}

enum Outline {
    static func items(in text: String) -> [OutlineItem] {
        var collector = HeadingCollector()
        collector.visit(Document(parsing: text))
        return collector.items
    }
}
