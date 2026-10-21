import Foundation
import FoundationModels

struct DraftExpense: Identifiable, Sendable {
    let id: UUID
    var title: String
    var detail: String
    var amount: Double
    var category: String

    init(title: String, detail: String, amount: Double, category: String) {
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.amount = amount
        self.category = category
    }
}

@Generable
nonisolated struct SpokenExpenses: Sendable {
    @Guide(description: "Each distinct purchase. Leave out a spoken total when the line items already add up to it.")
    var items: [SpokenExpense]
}

@Generable
nonisolated struct SpokenExpense: Sendable {
    @Guide(description: "Short name of the purchase, such as Coffee or Petrol.")
    var title: String
    @Guide(description: "One or two short lines, such as Lunch at The Green Bowl.")
    var detail: String
    @Guide(description: "Amount in Indian rupees. Numbers only, no currency symbol.")
    var amount: Double
    @Guide(description: "One of: Food & drink, Transport, Shopping, Bills, Health, Entertainment, Other.")
    var category: String
}

enum ExpenseParser {
    private static let instructions = """
        You turn a spoken expense note into structured purchases.
        Currency is always Indian rupees.
        Split combined sentences into separate items.
        If the speaker gives both a total and the items inside it, keep the items and drop the total.
        Titles stay short. Details can name the place or what it was for.
        """

    static func parse(_ transcript: String) async throws -> [DraftExpense] {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        let model = SystemLanguageModel.default
        if model.isAvailable {
            do {
                let structured = try await structure(cleaned, with: model)
                if !structured.isEmpty {
                    return structured
                }
            } catch {
                let local = LocalExpenseParser.parse(cleaned)
                if !local.isEmpty { return local }
                throw error
            }
        }

        let local = LocalExpenseParser.parse(cleaned)
        if local.isEmpty, !model.isAvailable {
            throw ParserError.intelligenceUnavailable
        }
        return local
    }

    private static func structure(_ transcript: String, with model: SystemLanguageModel) async throws -> [DraftExpense] {
        let session = LanguageModelSession(model: model, instructions: instructions)
        let response = try await session.respond(to: transcript, generating: SpokenExpenses.self)
        return response.content.items.compactMap { item in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard item.amount > 0, !title.isEmpty else { return nil }
            let detail = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return DraftExpense(
                title: title,
                detail: detail.isEmpty ? title : detail,
                amount: item.amount,
                category: ExpenseCategory.normalize(item.category)
            )
        }
    }
}

extension DraftExpense {
    static func recovered(amountText: String, title: String) -> DraftExpense? {
        let phrase = title.isEmpty ? "\(amountText) rupees" : "\(amountText) rupees for \(title)"
        if let parsed = LocalExpenseParser.parse(phrase).first, parsed.amount > 0 {
            let resolved = title.isEmpty ? parsed.title : title.capitalized
            return DraftExpense(
                title: resolved,
                detail: resolved,
                amount: parsed.amount,
                category: ExpenseCategory.infer(from: resolved)
            )
        }
        let digits = amountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "₹", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let amount = Double(digits), amount.isFinite, amount > 0 else { return nil }
        let resolved = title.isEmpty ? "Expense" : title.capitalized
        return DraftExpense(
            title: resolved,
            detail: resolved,
            amount: amount,
            category: ExpenseCategory.infer(from: resolved)
        )
    }
}

enum ParserError: LocalizedError {
    case intelligenceUnavailable
    case nothingRecognized

    var errorDescription: String? {
        switch self {
        case .intelligenceUnavailable:
            "This iPhone can’t run Apple Intelligence. Say the amount in words or numbers, such as one lakh rupees for rent, and it is still saved on device."
        case .nothingRecognized:
            "I could not find an expense in that. Try naming the amount and what it was for."
        }
    }
}

enum LocalExpenseParser {
    private static let units: [String: Double] = [
        "zero": 0, "oh": 0, "one": 1, "two": 2, "three": 3, "four": 4,
        "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9,
        "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
        "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90
    ]

