import Foundation

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers
#endif

/// MLX-Swift bridge to the Gemma 4 E4B 4-bit model via mlx-swift-lm 3.31.3.
///
/// Phase 4 design (now active):
///   - Uses `LLMRegistry.gemma4_e4b_it_4bit` which points to
///     `mlx-community/gemma-4-e4b-it-4bit`
///   - `LLMModelFactory.shared.loadContainer(...)` downloads the model on
///     first launch (~3.97 GB) into `~/Library/Caches/com.apple.MLX/...`
///   - Subsequent launches reuse the cached weights
///   - `ChatSession` provides streaming token output as `AsyncSequence<String>`
///   - System prompt comes from `SystemPrompt.composed` (locked Korean Socratic)
///   - Output expected as JSON object → `FunctionCallParser` → `Result`
///
/// Stage 5 day-1 verification:
///   1. First launch on dev machine downloads ~3.97 GB to cache.
///   2. Run a test utterance; confirm model emits valid function-call JSON.
///   3. Optionally bundle weights into app `Resources/` for offline-first
///      install (per `idea.spec.json` no-runtime-download policy). When
///      bundled, set `useBundledWeights = true` so we skip HuggingFace fetch.
///
/// `.stub` mode remains available for tests + dev-fast-path.
public actor GemmaService {

    public enum RuntimeMode: Sendable, Equatable {
        case stub  // canned JSON responses, no MLX
        case real  // mlx-swift-lm via LLMRegistry.gemma4_e4b_it_4bit
    }

    public enum LoadState: Sendable {
        case unloaded
        case loading(progress: Double)
        case ready(weightsSHA256: String, mode: RuntimeMode)
        case failed(String)
    }

    public private(set) var loadState: LoadState = .unloaded
    public let mode: RuntimeMode

    #if canImport(MLXLLM)
    private var modelContainer: ModelContainer?

    /// Reused across turns. The locked Korean Socratic system prompt is
    /// ~5,000 chars / ~1,500-2,000 tokens; creating a new ChatSession every
    /// turn would force a full re-prefill on each user utterance and was
    /// the dominant component of the observed 9-11s/turn latency. Holding
    /// the session lets mlx-swift-lm reuse its KV cache across turns: the
    /// system prefill happens exactly once, and subsequent turns only pay
    /// for the new user input + response decode.
    private var chatSession: ChatSession?
    private var sessionTurnCount: Int = 0

    /// Cap accumulated turns per session to bound KV-cache memory growth on
    /// long sessions (an hour of conversation can otherwise build a multi-
    /// thousand-token KV state). 20 turns ≈ 4-5 minutes of natural Socratic
    /// dialogue; well within attention budget for Gemma 4 E4B's 256K context
    /// while keeping prefill on `streamResponse` fast.
    private static let sessionTurnLimit = 20
    #endif

    /// Generation parameters per Stage 5 day-1 tuning. Temperature 0.0 makes
    /// the model deterministic — required for SC5 wondering-log replay
    /// reproducibility (M01 14-month time-jump scene).
    ///
    /// `maxTokens: 192` covers the function-call JSON wrap (~30 tokens) plus
    /// a Korean Socratic question of typical length (~80-120 tokens). Was
    /// 256; reducing it shaves the worst-case generation tail off turns
    /// where the model would otherwise keep emitting trailing whitespace
    /// past the closing `}` before EOS.
    public var generateParameters: GenerateParametersBox = GenerateParametersBox(
        temperature: 0.0,
        topP: 1.0,
        maxTokens: 192
    )

    public init(mode: RuntimeMode = .stub) {
        self.mode = mode
    }

    public func loadModel() async throws {
        switch mode {
        case .stub:
            loadState = .loading(progress: 0)
            try await Task.sleep(nanoseconds: 50_000_000)
            loadState = .ready(weightsSHA256: "stub-no-real-weights", mode: .stub)

        case .real:
            #if canImport(MLXLLM)
            loadState = .loading(progress: 0)
            do {
                let container = try await LLMModelFactory.shared.loadContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: LLMRegistry.gemma4_e4b_it_4bit
                ) { progress in
                    Task { [weak self] in
                        await self?.updateProgress(progress.fractionCompleted)
                    }
                }
                self.modelContainer = container
                // PR-γ: HF download progress callbacks may stop arriving
                // before reaching 1.0 (the last chunk completes synchronously
                // inside `loadContainer`). Explicitly emit 100% so any UI
                // bound to `loadState.loading(progress)` reaches 1.0 before
                // we transition to `.ready` — closes finding N-CRIT-7.
                loadState = .loading(progress: 1.0)
                loadState = .ready(
                    weightsSHA256: "(mlx-swift-lm cache verified by HF SHA)",
                    mode: .real
                )
            } catch {
                loadState = .failed("MLX load: \(error.localizedDescription)")
                throw EngineError.make(
                    domain: SocraticErrorDomain.model,
                    code: .modelLoadFailed,
                    descriptionKO: "Gemma 4 모델을 불러오지 못했다.",
                    descriptionEN: "Failed to load Gemma 4 model.",
                    underlying: error
                )
            }
            #else
            loadState = .failed("MLXLLM not available")
            throw EngineError.make(
                domain: SocraticErrorDomain.model,
                code: .modelLoadFailed,
                descriptionKO: "MLX 사용 불가.",
                descriptionEN: "MLX not available."
            )
            #endif
        }
    }

    private func updateProgress(_ p: Double) {
        if case .loading = loadState {
            loadState = .loading(progress: p)
        }
    }

    #if canImport(MLXLLM)
    /// Lazily build (or recycle) the per-session ChatSession. Recycles after
    /// `sessionTurnLimit` turns so the KV cache stays bounded during long
    /// conversations.
    private func ensureChatSession(
        container: ModelContainer,
        systemPrompt: String,
        params: GenerateParametersBox
    ) -> ChatSession {
        if let existing = chatSession, sessionTurnCount < Self.sessionTurnLimit {
            return existing
        }
        let session = ChatSession(
            container,
            instructions: systemPrompt,
            generateParameters: params.toMLX()
        )
        chatSession = session
        sessionTurnCount = 0
        return session
    }

    /// Actor-isolated stream pump. The strict-concurrency rule against
    /// sending a non-Sendable ChatSession into a nonisolated `AsyncStream`
    /// task forces this split: the outer `generate` only constructs the
    /// stream + a Task, and that Task immediately re-enters the actor here
    /// where the session capture is legal.
    private func streamInto(
        _ continuation: AsyncStream<String>.Continuation,
        systemPrompt: String,
        userTurn: String
    ) async {
        guard let container = modelContainer else {
            continuation.finish()
            return
        }
        let params = generateParameters
        let session = ensureChatSession(
            container: container,
            systemPrompt: systemPrompt,
            params: params
        )
        sessionTurnCount += 1
        do {
            for try await chunk in session.streamResponse(to: userTurn) {
                continuation.yield(chunk)
            }
        } catch {
            continuation.yield(
                """
                {"function":"defer_to_human","args":{"trigger_category":"other","suggested_resource_class":"system","explanation_phrase":"모델 추론 오류가 발생했다."}}
                """
            )
        }
        continuation.finish()
    }
    #endif

    /// Drop any cached ChatSession so the next `generate(...)` rebuilds it
    /// with whatever system prompt is passed in. Use when the host wants a
    /// clean slate (e.g. on `EngineCoordinator.shutdown()`).
    public func resetSession() {
        #if canImport(MLXLLM)
        chatSession = nil
        sessionTurnCount = 0
        #endif
    }

    /// Run one throwaway turn to warm the inference path (KV cache, GPU
    /// pipeline state objects, system-prompt prefill) so the first
    /// user-visible turn doesn't pay the cold-start cost. Output is
    /// discarded. Failure is non-fatal — callers may still proceed; the
    /// first real turn will simply pay the warm-up cost itself.
    public func warmup() async {
        switch mode {
        case .stub:
            return
        case .real:
            #if canImport(MLXLLM)
            guard modelContainer != nil else { return }
            do {
                let stream = try await generate(
                    systemPrompt: SystemPrompt.composed,
                    userTurn: "ready",
                    maxTokens: 8
                )
                for await _ in stream {}
            } catch {
                // intentional no-op; cold-start hit just shifts to turn 1.
            }

            // PR-γ: clear the warmup turn's user/assistant pair from the
            // ChatSession history so the user's first real turn is not
            // conditioned on a "ready"/throwaway exchange. The system
            // instructions remain installed — `ChatSession.clear()`
            // documented contract: "Clear the session history and cache,
            // preserving system instructions" (mlx-swift-lm 0.31.3
            // ChatSession.swift:492-497, Apple Inc. © 2025).
            //
            // We considered `ChatSession.clear()` (mlx-swift-lm 0.31.3
            // ChatSession.swift:492-497, "Clear the session history and
            // cache, preserving system instructions"), but `ChatSession`
            // is a non-Sendable `final class` and the `await
            // session.clear()` edge trips Swift 6 strict-concurrency
            // SendingRisksDataRace from inside our actor. The mlx-swift-lm
            // class is owned exclusively by this actor and serializes
            // internally via SerialAccessContainer, so the data race risk
            // is theoretical only — but rather than silence it with
            // `nonisolated(unsafe)` we drop the session entirely after
            // warmup. The next `streamInto` rebuilds it.
            //
            // Cost analysis: rebuilding `ChatSession` is a struct alloc
            // plus the first-call system-prefill (~600-800 ms on M2 Pro
            // for our 1.5-2k token system prompt). The Metal kernel JIT,
            // GPU pipeline state objects, and weight residency live in
            // the underlying `ModelContainer` (unchanged), so the
            // dominant warmup benefit survives. Net effect on user's
            // first real turn: equivalent to "warmup ran, ChatSession
            // built fresh" — clean conversation history, no contamination
            // by the throwaway "ready" exchange (Perf engineer's V/Lead's
            // V finding).
            chatSession = nil
            sessionTurnCount = 0
            #endif
        }
    }

    /// Streaming JSON output. Yields chunks of the function-call JSON; caller
    /// accumulates and parses at end-of-stream.
    public func generate(systemPrompt: String, userTurn: String, maxTokens: Int = 256) async throws
        -> AsyncStream<String>
    {
        switch mode {
        case .stub:
            return AsyncStream { continuation in
                Task {
                    let canned = stubCannedResponse(forUserTurn: userTurn)
                    let chunks = canned.chunked(into: 8)
                    for chunk in chunks {
                        try? await Task.sleep(nanoseconds: 60_000_000)
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                }
            }

        case .real:
            #if canImport(MLXLLM)
            guard modelContainer != nil else {
                throw EngineError.make(
                    domain: SocraticErrorDomain.model,
                    code: .modelLoadFailed,
                    descriptionKO: "모델이 로드되지 않았다.",
                    descriptionEN: "Model is not loaded."
                )
            }
            return AsyncStream { continuation in
                Task { [weak self] in
                    guard let self else {
                        continuation.finish()
                        return
                    }
                    await self.streamInto(
                        continuation,
                        systemPrompt: systemPrompt,
                        userTurn: userTurn
                    )
                }
            }
            #else
            throw EngineError.make(
                domain: SocraticErrorDomain.model,
                code: .modelLoadFailed,
                descriptionKO: "MLX 사용 불가.",
                descriptionEN: "MLX not available."
            )
            #endif
        }
    }

    public func runTurn(systemPrompt: String, userTurn: String) async throws
        -> FunctionCallParser.Result
    {
        let stream = try await generate(systemPrompt: systemPrompt, userTurn: userTurn)
        var assembled = ""
        for await chunk in stream {
            assembled += chunk
        }
        return FunctionCallParser.parse(assembled)
    }

    // MARK: - Stub responses (Phase 1-3, also dev fallback)

    private nonisolated func stubCannedResponse(forUserTurn turn: String) -> String {
        let lower = turn.lowercased()
        let regulatedKeywords = [
            "변호사", "lawyer", "법", "law", "의사", "doctor", "약물", "약", "응급",
            "주식", "stock", "투자", "invest", "보험", "insurance", "복지", "welfare",
        ]
        if regulatedKeywords.contains(where: lower.contains) {
            return """
                {"function":"defer_to_human","args":{"trigger_category":"other","suggested_resource_class":"전문가","explanation_phrase":"이 질문은 전문가의 도움이 필요해 보인다. 자네에게 더 적합한 사람을 찾아보라."}}
                """
        }
        return """
            {"function":"ask_back","args":{"question":"좋다. 그 말에서 가장 중요한 단어는 무엇인가?","language":"ko"}}
            """
    }
}

/// Sendable wrapper so we can pass parameters into Tasks.
public struct GenerateParametersBox: Sendable, Equatable {
    public var temperature: Double
    public var topP: Double
    public var maxTokens: Int

    public init(temperature: Double, topP: Double, maxTokens: Int) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
    }

    #if canImport(MLXLMCommon)
    public func toMLX() -> GenerateParameters {
        GenerateParameters(
            maxTokens: maxTokens,
            temperature: Float(temperature),
            topP: Float(topP)
        )
    }
    #endif
}

extension String {
    fileprivate func chunked(into size: Int) -> [String] {
        var result: [String] = []
        var current = startIndex
        while current < endIndex {
            let next = index(current, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(String(self[current..<next]))
            current = next
        }
        return result
    }
}
