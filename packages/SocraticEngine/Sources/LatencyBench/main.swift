// LatencyBench — out-of-process latency floor measurement.
//
// Loads the real Gemma 4 E4B 4-bit MLX weights through the same call paths
// the app uses (GemmaService.real → LLMRegistry.gemma4_e4b_it_4bit →
// FunctionCallOrchestrator.runTurn) and reports wall-clock samples for:
//
//   • model load (cold)            — one-time cost on first launch / cache miss
//   • warmup turn                  — PR-γ warmup (then ChatSession dropped)
//   • turns 1..N (post-warmup)     — measured per-turn wall in milliseconds
//
// Output is pretty-printed JSON to stdout — easy to paste into the audit
// report for a documented citation. No GUI, no STT, no TTS — this isolates
// the *decode* portion of per-turn latency, which is the dominant term on
// Apple Silicon at the Gemma 4 E4B 4-bit quantization tier.
//
// Total per-turn user latency in the live app =
//      decode wall (this bench)
//    + Apple-natural STT endpointing (~300–500 ms, documented)
//    + AVSpeechSynthesizer prepare-to-start (~50–100 ms, cached voice path)
//
// Invocation (reuse weights staged by the sandboxed app, no re-download):
//
//   HF_HUB_CACHE="$HOME/Library/Containers/com.twoweeks.hewassocrates/Data/Library/Caches/huggingface/hub" \
//     swift run -c release --package-path packages/SocraticEngine LatencyBench
//
// HF_HUB_CACHE is read by swift-huggingface CacheLocationProvider
// (https://github.com/huggingface/swift-huggingface) before the LLM loader
// touches the network.

import Foundation
import SocraticEngine

#if canImport(MLX)
import MLX
#endif

// MARK: - Configuration

/// 10 timed turns post-warmup. Korean Socratic-style inputs covering the
/// curious-adult / stuck-thinker / regulated-class branches so the bench
/// reflects realistic mode_classify routing, not just a single hot path.
/// 10 samples is the minimum for honest p10/p90 reporting.
private let benchTurns: [(label: String, utterance: String)] = [
    (
        label: "ask-back/curious-adult-1",
        utterance: "왜 사람들은 자신과 다른 의견을 가진 사람을 미워하게 될까?"
    ),
    (
        label: "ask-back/stuck-thinker-1",
        utterance: "내가 정말로 이 결정을 후회하지 않을지 모르겠어."
    ),
    (
        label: "ask-back/curious-adult-2",
        utterance: "정의로운 사회란 어떤 모습일까?"
    ),
    (
        label: "defer/regulated-medical",
        utterance: "최근에 가슴이 자주 아픈데 어떻게 해야 할까?"
    ),
    (
        label: "ask-back/curious-adult-3",
        utterance: "용기와 무모함의 차이는 무엇일까?"
    ),
    (
        label: "ask-back/stuck-thinker-2",
        utterance: "친구와 다툰 후 먼저 사과해야 할지 망설여진다."
    ),
    (
        label: "ask-back/curious-adult-4",
        utterance: "행복은 추구하는 것일까, 결과로 따라오는 것일까?"
    ),
    (
        label: "defer/regulated-financial",
        utterance: "지금 가진 적금을 깨고 주식에 투자해도 될까?"
    ),
    (
        label: "ask-back/curious-adult-5",
        utterance: "지식과 지혜는 무엇이 다를까?"
    ),
    (
        label: "ask-back/stuck-thinker-3",
        utterance: "오랫동안 미뤄온 일을 시작하기가 두렵다."
    ),
]

// MARK: - Helpers

private func nowMs() -> Double {
    return Date().timeIntervalSince1970 * 1000.0
}

private struct Sample: Codable {
    let label: String
    let wallMs: Double
    let replyChars: Int
    let deferred: Bool

    // Measurement-only extension to verify whether the gap between bench
    // wallMs (~6 s) and the expected decode-only latency for the parsed
    // reply length is explained by the model emitting trailing tokens
    // past the closing `}`. See claudedocs/bench/* for the running
    // hypothesis log; the JSON keys below are additive so older readers
    // that only consume the fields above are unaffected.
    let firstChunkMs: Double  // TTFT — start to first non-empty chunk
    let chunkCount: Int  // # of chunks streamed (≈ token count for token-level streaming)
    let rawChars: Int  // total raw chars accumulated from the stream
    let closingBraceAt: Int  // index of last `}` in raw stream (-1 if none)
    let trailingChars: Int  // raw chars emitted AFTER the closing `}`
}

