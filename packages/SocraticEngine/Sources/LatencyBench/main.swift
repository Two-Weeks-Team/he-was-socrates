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
        var samples: [Sample] = []
        for (i, t) in benchTurns.enumerated() {
            FileHandle.standardError.write(
                Data("[latency-bench] turn \(i + 1)/\(benchTurns.count): \(t.label)\n".utf8)
            )
            let input = FunctionCallOrchestrator.TurnInput(
                utterance: t.utterance,
                language: .ko
            )
            let turnStart = nowMs()
            do {
                let out = try await orchestrator.runTurn(input)
                let turnMs = nowMs() - turnStart
                FileHandle.standardError.write(
                    Data(
                        "[latency-bench]   wall: \(Int(turnMs)) ms · reply chars: \(out.socraticReply.count) · deferred: \(out.deferred)\n"
                            .utf8
                    )
                )
                samples.append(
                    Sample(
                        label: t.label,
                        wallMs: turnMs,
                        replyChars: out.socraticReply.count,
                        deferred: out.deferred
                    )
                )
            } catch {
                FileHandle.standardError.write(Data("[latency-bench]   FAIL: \(error)\n".utf8))
            }
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
            summary: summary
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
