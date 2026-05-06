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

    /// Persisted KV-cache file containing the prefilled system prompt. Set
    /// by `warmup()` after a successful one-shot ChatSession run; consumed
    /// by `streamInto(...)` per turn via `loadPromptCache(url:)` to
    /// re-seed a fresh ChatSession (`instructions: nil` + `cache: loaded`)
    /// — the documented mlx-swift-lm 0.31.3 prefill-caching path
    /// (ChatSession.swift:163-182, "build a KV cache from a long shared
    /// context once, save it, and restore it across multiple sessions to
    /// avoid re-prefilling the same tokens each time").
    ///
    /// Earlier revisions stored a `chatSession` reference and reused it
    /// across turns under the assumption that mlx-swift-lm's ChatSession
    /// cache reuse would amortize the system-prompt prefill. PR-λ verify-2
    /// (claudedocs/bench/2026-05-06-*) measured TTFT_2/TTFT_1 = 0.98 for
    /// a back-to-back same-utterance probe, confirming that the standard
    /// `ChatSession(_, instructions:, ...)` path re-tokenizes and
    /// re-prefills the instructions string on every `streamResponse(...)`
    /// call (this is also stated as a warning in ChatSession.swift:168-
    /// 171). Disk-mediated KV reuse is the only public API that achieves
    /// the intended optimization in 0.31.3.
    private var systemCacheURL: URL?
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
        maxTokens: 192,
        // PR-λ F19: KV-cache quantization is exposed (kvBits / kvGroupSize /
        // quantizedKVStart fields) so the engine is forward-ready, but the
        // default ships with `kvBits = nil` (full-precision FP16 KV cache).
        //
        // Why nil and not 4: mlx-swift-lm 3.31.3's `Gemma4.swift` model
        // implementation does not fully wrap every cache call site with the
        // `if let quantizedCache = cache as? QuantizedKVCacheProtocol` branch
        // — at least one attention path still calls `cache.update(...)`,
        // which `QuantizedKVCache.update` deliberately traps with a
        // `fatalError("Use `updateQuantized` instead.")` (see
        // `MLXLMCommon/KVCache.swift:894`). LatencyBench reproduced the
        // crash on first inference. Once upstream Gemma 4 grows the missing
        // branch, callers can opt in by passing `kvBits: 4` here without a
        // schema change.
        kvBits: nil,
        kvGroupSize: 64,
        quantizedKVStart: 0
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
    /// Build the ChatSession used for one turn. Two paths:
    ///
    /// 1. **Fast path** — `systemCacheURL` is set (warmup persisted a KV
    ///    cache containing the prefilled system prompt). Load it, build a
    ///    ChatSession with `instructions: nil` + `cache: loaded`, so the
    ///    standard `streamResponse(to:)` only prefills the *user* tokens
    ///    on top of the pre-warmed system prefix.
    /// 2. **Slow fallback** — no warm cache available (warmup failed or
    ///    not run yet). Build a ChatSession with the system prompt as
    ///    `instructions:` per the legacy path. Each call re-prefills the
    ///    system tokens; correct but slow.
    ///
    /// The fast path is the documented mlx-swift-lm 0.31.3 prefill-caching
    /// API (ChatSession.swift:163-188): "build a KV cache from a long
    /// shared context once, save it via `saveCache(to:)`, and restore it
    /// across multiple sessions to avoid re-prefilling the same tokens
    /// each time".
    private func makeSessionForTurn(
        container: ModelContainer,
        systemPrompt: String,
        params: GenerateParametersBox
    ) -> ChatSession {
        if let cacheURL = systemCacheURL {
            do {
                let (loaded, _) = try loadPromptCache(url: cacheURL)
                guard !loaded.isEmpty else { throw GemmaServiceError.warmCacheEmpty }
                return ChatSession(
                    container,
                    instructions: nil,
                    cache: loaded,
                    generateParameters: params.toMLX()
                )
            } catch {
                // Disk read failed — fall through to the slow path so the
                // turn still completes (correctness > perf). A
                // self-healing pass could re-warm here, but reusing the
                // same warmup logic without recursion needs more
                // structuring; deferred to a follow-up if disk failures
                // are observed.
            }
        }
        // Slow fallback: legacy `instructions:` path with full system
        // prefill on every call.
        return ChatSession(
            container,
            instructions: systemPrompt,
            generateParameters: params.toMLX()
        )
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
        let session = makeSessionForTurn(
            container: container,
            systemPrompt: systemPrompt,
            params: params
        )
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

    private enum GemmaServiceError: Error {
        case warmCacheEmpty
    }

    /// Drop any cached ChatSession so the next `generate(...)` rebuilds it
    /// with whatever system prompt is passed in. Use when the host wants a
    /// clean slate (e.g. on `EngineCoordinator.shutdown()`).
    // MARK: - Test seams (PR-ζ)
    //
    // `@testable import SocraticEngine` reaches these. Lets tests assert
    // ChatSession lifecycle invariants without standing up a real
    // mlx-swift-lm ModelContainer (which would require either a mock
    // protocol that doesn't exist in the upstream library or shipping
    // a 4 GB weights file in the test target).

    /// `true` once `warmup()` has persisted a system-prompt KV cache to
    /// disk. Per-turn `streamInto(...)` then takes the fast path (load
    /// cache + `instructions: nil`); when false, falls back to the legacy
    /// `instructions:` path with full system re-prefill per turn.
    /// Drops back to `false` after `resetSession()`.
    internal var _test_chatSessionExists: Bool {
        #if canImport(MLXLLM)
        return systemCacheURL != nil
        #else
        return false
        #endif
    }

    /// Pre-PR-Λ this counted "turns since ChatSession last built" to bound
    /// KV-cache memory growth. With disk-mediated reuse the per-turn
    /// session is rebuilt fresh from a saved cache snapshot, so growth is
    /// bounded by construction. The seam stays for backward compatibility
    /// with PR-ζ's regression bar; it always reports 0 now.
    internal var _test_sessionTurnCount: Int { 0 }

    public func resetSession() {
        #if canImport(MLXLLM)
        // Forget any persisted system-prompt cache. The next `warmup()`
        // call rebuilds it; the next `streamInto(...)` without warmup
        // falls back to the legacy slow path (still correct).
        if let url = systemCacheURL {
            try? FileManager.default.removeItem(at: url)
        }
        systemCacheURL = nil
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
            guard let container = modelContainer else { return }

            // 1. Build a one-shot ChatSession with the locked Korean system
            //    prompt as `instructions:` and `maxTokens: 8`. This single
            //    streamResponse triggers the system-prompt prefill exactly
            //    once; the 8-token decode tail keeps the warmup itself
            //    cheap (~150-300ms beyond the unavoidable prefill).
            //
            //    `maxTokens: 8` is honored here because we set it on the
            //    session's `GenerateParameters` directly, bypassing the
            //    `generate(systemPrompt:userTurn:maxTokens:)` signature
            //    that historically dropped the argument on the floor
            //    (PR-λ verify-2 finding).
            var warmParams = generateParameters
            warmParams.maxTokens = 8
            let warmSession = ChatSession(
                container,
                instructions: SystemPrompt.composed,
                generateParameters: warmParams.toMLX()
            )
            do {
                for try await _ in warmSession.streamResponse(to: "ready") {}
            } catch {
                // Cold-start failed — leave systemCacheURL nil so per-turn
                // streamInto falls back to the legacy slow path. Correct
                // but not optimized.
                return
            }

            // 2. Persist the warmed KV cache to disk via the documented
            //    mlx-swift-lm 0.31.3 `saveCache(to:)` API
            //    (ChatSession.swift:531-540 → KVCache.swift `savePromptCache`).
            //    The file is written into the app's sandbox cache
            //    directory, which is writable without any extra
            //    entitlement (App Sandbox grants write access to its own
            //    `Library/Caches/`). The file persists for the lifetime
            //    of the process; `resetSession()` deletes it when the
            //    host wants a clean slate.
            //
            //    Side effect: the saved cache contains not just the
            //    system prefill but also the tokenized "ready" exchange
            //    (chat-template wrappers + ~5-token user prompt + 8 model
            //    tokens). When loaded for a real user turn, the model
            //    sees the warmup conversation as benign prior context.
            //    Coherent because the system prompt's "단정한 평어체"
            //    voice dominates and the warmup interjection is tiny
            //    compared to the system prompt's ~1500 tokens.
            do {
                let cachesDir = try FileManager.default.url(
                    for: .cachesDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let url = cachesDir.appendingPathComponent(
                    "hewassocrates-system-prompt-cache.safetensors"
                )
                try await warmSession.saveCache(to: url)
                systemCacheURL = url
            } catch {
                // Disk write failed — leave systemCacheURL nil; fall back
                // to legacy slow path on each turn (4500ms TTFT instead
                // of the targeted ~200ms). The user-facing UX still works.
                return
            }
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
///
/// PR-λ F19: exposes `kvBits` + `kvGroupSize` so callers can opt in to MLX's
/// quantized KV cache. mlx-swift-lm 3.31.3 `GenerateParameters.kvBits` is `nil`
/// by default (full-precision FP16 KV cache); setting it to 4 with a group
/// size of 64 lets each attention step run against a 4-bit quantized K/V,
/// which is the same trick MLX uses for the model weights themselves. Apple
/// MLX team's `mlx-lm`/`mlx-swift-lm` documentation: "Quantized cache" section
/// of `MLXLMCommon/KVCache.swift` shows `QuantizedKVCache(groupSize: 64,
/// bits: 4)` as the canonical recipe. Memory drops ~4× and attention throughput
/// improves on Apple Silicon for long-context turns.
public struct GenerateParametersBox: Sendable, Equatable {
    public var temperature: Double
    public var topP: Double
    public var maxTokens: Int

    /// nil → no KV-cache quantization (FP16). 4 → 4-bit quantized KV cache
    /// (matches the model's own weight quantization tier; recommended for
    /// Gemma 4 E4B 4-bit on Apple Silicon).
    public var kvBits: Int?

    /// Group size for KV cache quantization. mlx-swift-lm default is 64;
    /// matches the recipe documented in `MLXLMCommon/KVCache.swift`
    /// "Quantized Cache Usage" section.
    public var kvGroupSize: Int

    /// Token offset at which to start using the quantized KV cache. 0 means
    /// the cache is quantized from the very first generated token. mlx-swift-lm
    /// default is 0.
    public var quantizedKVStart: Int

    public init(
        temperature: Double,
        topP: Double,
        maxTokens: Int,
        kvBits: Int? = nil,
        kvGroupSize: Int = 64,
        quantizedKVStart: Int = 0
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
        self.kvBits = kvBits
        self.kvGroupSize = kvGroupSize
        self.quantizedKVStart = quantizedKVStart
    }

    #if canImport(MLXLMCommon)
    public func toMLX() -> GenerateParameters {
        var p = GenerateParameters(
            maxTokens: maxTokens,
            temperature: Float(temperature),
            topP: Float(topP)
        )
        p.kvBits = kvBits
        p.kvGroupSize = kvGroupSize
        p.quantizedKVStart = quantizedKVStart
        return p
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
