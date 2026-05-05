import Foundation
#if canImport(MLX)
import MLX
import MLXNN
#endif

/// MLX-Swift bridge to the Gemma 4 E4B 4-bit model.
///
/// Phase 4 architecture:
///   - Model directory bundled at `Resources/gemma-4-e4b-it-4bit/`
///     (config.json + tokenizer + weights.safetensors files)
///   - Source: https://huggingface.co/mlx-community/gemma-4-e4b-it-4bit
///   - Integrity verified on first launch via `ModelIntegrity.verify(...)`
///   - Inference runs on Apple Silicon Metal via mlx-swift 0.31.3
///   - System prompt + per-turn user prompt produced by `SystemPrompt.composed`
///   - Output parsed by `FunctionCallParser` into a typed `FunctionCallParser.Result`
///
/// Phase 4 day-1 work item (deferred from Phase 1):
///   - Vendor MLXLLM loader code from mlx-swift-examples
///   - OR write a minimal Gemma 4 transformer forward pass in MLXNN
///   - OR adopt swift-transformers + MLX backend if community port lands
///
/// Until day-1 lands, this service runs in `.stub` mode returning canned
/// JSON-shaped Socratic responses to exercise the rest of the pipeline.
public actor GemmaService {

    public enum RuntimeMode: Sendable, Equatable {
        case stub      // Phase 1-3 — canned responses
        case real      // Phase 4 day-1+ — real MLX inference
    }

    public enum LoadState: Sendable {
        case unloaded
        case loading
        case ready(weightsSHA256: String, mode: RuntimeMode)
        case failed(String)
    }

    public private(set) var loadState: LoadState = .unloaded
    public let mode: RuntimeMode

    public init(mode: RuntimeMode = .stub) {
        self.mode = mode
    }

    /// Locate the bundled model directory. Phase 4 will populate this with
    /// real weights + tokenizer files.
    public static func bundledModelURL() -> URL? {
        return Bundle.main.url(forResource: ModelIntegrity.modelTag, withExtension: nil)
    }

    public func loadModel() async throws {
        loadState = .loading
        switch mode {
        case .stub:
            try await Task.sleep(nanoseconds: 50_000_000)
            loadState = .ready(weightsSHA256: "stub-no-real-weights", mode: .stub)
        case .real:
#if canImport(MLX)
            // Phase 4 day-1 placeholder. Real implementation:
            //   1. Locate model directory (bundledModelURL or app-support cache)
            //   2. Verify SHA-256 via ModelIntegrity.verify
            //   3. Load tokenizer (sentencepiece-style for Gemma)
            //   4. Load weights into MLX-NN modules (Gemma 4 architecture)
            //   5. Set MLX device to GPU
            guard let modelURL = Self.bundledModelURL() else {
                let err = "Bundled model not found at Resources/\(ModelIntegrity.modelTag)/"
                loadState = .failed(err)
                throw EngineError.make(
                    domain: SocraticErrorDomain.model,
                    code: .modelLoadFailed,
                    descriptionKO: "Gemma 모델 파일을 앱 번들에서 찾을 수 없습니다.",
                    descriptionEN: "Gemma model bundle missing in app Resources."
                )
            }

            let weightsURL = modelURL.appendingPathComponent("model.safetensors")
            let outcome = try ModelIntegrity.verify(weightsAt: weightsURL)
            switch outcome {
            case .ok(let actual):
                loadState = .ready(weightsSHA256: actual, mode: .real)
            case .mismatch(let actual, let expected):
                loadState = .failed("SHA mismatch: \(actual) ≠ \(expected)")
                throw EngineError.make(
                    domain: SocraticErrorDomain.model,
                    code: .modelFileCorrupt,
                    descriptionKO: "Gemma 모델 파일 무결성 검증 실패.",
                    descriptionEN: "Gemma model integrity check failed."
                )
            case .skippedDevMode:
                loadState = .ready(weightsSHA256: "dev-mode-skip", mode: .real)
            case .fileMissing:
                loadState = .failed("weights file missing")
                throw EngineError.make(
                    domain: SocraticErrorDomain.model,
                    code: .modelFileCorrupt,
                    descriptionKO: "Gemma 가중치 파일이 누락되었습니다.",
                    descriptionEN: "Gemma weights file is missing."
                )
            }

            // TODO Phase 4 day-1+: actual MLX-NN model construction.
#else
            loadState = .failed("MLX not available on this build")
            throw EngineError.make(
                domain: SocraticErrorDomain.model,
                code: .modelLoadFailed,
                descriptionKO: "MLX 사용 불가.",
                descriptionEN: "MLX not available."
            )
#endif
        }
    }

    /// Streaming JSON output. Yields chunks of the function-call JSON; caller
    /// accumulates and parses at end-of-stream (or after first balanced `}`).
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
            return AsyncStream { continuation in
                Task {
                    // Phase 4 day-1+: real MLX-NN forward pass with sampling loop.
                    continuation.yield(stubCannedResponse(forUserTurn: userTurn))
                    continuation.finish()
                }
            }
        }
    }

    /// Convenience: parse the full assembled JSON response.
    public func runTurn(systemPrompt: String, userTurn: String) async throws -> FunctionCallParser.Result {
        let stream = try await generate(systemPrompt: systemPrompt, userTurn: userTurn)
        var assembled = ""
        for await chunk in stream {
            assembled += chunk
        }
        return FunctionCallParser.parse(assembled)
    }

    // MARK: - Stub responses (Phase 1-3)

    private nonisolated func stubCannedResponse(forUserTurn turn: String) -> String {
        let lower = turn.lowercased()
        // Heuristic: detect regulated-advice triggers in stub mode so the
        // pipeline exercises defer_to_human flow without real inference.
        let regulatedKeywords = ["변호사", "lawyer", "법", "law", "의사", "doctor", "약물", "약", "응급",
                                 "주식", "stock", "투자", "invest", "보험", "insurance", "복지", "welfare"]
        if regulatedKeywords.contains(where: lower.contains) {
            return """
            {"function":"defer_to_human","args":{"trigger_category":"other","suggested_resource_class":"전문가","explanation_phrase":"이 질문은 전문가의 도움이 필요해 보인다. 자네에게 더 적합한 사람을 찾아보라."}}
            """
        }
        // Default: ask_back with a Socratic-style canned re-question.
        return """
        {"function":"ask_back","args":{"question":"좋다. 그 말에서 가장 중요한 단어는 무엇인가?","language":"ko"}}
        """
    }
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
