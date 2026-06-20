import Foundation

/// A rendered block of comment content.
enum CommentBlock: Hashable {
    case text(AttributedString)
    case quote(AttributedString)
    case code(String)
}

/// Converts the small, predictable subset of HTML that the Hacker News API
/// emits in comment/text bodies into native styled blocks. Handles `<p>`
/// paragraphs, `<i>`/`<em>` and `<b>`/`<strong>` inline styles, `<a href>`
/// links, `<pre><code>` blocks, `<br>`, HTML entities, and `>`-quoted lines.
enum HTMLRenderer {

    static func render(_ html: String) -> [CommentBlock] {
        guard !html.isEmpty else { return [] }
        let chars = Array(html)
        var blocks: [CommentBlock] = []

        var current = AttributedString()
        var rawText = ""           // plain text of current paragraph (quote detection)
        var emphasis = false
        var strong = false
        var linkURL: String?
        var i = 0

        func appendRun(_ raw: String) {
            guard !raw.isEmpty else { return }
            let decoded = decodeEntities(raw)
            rawText += decoded
            var run = AttributedString(decoded)
            var intent: InlinePresentationIntent = []
            if emphasis { intent.insert(.emphasized) }
            if strong { intent.insert(.stronglyEmphasized) }
            if !intent.isEmpty { run.inlinePresentationIntent = intent }
            if let linkURL, let url = URL(string: linkURL) {
                run.link = url
            }
            current += run
        }

        func finishParagraph() {
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if trimmed.hasPrefix(">") {
                    blocks.append(.quote(AttributedString(stripQuoteMarkers(trimmed))))
                } else {
                    blocks.append(.text(current))
                }
            }
            current = AttributedString()
            rawText = ""
        }

        while i < chars.count {
            if chars[i] == "<" {
                // Read the full tag.
                var j = i + 1
                while j < chars.count && chars[j] != ">" { j += 1 }
                let rawTag = String(chars[(i + 1)..<min(j, chars.count)])
                let tag = rawTag.lowercased()
                i = (j < chars.count) ? j + 1 : j

                if tag == "pre" || tag.hasPrefix("pre ") {
                    finishParagraph()
                    // Capture everything up to the matching </pre>.
                    let (code, next) = captureUntilClose(chars, from: i, close: "</pre>")
                    let cleaned = stripTags(code)
                    let text = decodeEntities(cleaned)
                        .trimmingCharacters(in: .newlines)
                    if !text.isEmpty { blocks.append(.code(text)) }
                    i = next
                    continue
                }

                switch tag {
                case "p", "/p", "p/", "br", "br/", "br /":
                    if tag.hasPrefix("br") {
                        appendRun("\n")
                    } else {
                        finishParagraph()
                    }
                case "i", "em": emphasis = true
                case "/i", "/em": emphasis = false
                case "b", "strong": strong = true
                case "/b", "/strong": strong = false
                case "/a": linkURL = nil
                default:
                    if tag == "a" || tag.hasPrefix("a ") {
                        linkURL = extractHref(rawTag)
                    }
                    // All other tags (code, span, etc.) are ignored.
                }
                continue
            }

            // Accumulate a run of text up to the next tag.
            var j = i
            while j < chars.count && chars[j] != "<" { j += 1 }
            appendRun(String(chars[i..<j]))
            i = j
        }
        finishParagraph()
        return blocks
    }

    // MARK: - Helpers

    /// Returns (captured text, index just past the close tag).
    private static func captureUntilClose(_ chars: [Character], from start: Int, close: String) -> (String, Int) {
        let closeChars = Array(close.lowercased())
        var i = start
        while i < chars.count {
            if chars[i] == "<" {
                let slice = chars[i..<min(i + closeChars.count, chars.count)]
                if String(slice).lowercased() == close {
                    return (String(chars[start..<i]), i + closeChars.count)
                }
            }
            i += 1
        }
        return (String(chars[start..<chars.count]), chars.count)
    }

    private static func stripTags(_ s: String) -> String {
        var out = ""
        var inTag = false
        for c in s {
            if c == "<" { inTag = true }
            else if c == ">" { inTag = false }
            else if !inTag { out.append(c) }
        }
        return out
    }

    private static func extractHref(_ tag: String) -> String? {
        guard let range = tag.range(of: "href=", options: .caseInsensitive) else { return nil }
        var rest = tag[range.upperBound...]
        guard let quote = rest.first, quote == "\"" || quote == "'" else {
            // Unquoted href: read until whitespace.
            let value = rest.prefix { !$0.isWhitespace }
            return value.isEmpty ? nil : decodeEntities(String(value))
        }
        rest = rest.dropFirst()
        let value = rest.prefix { $0 != quote }
        return value.isEmpty ? nil : decodeEntities(String(value))
    }

    private static func stripQuoteMarkers(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var l = Substring(line)
                while l.first == ">" || l.first == " " { l = l.dropFirst() }
                return String(l)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": " ", "mdash": "—", "ndash": "–", "hellip": "…",
        "ldquo": "\u{201C}", "rdquo": "\u{201D}", "lsquo": "\u{2018}",
        "rsquo": "\u{2019}", "times": "×", "deg": "°", "copy": "©", "reg": "®",
        "trade": "™", "euro": "€", "pound": "£", "cent": "¢",
    ]

    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var result = ""
        result.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "&",
               let semi = s[i...].firstIndex(of: ";"),
               s.distance(from: i, to: semi) <= 12 {
                let entity = String(s[s.index(after: i)..<semi])
                if let decoded = decodeEntity(entity) {
                    result.append(decoded)
                    i = s.index(after: semi)
                    continue
                }
            }
            result.append(s[i])
            i = s.index(after: i)
        }
        return result
    }

    private static func decodeEntity(_ entity: String) -> String? {
        if let named = namedEntities[entity] { return named }
        guard entity.first == "#" else { return nil }
        let body = entity.dropFirst()
        let scalarValue: UInt32?
        if body.first == "x" || body.first == "X" {
            scalarValue = UInt32(body.dropFirst(), radix: 16)
        } else {
            scalarValue = UInt32(body, radix: 10)
        }
        guard let value = scalarValue, let scalar = Unicode.Scalar(value) else { return nil }
        return String(scalar)
    }
}