private struct DeviceProof: Codable {
    let mlxDefaultDevice: String
    let mlxDefaultDeviceType: String
    let gpuActiveBytesBefore: Int
    let gpuActiveBytesAfter: Int
    let gpuPeakBytes: Int
    let gpuCacheBytes: Int
    let metalLibLoaded: Bool
}

/// Path-comparison probe: runs the same utterance twice on the same
/// `GemmaService`, with `resetSession()` called between to delete the
/// warmed system-prompt cache file. Shot 1 takes the fast path (load
/// pre-warmed `[KVCache]` + `instructions: nil`); shot 2 takes the slow
/// fallback (`instructions: SystemPrompt.composed` re-prefill).
///
/// `ttftRatio = slow / fast`. Expected ≥ 10 once disk-mediated KV reuse
/// is enabled (PR-Λ): the slow path re-prefills ~1500 system tokens
/// every turn, the fast path skips them. A ratio near 1 would indicate
/// the fast path is broken (regression).
///
/// The earlier hypothesis-1 probe (back-to-back shots without a reset
/// between) lost meaning under the disk-mediated reuse model — both
/// shots become identical fast-path operations and ratio collapses to
/// ~1.0 trivially. The new shot ordering preserves regression-detection
/// value across PR-Λ.
private struct ProbeShot: Codable {
    let label: String
    let wallMs: Double
    let firstChunkMs: Double
    let chunkCount: Int
    let rawChars: Int
}

private struct ReuseProbe: Codable {
    let utterance: String
    let shots: [ProbeShot]
    /// shot2.firstChunkMs (slow) / shot1.firstChunkMs (fast).
    /// ≥ 10 → fast path enabled (slow path is ~20-25× costlier).
    /// ≈ 1 → fast path broken or warmup never produced a cache.
    let ttftRatio: Double
}

private struct Result: Codable {
    let host: String
    let timestamp: String
    let modelTag: String
    let kvBits: Int?
    let kvGroupSize: Int
    let device: DeviceProof
    let loadMs: Double
    let warmupMs: Double
    let turns: [Sample]
    let summary: Summary
    /// Optional — present only when the bench's reuse probe ran (the
    /// existing JSON fields above are unaffected if a downstream reader
    /// pre-dates this addition).
    let reuseProbe: ReuseProbe?

    struct Summary: Codable {
        let n: Int
        let medianMs: Double
        let p10Ms: Double
        let p90Ms: Double
        let meanMs: Double
        let minMs: Double
        let maxMs: Double
    }
}

private func percentile(_ sorted: [Double], _ p: Double) -> Double {
    guard !sorted.isEmpty else { return 0 }
    if sorted.count == 1 { return sorted[0] }
    let rank = p * Double(sorted.count - 1)
    let lo = Int(floor(rank))
    let hi = Int(ceil(rank))
    if lo == hi { return sorted[lo] }
    let frac = rank - Double(lo)
    return sorted[lo] * (1 - frac) + sorted[hi] * frac
}

private func median(_ xs: [Double]) -> Double {
    let s = xs.sorted()
    if s.isEmpty { return 0 }
    if s.count % 2 == 1 { return s[s.count / 2] }
    return (s[s.count / 2 - 1] + s[s.count / 2]) / 2.0
}

// MARK: - Entry point

