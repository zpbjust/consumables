import Foundation

struct LabelScanResult: Identifiable, Equatable {
    let id = UUID()
    let lines: [String]
    var suggestedName: String
    var brand: String
    var model: String
    var size: String
    var category: ItemCategory?
}

enum LabelScanParser {
    nonisolated static func parse(lines rawLines: [String]) -> LabelScanResult {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let brand = labeledValue(
            in: lines,
            labels: ["brand", "manufacturer", "品牌", "厂牌"]
        ) ?? fallbackBrand(in: lines)
        let model = labeledValue(
            in: lines,
            labels: ["model number", "model no", "model", "part number", "part no", "sku", "产品型号", "型号", "货号"]
        ) ?? fallbackModel(in: lines)
        let size = labeledValue(
            in: lines,
            labels: ["size", "dimensions", "dimension", "specification", "spec", "规格", "尺寸"]
        ) ?? fallbackSize(in: lines)
        let explicitName = labeledValue(
            in: lines,
            labels: ["product name", "product", "item", "产品名称", "品名", "名称"]
        )
        let category = suggestedCategory(from: lines)

        return LabelScanResult(
            lines: lines,
            suggestedName: explicitName ?? suggestedName(for: category, lines: lines),
            brand: brand ?? "",
            model: model ?? "",
            size: size ?? "",
            category: category
        )
    }

    private nonisolated static func labeledValue(in lines: [String], labels: [String]) -> String? {
        let labelPattern = labels
            .sorted(by: { $0.count > $1.count })
            .map(NSRegularExpression.escapedPattern)
            .joined(separator: "|")
        guard let expression = try? NSRegularExpression(
            pattern: "^\\s*(?:\(labelPattern))\\.?\\s*(?:[:：#]|-\\s+)?\\s*(.+?)\\s*$",
            options: [.caseInsensitive]
        ) else { return nil }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = expression.firstMatch(in: line, range: range),
                  let valueRange = Range(match.range(at: 1), in: line) else { continue }
            let value = line[valueRange].trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return nil
    }

    private nonisolated static func fallbackModel(in lines: [String]) -> String? {
        lines
            .filter { line in
                let compact = line.replacingOccurrences(of: " ", with: "")
                let hasLetter = compact.rangeOfCharacter(from: .letters) != nil
                let hasNumber = compact.rangeOfCharacter(from: .decimalDigits) != nil
                return hasLetter && hasNumber && compact.count >= 4 && compact.count <= 32 &&
                    fallbackSize(in: [line]) == nil
            }
            .max { modelScore($0) < modelScore($1) }
    }

    private nonisolated static func modelScore(_ line: String) -> Int {
        var score = 0
        if line.contains("-") { score += 3 }
        if !line.contains(" ") { score += 2 }
        if line.range(of: "model|part|型号|货号", options: [.regularExpression, .caseInsensitive]) != nil { score += 4 }
        if line.count <= 20 { score += 1 }
        return score
    }

    private nonisolated static func fallbackSize(in lines: [String]) -> String? {
        let patterns = [
            #"\d+(?:\.\d+)?\s*(?:x|×|\*)\s*\d+(?:\.\d+)?(?:\s*(?:x|×|\*)\s*\d+(?:\.\d+)?)?\s*(?:in(?:ches)?|mm|cm|\")?"#,
            #"\d+(?:\.\d+)?\s*(?:英寸|寸|毫米|厘米)"#
        ]
        for line in lines {
            for pattern in patterns {
                if let range = line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    return String(line[range])
                }
            }
        }
        return nil
    }

    private nonisolated static func fallbackBrand(in lines: [String]) -> String? {
        lines.first { line in
            let lower = line.lowercased()
            let genericWords = [
                "filter", "bulb", "battery", "batteries", "replacement", "model", "size", "spec",
                "滤芯", "过滤", "灯泡", "电池", "型号", "规格", "产品"
            ]
            return line.count >= 2 && line.count <= 24 &&
                line.rangeOfCharacter(from: .decimalDigits) == nil &&
                !genericWords.contains(where: lower.contains)
        }
    }

    private nonisolated static func suggestedCategory(from lines: [String]) -> ItemCategory? {
        let text = lines.joined(separator: " ").lowercased()
        if containsAny(text, ["water filter", "refrigerator filter", "reverse osmosis", "ro filter", "净水", "水过滤"]) {
            return .water
        }
        if containsAny(text, ["furnace", "hvac", "air filter", "return air", "空调滤", "空气过滤", "新风滤"]) {
            return .hvac
        }
        if containsAny(text, ["light bulb", "led bulb", "lumen", "灯泡", "灯具", "照明"]) {
            return .lighting
        }
        if containsAny(text, ["battery", "batteries", "alkaline", "lithium", "电池"]) {
            return .batteries
        }
        if containsAny(text, ["appliance", "vacuum", "coffee machine", "吸尘器", "咖啡机", "家电"]) {
            return .appliances
        }
        return nil
    }

    private nonisolated static func suggestedName(for category: ItemCategory?, lines: [String]) -> String {
        let text = lines.joined(separator: " ").lowercased()
        if text.contains("furnace filter") { return "Furnace Filter" }
        if text.contains("refrigerator water filter") { return "Refrigerator Water Filter" }
        if text.contains("light bulb") || text.contains("led bulb") { return "LED Light Bulb" }
        if text.contains("battery") || text.contains("batteries") { return "Batteries" }
        switch category {
        case .water: return text.contains("净水") ? "净水器滤芯" : "Water Filter"
        case .hvac: return "Air Filter"
        case .lighting: return "Light Bulb"
        case .batteries: return "Batteries"
        case .appliances, .other, nil: return ""
        }
    }

    private nonisolated static func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains(where: text.contains)
    }
}
