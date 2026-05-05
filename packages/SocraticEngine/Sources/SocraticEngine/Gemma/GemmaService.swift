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
        case stub      // canned JSON responses, no MLX
        case real      // mlx-swift-lm via LLMRegistry.gemma4_e4b_it_4bit
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
#endif

    /// Generation parameters per Stage 5 day-1 tuning. Temperature 0.0 makes
    /// the model deterministic — required for SC5 wondering-log replay
    /// reproducibility (M01 14-month time-jump scene).
    public var generateParameters: GenerateParametersBox = GenerateParametersBox(
        temperature: 0.0,
        topP: 1.0,
        maxTokens: 256
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

    /// Streaming JSON output. Yields chunks of the function-call JSON; caller
    /// accumulates and parses at end-of-stream.
    public func generate(systemPrompt: String, userTurn: String, maxTokens: Int = 256) async throws -> AsyncStream<String> {
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
            guard let container = modelContainer else {
                throw EngineError.make(
                    domain: SocraticErrorDomain.model,
                    code: .modelLoadFailed,
                    descriptionKO: "모델이 로드되지 않았다.",
                    descriptionEN: "Model is not loaded."
                )
            }
            let params = generateParameters
            return AsyncStream { continuation in
                Task {
                    do {
                        let session = ChatSession(
                            container,
                            instructions: systemPrompt,
                            generateParameters: params.toMLX()
                        )
                        for try await chunk in session.streamResponse(to: userTurn) {
                            continuation.yield(chunk)
                        }
                        continuation.finish()
                    } catch {
                        continuation.yield("""
                        {"function":"defer_to_human","args":{"trigger_category":"other","suggested_resource_class":"system","explanation_phrase":"모델 추론 오류가 발생했다."}}
                        """)
                        continuation.finish()
                    }
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

    public func runTurn(systemPrompt: String, userTurn: String) async throws -> FunctionCallParser.Result {
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
        let regulatedKeywords = ["변호사", "lawyer", "법", "law", "의사", "doctor", "약물", "약", "응급",
                                 "주식", "stock", "투자", "invest", "보험", "insurance", "복지", "welfare"]
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

private extension String {
    func chunked(into size: Int) -> [String] {
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