@main
struct LatencyBench {
    static func main() async {
        let host = ProcessInfo.processInfo.hostName
        let timestamp = ISO8601DateFormatter().string(from: Date())

        if ProcessInfo.processInfo.environment["HF_HUB_CACHE"] == nil
            && ProcessInfo.processInfo.environment["HF_HOME"] == nil
        {
            FileHandle.standardError.write(
                Data(
                    """
                    [latency-bench] WARNING: HF_HUB_CACHE / HF_HOME not set. swift-huggingface
                    will fall back to ~/.cache/huggingface/hub and may attempt a 4 GB download.
                    For an offline reuse of the sandboxed app's cache, set:
                      export HF_HUB_CACHE="$HOME/Library/Containers/com.twoweeks.hewassocrates/Data/Library/Caches/huggingface/hub"

                    """.utf8
                )
            )
        }

        // 0) Device proof — print MLX default device + GPU memory before any
        //    inference to confirm Metal is actually wired. If the metallib
        //    failed to load we'd have errored out at first MLX call; reaching
        //    here with .gpu means Metal is initialized.
        var defaultDeviceDesc = "(MLX not linked)"
        var defaultDeviceType = "unknown"
        var gpuMemBefore = 0
        var gpuMemAfter = 0
        var gpuPeak = 0
        var gpuCache = 0
        var metalOK = false
        #if canImport(MLX)
        let dev = Device.defaultDevice()
        defaultDeviceDesc = String(describing: dev)
        defaultDeviceType = String(describing: dev.deviceType)
        gpuMemBefore = MLX.GPU.activeMemory
        FileHandle.standardError.write(
            Data(
                "[latency-bench] MLX default device: \(defaultDeviceDesc) (type=\(defaultDeviceType))\n"
                    .utf8
            )
        )
        FileHandle.standardError.write(
            Data("[latency-bench] GPU active memory before load: \(gpuMemBefore) bytes\n".utf8)
        )
        metalOK = (defaultDeviceType.lowercased().contains("gpu"))
        #endif

        FileHandle.standardError.write(Data("[latency-bench] loading Gemma 4 E4B 4-bit...\n".utf8))

        let gemma = GemmaService(mode: .real)
        let orchestrator = FunctionCallOrchestrator(gemma: gemma)
        let kvBits = await gemma.generateParameters.kvBits
        let kvGroup = await gemma.generateParameters.kvGroupSize
        FileHandle.standardError.write(
            Data(
                "[latency-bench] KV cache quantization: bits=\(kvBits.map(String.init) ?? "nil") groupSize=\(kvGroup)\n"
                    .utf8
            )
        )

        // 1) Model load
        let loadStart = nowMs()
        do {
            try await gemma.loadModel()
        } catch {
            FileHandle.standardError.write(
                Data("[latency-bench] FATAL load failed: \(error)\n".utf8)
            )
            exit(1)
        }
        let loadMs = nowMs() - loadStart
        FileHandle.standardError.write(Data("[latency-bench] load: \(Int(loadMs)) ms\n".utf8))

        // 2) Warmup (PR-γ contract: throwaway turn + ChatSession drop)
        let warmStart = nowMs()
        await gemma.warmup()
        let warmupMs = nowMs() - warmStart
        FileHandle.standardError.write(Data("[latency-bench] warmup: \(Int(warmupMs)) ms\n".utf8))

        // 3) N timed turns
        //
        // We call `gemma.generate(...)` directly instead of
        // `orchestrator.runTurn(...)` so we can observe the raw stream
        // (chunk count, TTFT, trailing-char tail past the closing `}`).
        // The user-turn formatting and JSON parsing are reproduced here
        // 1:1 with FunctionCallOrchestrator so the parsed-reply contract
        // is unchanged. Generation behavior is NOT touched — no early
        // break, no maxTokens override.
        _ = orchestrator  // silence unused-variable diagnostic
        var samples: [Sample] = []
        for (i, t) in benchTurns.enumerated() {
            FileHandle.standardError.write(
                Data("[latency-bench] turn \(i + 1)/\(benchTurns.count): \(t.label)\n".utf8)
            )
            let userTurn = SystemPrompt.userTurn(
                utterance: t.utterance,
                language: .ko,
                recentHistory: ""
            )
            let turnStart = nowMs()
            var firstChunkMs: Double = -1
            var raw = ""
            var chunkCount = 0
            do {
                let stream = try await gemma.generate(
                    systemPrompt: SystemPrompt.composed,
                    userTurn: userTurn
                )
                for await chunk in stream {
                    if firstChunkMs < 0 && !chunk.isEmpty {
                        firstChunkMs = nowMs() - turnStart
                    }
                    raw += chunk
                    chunkCount += 1
                }
            } catch {
                FileHandle.standardError.write(Data("[latency-bench]   FAIL: \(error)\n".utf8))
                continue
            }
            let turnMs = nowMs() - turnStart

            // Reproduce FunctionCallOrchestrator's parsed-reply contract
            // so the existing `replyChars` + `deferred` JSON fields keep
            // their meaning. Any other parser branch contributes the same
            // empty-reply / non-deferred default the orchestrator uses for
            // mode_classify-only or malformed responses (Phase 1 stub).
            let parseResult = FunctionCallParser.parse(raw)
            let deferred: Bool
            let parsedReply: String
            switch parseResult {
            case .askBack(let q, _):
                deferred = false
                parsedReply = q
            case .deferToHuman(_, _, let exp):
                deferred = true
                parsedReply = exp
            case .surfacePastWonder(let connector, _):
                deferred = false
                parsedReply = connector
            case .modeClassify, .malformed:
                deferred = false
                parsedReply = ""
            }

            // Trailing-char metric: how many raw chars the model emits
            // AFTER the last closing `}`. If this is consistently large
            // (> 100), the model is generating a long whitespace/newline
            // tail until maxTokens fires — the hypothesis under test.
            let lastBraceAt: Int
            if let idx = raw.lastIndex(of: "}") {
                lastBraceAt = raw.distance(from: raw.startIndex, to: idx)
            } else {
                lastBraceAt = -1
            }
            let trailingChars = lastBraceAt >= 0 ? raw.count - 1 - lastBraceAt : raw.count

            FileHandle.standardError.write(
                Data(
                    "[latency-bench]   wall: \(Int(turnMs)) ms · ttft: \(Int(firstChunkMs)) ms · chunks: \(chunkCount) · raw: \(raw.count) chars · trail: \(trailingChars) · reply: \(parsedReply.count) · deferred: \(deferred)\n"
                        .utf8
                )
            )
            // Korean Socratic quality preview — truncated to 80 chars (≈ 1
            // tweet line) so a reviewer can spot-check that warmup's "ready"
            // contamination didn't push the model off-voice. stderr only,
            // not in JSON, to keep the bench file shape stable for diffs.
            let preview =
                parsedReply.count > 80
                ? String(parsedReply.prefix(80)) + "…"
                : parsedReply
            FileHandle.standardError.write(
                Data("[latency-bench]   reply: \(preview)\n".utf8)
            )
            samples.append(
                Sample(
                    label: t.label,
                    wallMs: turnMs,
                    replyChars: parsedReply.count,
                    deferred: deferred,
                    firstChunkMs: firstChunkMs,
                    chunkCount: chunkCount,
                    rawChars: raw.count,
                    closingBraceAt: lastBraceAt,
                    trailingChars: trailingChars
                )
            )
        }

        let walls = samples.map { $0.wallMs }.sorted()
        let summary = Result.Summary(
            n: samples.count,
            medianMs: median(walls),
            p10Ms: percentile(walls, 0.10),
            p90Ms: percentile(walls, 0.90),
            meanMs: walls.isEmpty ? 0 : walls.reduce(0, +) / Double(walls.count),
            minMs: walls.first ?? 0,
            maxMs: walls.last ?? 0
        )

        // 4) Path-comparison probe — runs the same utterance twice with a
        //    `resetSession()` between to delete the warmed cache file.
        //    Shot 1 = fast path (warmup-built cache still present), Shot 2
        //    = slow fallback path (cache deleted, ChatSession built with
        //    full `instructions:` re-prefill on every call). The TTFT
        //    ratio (slow/fast) is the headline regression metric for
        //    PR-Λ: should land in the 10-25× range.
        FileHandle.standardError.write(
            Data(
                "[latency-bench] probe: path comparison (fast vs slow fallback)\n".utf8
            )
        )
        let probeUtterance = benchTurns[0].utterance
        let probeUserTurn = SystemPrompt.userTurn(
            utterance: probeUtterance,
            language: .ko,
            recentHistory: ""
        )

        @Sendable func runProbeShot(label: String) async -> ProbeShot {
            let start = nowMs()
            var ttft: Double = -1
            var chunks = 0
            var raw = ""
            do {
                let stream = try await gemma.generate(
                    systemPrompt: SystemPrompt.composed,
                    userTurn: probeUserTurn
                )
                for await chunk in stream {
                    if ttft < 0 && !chunk.isEmpty { ttft = nowMs() - start }
                    chunks += 1
                    raw += chunk
                }
            } catch {
                FileHandle.standardError.write(
                    Data("[latency-bench]   probe \(label) FAIL: \(error)\n".utf8)
                )
            }
            return ProbeShot(
                label: label,
                wallMs: nowMs() - start,
                firstChunkMs: ttft,
                chunkCount: chunks,
                rawChars: raw.count
            )
        }

        // Shot 1: fast path. The 10 timed turns above already exercised it,
        // but we measure the same utterance fresh to keep the JSON entry
        // self-contained.
        let shot1 = await runProbeShot(label: "fast-path")
        // Reset clears the warmed `systemCacheURL` and deletes the file on
        // disk, forcing the next call into the legacy `instructions:`
        // path.
        await gemma.resetSession()
        // Shot 2: slow fallback. Same utterance, no warmed cache.
        let shot2 = await runProbeShot(label: "slow-fallback")
        let ttftRatio: Double =
            shot1.firstChunkMs > 0 ? shot2.firstChunkMs / shot1.firstChunkMs : 0
        FileHandle.standardError.write(
            Data(
                "[latency-bench]   shot 1 fast-path:     wall=\(Int(shot1.wallMs)) ttft=\(Int(shot1.firstChunkMs)) chunks=\(shot1.chunkCount) raw=\(shot1.rawChars)\n"
                    .utf8
            )
        )
        FileHandle.standardError.write(
            Data(
                "[latency-bench]   shot 2 slow-fallback: wall=\(Int(shot2.wallMs)) ttft=\(Int(shot2.firstChunkMs)) chunks=\(shot2.chunkCount) raw=\(shot2.rawChars)\n"
                    .utf8
            )
        )
        let verdict =
            ttftRatio >= 10
            ? "FAST PATH ENABLED"
            : (ttftRatio >= 3 ? "FAST PATH PARTIAL" : "FAST PATH DISABLED OR BROKEN")
        FileHandle.standardError.write(
            Data(
                "[latency-bench]   ttft ratio (slow/fast): \(String(format: "%.2f", ttftRatio))  → \(verdict)\n"
                    .utf8
            )
        )
        let reuseProbe = ReuseProbe(
            utterance: probeUtterance,
            shots: [shot1, shot2],
            ttftRatio: ttftRatio
        )

        #if canImport(MLX)
        gpuMemAfter = MLX.GPU.activeMemory
        gpuPeak = MLX.GPU.peakMemory
        gpuCache = MLX.GPU.cacheMemory
        FileHandle.standardError.write(
            Data(
                "[latency-bench] GPU active memory after bench: \(gpuMemAfter) bytes (Δ=\(gpuMemAfter - gpuMemBefore))\n"
                    .utf8
            )
        )
        FileHandle.standardError.write(
            Data(
                "[latency-bench] GPU peak memory: \(gpuPeak) bytes  cache: \(gpuCache) bytes\n".utf8
            )
        )
        #endif

        let device = DeviceProof(
            mlxDefaultDevice: defaultDeviceDesc,
            mlxDefaultDeviceType: defaultDeviceType,
            gpuActiveBytesBefore: gpuMemBefore,
            gpuActiveBytesAfter: gpuMemAfter,
            gpuPeakBytes: gpuPeak,
            gpuCacheBytes: gpuCache,
            metalLibLoaded: metalOK
        )

        let result = Result(
            host: host,
            timestamp: timestamp,
            modelTag: "mlx-community/gemma-4-e4b-it-4bit",
            kvBits: kvBits,
            kvGroupSize: kvGroup,
            device: device,
            loadMs: loadMs,
            warmupMs: warmupMs,
            turns: samples,
            summary: summary,
            reuseProbe: reuseProbe
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(result), let json = String(data: data, encoding: .utf8) {
            print(json)
        } else {
            FileHandle.standardError.write(
                Data("[latency-bench] FATAL: failed to encode result\n".utf8)
            )
            exit(2)
        }
    }
}
