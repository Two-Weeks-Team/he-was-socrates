import Foundation

#if canImport(QuartzCore)
import QuartzCore
#endif

/// Drives the bust's viseme PNG swap at 30 fps with phoneme-rate hold.
/// Per `viseme-best-practices.md` §7.4: render rate 30 fps, but a viseme is
/// held for ≥ 2 frames (66 ms) before being eligible to swap, to avoid
/// strobing on rapid phoneme transitions.
///
/// Two ingestion paths:
///   1. `ingest(appleLabel:audioOffsetMs:)` — Apple AVSpeechSynthesisMarker.phoneme path
///   2. `ingestSchedule(_:)` — pre-computed (visemeID, audioOffsetMs) array
///       (used by ko-KR jamo time-uniform fallback when Apple emits no markers)
///
/// The driver maintains an "audio clock" that the host updates as TTS playback
/// progresses; whenever audio_clock crosses a scheduled marker offset, that
/// marker becomes the active target.
@MainActor
public final class VisemeDriver {

    public static let renderFPS: Double = 30
    public static let renderInterval: TimeInterval = 1.0 / renderFPS
    public static let minHoldFrames: Int = 2
    public static let reduceMotionFPS: Double = 12

    /// Drift > this threshold (ms) is logged as a perf alert.
    public static let driftAlertThresholdMs: Double = 50.0

    public private(set) var currentViseme: VisemeID = .REST
    public private(set) var renderRate: Double = renderFPS
    public private(set) var reduceMotion: Bool = false
    public private(set) var isRunning: Bool = false

    /// Fired on every visible swap.
    public var onVisemeChanged: ((VisemeID) -> Void)?

    /// Fired when a viseme swap was scheduled but ran late by > drift threshold.
    public var onDriftAlert:
        ((_ visemeID: VisemeID, _ scheduledMs: Double, _ actualMs: Double) -> Void)?

    private let phonemeMap: PhonemeMap
    private var pendingNextViseme: VisemeID?
    private var holdFramesRemaining: Int = 0

    private var schedule: [(viseme: VisemeID, audioOffsetMs: Double, ingestedAt: TimeInterval)] = []
    private var nextScheduleIndex: Int = 0

    /// Audio playback clock in milliseconds. Host updates this as TTS plays.
    public private(set) var audioClockMs: Double = 0

    /// Reference host time captured by `notePlaybackStarted()`. The tick loop
    /// derives `audioClockMs` from `(systemUptime - playbackStartHostTime) *
    /// 1000` whenever the host has not provided an explicit clock update.
    /// This makes the schedule drive lip-sync even when the TTS pipeline
    /// can't emit playback-time callbacks (current `AVSpeechSynthesizer` on
    /// macOS 26 emits zero phoneme markers AND no time updates — verdict
    /// "no-markers-anywhere" in spec/apple-phoneme-availability.json).
    private var playbackStartHostTime: TimeInterval?
    private var hasExplicitAudioClock: Bool = false

    private var timer: Timer?

    public init(phonemeMap: PhonemeMap = .default) {
        self.phonemeMap = phonemeMap
    }
    // Note: no explicit deinit. Timer closure uses [weak self] so a dead
    // VisemeDriver gracefully no-ops while the timer self-invalidates on the
    // next tick. Swift 6 strict concurrency forbids accessing the non-Sendable
    // Timer from a nonisolated deinit, so callers should invoke `stop()`
    // explicitly before releasing.

