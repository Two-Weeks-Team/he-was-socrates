import Foundation

/// Coordinates the four Gemma function calls per
/// `runs/2026-05-05-spec/spec/function_call_contract.yaml`.
///
/// Standard turn order:
///   1. mode_classify(utterance, recent_history) → ModeClassification
///   2. (optional) surface_past_wonder(utterance, log_summary) → connector
///   3. ask_back(utterance, mode, language) OR defer_to_human(...)
///
/// Phase 1 skeleton.
public actor FunctionCallOrchestrator {

    public struct TurnInput: Sendable {
        public let utterance: String
        public let language: Language
        public let recentHistoryCompressed: String

        public init(utterance: String, language: Language, recentHistoryCompressed: String = "") {
            self.utterance = utterance
            self.language = language
            self.recentHistoryCompressed = recentHistoryCompressed
        }
    }

    public struct TurnOutput: Sendable {
        public let mode: ModeClassification
        /// Reserved — iter2 §A7 stall-fallback surface. `EngineCoordinator`
        /// in Phase 1–3 does NOT read this field. Populated only by the
        /// `.surfacePastWonder` parser case for forward compatibility
        /// with the Phase-4 surface_past_wonder + ask_back composite turn.
        /// CONTRIBUTING.md L27-31 prohibits removing the field; PR-δ
        /// annotates it so a reader doesn't mistake the orphan for a bug.
        public let surfacedPastWonder: String?
        public let socraticReply: String
        public let deferred: Bool
        public let correlationId: UUID
    }

    public enum DeferTrigger: String, Codable, Sendable {
        case legal
        case medical
        case financial
        case emergency
        case welfare  // added per SC2 finding (idea.spec.json no_go alignment)
        case insurance  // added per SC2 finding
        case other
    }

    private let gemma: GemmaService

    public init(gemma: GemmaService) {
        self.gemma = gemma
    }

    /// Run a complete turn end-to-end:
    ///   1. Compose system + user prompts (SystemPrompt)
    ///   2. Stream Gemma generation
    ///   3. Parse JSON function-call (FunctionCallParser)
    ///   4. Map to TurnOutput
    ///
    /// In stub mode the GemmaService produces a canned JSON-shape response
    /// so the entire pipeline is exercised without real MLX inference.
    public func runTurn(_ input: TurnInput, correlationId: UUID = UUID()) async throws -> TurnOutput
    {
        let userTurn = SystemPrompt.userTurn(
            utterance: input.utterance,
            language: input.language,
            recentHistory: input.recentHistoryCompressed
        )

        let result: FunctionCallParser.Result
        do {
            result = try await gemma.runTurn(
                systemPrompt: SystemPrompt.composed,
                userTurn: userTurn
            )
        } catch {
            throw EngineError.make(
                domain: SocraticErrorDomain.model,
                code: .modelInferenceTimeout,
                descriptionKO: "추론이 시간 안에 끝나지 않았다.",
                descriptionEN: "Inference did not complete in time.",
                underlying: error
            )
        }

        // Convert parser result into a TurnOutput. If the model returned a
        // mode_classify call without a follow-up ask_back, we use a default
        // classification + still need to produce a reply — caller may need
        // a second turn. For Phase 1-3 the stub directly produces ask_back
        // or defer_to_human, which is the common path.
        switch result {
        case .askBack(let question, let language):
            return TurnOutput(
                mode: ModeClassification(
                    mode: .curiousAdult,
                    confidence: 0.85,
                    reasoningSummary: "stub default"
                ),
                surfacedPastWonder: nil,
                socraticReply: question,
                deferred: false,
                correlationId: correlationId
            )

        case .deferToHuman(_, _, let explanation):
            return TurnOutput(
                mode: ModeClassification(
                    mode: .other,
                    confidence: 0.95,
                    reasoningSummary: "regulated advice"
                ),
                surfacedPastWonder: nil,
                socraticReply: explanation,
                deferred: true,
                correlationId: correlationId
            )

        case .surfacePastWonder(let connector, _):
            // Phase 4: real flow re-issues a follow-up generate() to compose
            // the surface_past_wonder + ask_back combo. Stub: treat connector
            // as the reply directly.
            return TurnOutput(
                mode: ModeClassification(
                    mode: .curiousAdult,
                    confidence: 0.80,
                    reasoningSummary: "surfacing"
                ),
                surfacedPastWonder: connector,
                socraticReply: connector,
                deferred: false,
                correlationId: correlationId
            )

        case .modeClassify(let mode, let confidence, let reasoning):
            // Single mode_classify isn't a full reply — synthesize a placeholder.
            return TurnOutput(
                mode: ModeClassification(
                    mode: mode,
                    confidence: confidence,
                    reasoningSummary: reasoning
                ),
                surfacedPastWonder: nil,
                socraticReply: "(awaiting follow-up ask_back)",
                deferred: false,
                correlationId: correlationId
            )

        case .malformed(let reason, let raw):
            throw EngineError.make(
                domain: SocraticErrorDomain.model,
                code: .modelMalformedJSON,
                descriptionKO: "모델 응답을 해석할 수 없다.",
                descriptionEN: "Could not parse model output: \(reason). Raw: \(raw.prefix(200))"
            )
        }
    }
}
