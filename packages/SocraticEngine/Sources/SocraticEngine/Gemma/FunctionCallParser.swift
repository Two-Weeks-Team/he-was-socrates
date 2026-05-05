import Foundation

/// Parses Gemma's JSON function-call output per `function_call_contract.yaml`
/// and `SystemPrompt.partC_dispatch`. Defensive against:
/// - Markdown code fences the model may emit despite instructions
/// - Leading/trailing whitespace
/// - Quotation drift (smart quotes)
/// - Truncated JSON when streaming (returns nil for partial)
public enum FunctionCallParser {

    public enum Result: Equatable, Sendable {
        case modeClassify(mode: Mode, confidence: Double, reasoning: String)
        case askBack(question: String, language: Language)
        case surfacePastWonder(connector: String, language: Language)
        case deferToHuman(trigger: String, resource: String, explanation: String)
        case malformed(reason: String, raw: String)
    }

    public static func parse(_ raw: String) -> Result {
        let cleaned = strip(raw)
        guard let data = cleaned.data(using: .utf8),
              let any = try? JSONSerialization.jsonObject(with: data),
              let obj = any as? [String: Any],
              let function = obj["function"] as? String,
              let args = obj["args"] as? [String: Any] else {
            return .malformed(reason: "could not parse JSON object with function+args", raw: raw)
        }

        switch function {
        case "mode_classify":
            guard let modeStr = args["mode"] as? String,
                  let mode = Mode(rawValue: modeStr) else {
                return .malformed(reason: "mode_classify: invalid mode value", raw: raw)
            }
            let confidence = (args["confidence"] as? Double)
                          ?? Double(args["confidence"] as? Int ?? 0)
            let reasoning = args["reasoning_summary"] as? String ?? ""
            return .modeClassify(mode: mode, confidence: confidence, reasoning: reasoning)

        case "ask_back":
            guard let q = args["question"] as? String, !q.isEmpty else {
                return .malformed(reason: "ask_back: missing/empty question", raw: raw)
            }
            let langStr = args["language"] as? String ?? "ko"
            let lang = Language(rawValue: langStr) ?? .auto
            return .askBack(question: q, language: lang)

        case "surface_past_wonder":
            let connector = args["connector_phrasing"] as? String ?? ""
            let langStr = args["language"] as? String ?? "ko"
            let lang = Language(rawValue: langStr) ?? .auto
            return .surfacePastWonder(connector: connector, language: lang)

        case "defer_to_human":
            let trigger = args["trigger_category"] as? String ?? "other"
            let resource = args["suggested_resource_class"] as? String ?? ""
            let explanation = args["explanation_phrase"] as? String ?? ""
            return .deferToHuman(trigger: trigger, resource: resource, explanation: explanation)

        default:
            return .malformed(reason: "unknown function name: \(function)", raw: raw)
        }
    }

    /// Robustly strip wrapping the model might emit despite system prompt rules:
    /// markdown fences (```json ... ```), leading/trailing prose,
    /// smart-quote replacement.
    private static func strip(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code fence opener / closer.
        if s.hasPrefix("```") {
            // Drop everything up to first newline (drops "```json" tag).
            if let nl = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: nl)...])
            }
        }
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Smart quotes → straight quotes (some models emit them in Korean output).
        let smartQuoteMap: [(String, String)] = [
            ("\u{201C}", "\""), ("\u{201D}", "\""),
            ("\u{2018}", "'"), ("\u{2019}", "'"),
        ]
        for (smart, plain) in smartQuoteMap {
            s = s.replacingOccurrences(of: smart, with: plain)
        }

        // Truncate trailing prose after the closing brace if the model
        // chattered (defensive — often happens with smaller Gemma variants).
        if let braceEnd = s.lastIndex(of: "}") {
            s = String(s[...braceEnd])
        }

        return s
    }
}