    private static let scales: [(String, Double)] = [
        ("crores", 10_000_000), ("crore", 10_000_000),
        ("lakhs", 100_000), ("lakh", 100_000), ("lacs", 100_000), ("lac", 100_000), ("lack", 100_000),
        ("thousand", 1_000), ("hundred", 100)
    ]

    private static let rupeeWords: Set<String> = ["rupee", "rupees", "inr"]
    private static let connectors: Set<String> = ["for", "on", "towards"]
    private static let skipWords: Set<String> = [
        "i", "me", "my", "we", "our", "spent", "spend", "spending", "paid", "pay", "paying",
        "bought", "buy", "got", "had", "have", "was", "were", "is", "the", "a", "an", "of",
        "to", "and", "today", "yesterday", "just", "about", "around", "roughly", "only",
        "please", "rupee", "rupees", "inr", "rs", "worth", "cost", "costs", "costing",
        "at", "from", "in", "total", "overall", "altogether"
    ]

    static func parse(_ transcript: String) -> [DraftExpense] {
        let words = tokenize(transcript)
        let matches = amounts(in: words)
        guard !matches.isEmpty else { return [] }

        var drafts: [DraftExpense] = []
        for (index, match) in matches.enumerated() {
            let previousEnd = index == 0 ? 0 : matches[index - 1].end
            let nextStart = index + 1 < matches.count ? matches[index + 1].start : words.count
            let name = title(in: words, match: match, previousEnd: previousEnd, nextStart: nextStart)
            drafts.append(
                DraftExpense(
                    title: name,
                    detail: name,
                    amount: match.value,
                    category: ExpenseCategory.infer(from: name)
                )
            )
        }

        if drafts.count >= 2 {
            let parts = drafts.dropLast().reduce(0) { $0 + $1.amount }
            if abs(parts - drafts[drafts.count - 1].amount) < 0.5 {
                drafts.removeLast()
            }
        }
        return drafts
    }

    private struct AmountMatch {
        var value: Double
        var start: Int
        var end: Int
    }

    private static func amounts(in words: [String]) -> [AmountMatch] {
        var found: [AmountMatch] = []
        var index = 0
        while index < words.count {
            if rupeeWords.contains(words[index]), let parsed = number(in: words, from: index + 1) {
                found.append(AmountMatch(value: parsed.value, start: index, end: pastRupee(parsed.end, in: words)))
                index = pastRupee(parsed.end, in: words)
                continue
            }
            if let parsed = number(in: words, from: index) {
                let end = pastRupee(parsed.end, in: words)
                let followedByPurpose = end < words.count && connectors.contains(words[end])
                if parsed.strong || followedByPurpose || (end > parsed.end) {
                    found.append(AmountMatch(value: parsed.value, start: index, end: end))
                    index = end
                    continue
                }
            }
            index += 1
        }
        return found
    }

    private struct NumberParse {
        var value: Double
        var end: Int
        var strong: Bool
    }