    // MARK: - Lifecycle

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        let interval = 1.0 / renderRate
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            [weak self] timer in
            // Self-invalidate when the driver is deallocated.
            guard self != nil else {
                timer.invalidate()
                return
            }
            // PR-η F10: the timer runs on `RunLoop.main`, so this body
            // already executes on the main thread. `MainActor.assumeIsolated`
            // (WWDC24 #10169) lets `tick()` run synchronously without
            // spawning 30 Tasks/sec through the cooperative pool — drops
            // 30 Hz of hop overhead AND removes a re-entrancy window
            // inside the tick body that the schedule loop assumes won't
            // be interleaved.
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    public func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        renderRate = enabled ? Self.reduceMotionFPS : Self.renderFPS
        if isRunning {
            stop()
            start()
        }
    }

    /// Reset state for a new utterance.
    public func reset() {
        schedule.removeAll()
        nextScheduleIndex = 0
        audioClockMs = 0
        pendingNextViseme = .REST
        playbackStartHostTime = nil
        hasExplicitAudioClock = false
    }

    // MARK: - Ingestion

    public func ingest(appleLabel: String, audioOffsetMs: Double) {
        let viseme = phonemeMap.viseme(forAppleLabel: appleLabel)
        appendSchedule(viseme: viseme, audioOffsetMs: audioOffsetMs)
    }

    public func ingestJamo(_ jamo: String, audioOffsetMs: Double) {
        let viseme = phonemeMap.viseme(forJamo: jamo)
        appendSchedule(viseme: viseme, audioOffsetMs: audioOffsetMs)
    }

    public func ingestSchedule(_ schedule: [(viseme: VisemeID, audioOffsetMs: Double)]) {
        for entry in schedule {
            appendSchedule(viseme: entry.viseme, audioOffsetMs: entry.audioOffsetMs)
        }
    }

    private func appendSchedule(viseme: VisemeID, audioOffsetMs: Double) {
        let stamp = ProcessInfo.processInfo.systemUptime
        schedule.append((viseme: viseme, audioOffsetMs: audioOffsetMs, ingestedAt: stamp))
    }

    // MARK: - Audio clock

    /// Host (TTSManager) calls this when TTS begins.
    public func notePlaybackStarted() {
        audioClockMs = 0
        playbackStartHostTime = ProcessInfo.processInfo.systemUptime
        hasExplicitAudioClock = false
    }

    /// Host calls this every frame with the current TTS audio playback offset.
    /// If the host doesn't provide updates, the tick loop falls back to a
    /// host-clock derivation seeded by `notePlaybackStarted()`.
    public func updateAudioClock(_ ms: Double) {
        audioClockMs = ms
        hasExplicitAudioClock = true
    }

    // MARK: - Tick

    /// Advance one render frame.
    public func tick() {
        // If the host pipeline does not feed an explicit audio clock (true
        // for AVSpeechSynthesizer on current macOS — see header note), we
        // derive one from the host monotonic clock anchored at the last
        // `notePlaybackStarted()` call. Explicit `updateAudioClock(_:)` wins
        // when present, preserving the existing test contract.
        if !hasExplicitAudioClock, let start = playbackStartHostTime {
            audioClockMs = (ProcessInfo.processInfo.systemUptime - start) * 1000.0
        }

        // Reduce Motion Tier 3 talking cue (viseme-best-practices.md §7.6 +
        // WCAG 2.3.3 "Animation from Interactions"): when Reduce Motion is on
        // AND an utterance is playing, swap REST ↔ AA on a 500 ms square wave
        // instead of running phoneme-driven swaps. The user still sees the
        // bust "talking" but at a non-phoneme cadence that won't trigger
        // motion sensitivity. When playback isn't active, hold REST.
        if reduceMotion {
            let isSpeaking = playbackStartHostTime != nil
            let target: VisemeID
            if isSpeaking {
                let halfCycles = Int(floor(audioClockMs / 500.0))
                target = (halfCycles % 2 == 0) ? .AA : .REST
            } else {
                target = .REST
            }
            if target != currentViseme {
                currentViseme = target
                onVisemeChanged?(currentViseme)
            }
            return
        }

        // Promote any scheduled viseme whose audio offset has been reached.
        while nextScheduleIndex < schedule.count {
            let next = schedule[nextScheduleIndex]
            if audioClockMs >= next.audioOffsetMs {
                pendingNextViseme = next.viseme
                let drift = audioClockMs - next.audioOffsetMs
                if drift > Self.driftAlertThresholdMs {
                    onDriftAlert?(next.viseme, next.audioOffsetMs, audioClockMs)
                }
                nextScheduleIndex += 1
            } else {
                break
            }
        }

        if holdFramesRemaining > 0 {
            holdFramesRemaining -= 1
        }

        if holdFramesRemaining == 0,
            let next = pendingNextViseme,
            next != currentViseme
        {
            currentViseme = next
            pendingNextViseme = nil
            holdFramesRemaining = Self.minHoldFrames
            onVisemeChanged?(currentViseme)
        }
    }

    // MARK: - Diagnostics

    public func diagnosticSnapshot() -> [String: any Sendable] {
        return [
            "currentViseme": currentViseme.rawValue,
            "renderRate": renderRate,
            "reduceMotion": reduceMotion,
            "audioClockMs": audioClockMs,
            "scheduleQueued": schedule.count,
            "nextScheduleIndex": nextScheduleIndex,
            "holdFramesRemaining": holdFramesRemaining,
        ]
    }
}