    private static func number(in words: [String], from start: Int) -> NumberParse? {
        var index = start
        var total = 0.0
        var current = 0.0
        var consumed = false
        var strong = false
        var lastScale = 0.0

        while index < words.count {
            let word = words[index]
            if word == "and" {
                let upcoming = index + 1 < words.count ? words[index + 1] : ""
                let halfAfterArticle = (upcoming == "a" || upcoming == "an") && index + 2 < words.count && words[index + 2] == "half"
                if current == 0, lastScale > 0, upcoming == "half" || halfAfterArticle {
                    total += lastScale / 2
                    index += halfAfterArticle ? 3 : 2
                    consumed = true
                    continue
                }
                if upcoming == "a" || upcoming == "an" || upcoming == "half" || units[upcoming] != nil || decimal(upcoming) != nil {
                    index += 1
                    continue
                }
                break
            }
            if word == "a" || word == "an" {
                let upcoming = index + 1 < words.count ? words[index + 1] : ""
                if upcoming == "half" {
                    current += 0.5
                    consumed = true
                    index += 2
                    continue
                }
                if scale(upcoming) != nil {
                    current += 1
                    consumed = true
                    index += 1
                    continue
                }
                break
            }
            if word == "half" {
                current += 0.5
                consumed = true
                index += 1
                continue
            }
            if word == "point" || word == "decimal" {
                var fraction = ""
                var cursor = index + 1
                while cursor < words.count, fraction.count < 2, let digit = singleDigit(words[cursor]) {
                    fraction.append(digit)
                    cursor += 1
                }
                if let value = Double("0." + fraction), !fraction.isEmpty {
                    current = current.rounded(.towardZero) + value
                    consumed = true
                    index = cursor
                    continue
                }
                break
            }
            if let value = gluedScale(word) ?? decimal(word) {
                if current == 0, total > 0 { break }
                current += value
                consumed = true
                strong = true
                index += 1
                continue
            }
            if let value = units[word] {
                current += value
                consumed = true
                if value >= 20 { strong = true }
                index += 1
                continue
            }
            if let factor = scale(word) {
                if current == 0 { current = 1 }
                if factor == 100 {
                    current *= factor
                } else {
                    total += current * factor
                    current = 0
                    lastScale = factor
                }
                consumed = true
                strong = true
                index += 1
                continue
            }
            break
        }

        total += current
        guard consumed, total > 0, index > start else { return nil }
        return NumberParse(value: total, end: index, strong: strong)
    }

    private static func title(in words: [String], match: AmountMatch, previousEnd: Int, nextStart: Int) -> String {
        if match.end < words.count, connectors.contains(words[match.end]) {
            let spoken = nameWords(Array(words[(match.end + 1)..<nextStart]))
            if !spoken.isEmpty { return spoken }
        }
        let spoken = nameWords(Array(words[previousEnd..<match.start]))
        return spoken.isEmpty ? "Expense" : spoken
    }

    private static func nameWords(_ words: [String]) -> String {
        let kept = words
            .filter { !skipWords.contains($0) && !connectors.contains($0) && decimal($0) == nil && scale($0) == nil }
            .prefix(8)
        guard !kept.isEmpty else { return "" }
        return kept.joined(separator: " ").capitalized
    }

    private static func pastRupee(_ index: Int, in words: [String]) -> Int {
        guard index < words.count, rupeeWords.contains(words[index]) else { return index }
        return index + 1
    }

    private static func scale(_ word: String) -> Double? {
        scales.first { $0.0 == word }?.1
    }

    private static func decimal(_ word: String) -> Double? {
        let cleaned = word.replacingOccurrences(of: ",", with: "")
        guard cleaned.contains(where: \.isNumber), let value = Double(cleaned), value >= 0 else { return nil }
        return value
    }

    private static func singleDigit(_ word: String) -> Character? {
        if let value = units[word], value < 10, value == value.rounded() {
            return Character(String(Int(value)))
        }
        if word.count == 1, let character = word.first, character.isNumber {
            return character
        }
        return nil
    }

    private static func gluedScale(_ word: String) -> Double? {
        for (suffix, factor) in scales where word.hasSuffix(suffix) && word.count > suffix.count {
            let head = String(word.dropLast(suffix.count))
            if let value = Double(head) { return value * factor }
        }
        return nil
    }

    private static func tokenize(_ transcript: String) -> [String] {
        var text = transcript.lowercased().replacingOccurrences(of: "₹", with: " rupees ")
        if let regex = try? NSRegularExpression(pattern: #"(?i)\brs\.?(?=\d)"#) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: " rupees ")
        }
        if let regex = try? NSRegularExpression(pattern: #"(?i)\brs\.?\b"#) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: " rupees ")
        }
        if let regex = try? NSRegularExpression(pattern: #"(\d),(?=\d)"#) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
        }

        var words: [String] = []
        var current = ""
        func flush() {
            let token = current.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if !token.isEmpty { words.append(token) }
            current = ""
        }
        for character in text {
            if character.isLetter || character.isNumber || character == "." {
                current.append(character)
            } else {
                flush()
            }
        }
        flush()
        return words
    }
}
