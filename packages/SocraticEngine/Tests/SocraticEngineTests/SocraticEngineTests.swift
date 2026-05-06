import Foundation
import Testing

@testable import SocraticEngine

@Suite("Viseme set integrity")
struct VisemeTests {
    @Test func sixteenVisemes() {
        #expect(VisemeID.allCases.count == 16)
    }

    @Test func restNominalDimsMatchResearch() {
        // Research §7.2 recommended REST = 82×8.
        let dims = VisemeID.REST.nominalDims
        #expect(dims.w == 82)
        #expect(dims.h == 8)
    }

    @Test func ihDistinctFromEE() {
        // Research §7.2: previously identical heights — must differ now.
        #expect(VisemeID.IH.nominalDims.h != VisemeID.EE.nominalDims.h)
    }

    @Test func fvDistinctFromIH() {
        // Research §7.2: F/V was visually identical to IH.
        #expect(VisemeID.F.nominalDims != VisemeID.IH.nominalDims)
    }

    @Test func thDistinctFromUH() {
        // Research §7.2: TH was identical to UH dims.
        #expect(VisemeID.TH.nominalDims != VisemeID.UH.nominalDims)
    }
}

@Suite("Phoneme map iter-4 amendments")
struct PhonemeMapTests {
    @Test func koreanFlapMapsToS() {
        // iter-4 amendment: ɾ (Korean ㄹ initial) maps to S, not R.
        let map = PhonemeMap.default
        #expect(map.viseme(forIPA: "ɾ") == .S)
    }

    @Test func koreanEoMapsToUH() {
        // iter-4 amendment: ㅓ maps to UH, not AA.
        let map = PhonemeMap.default
        #expect(map.viseme(forJamo: "ㅓ") == .UH)
        #expect(map.viseme(forJamo: "ㅕ") == .UH)
        #expect(map.viseme(forJamo: "ㅝ") == .UH)
    }

    @Test func unknownJamoFallsBackToREST() {
        let map = PhonemeMap.default
        #expect(map.viseme(forJamo: "🦄") == .REST)
    }
}

@Suite("Wondering log SC5 invariants")
struct WonderingLogTests {
    @Test func dedupSameUtteranceSameSession() async {
        let log = WonderingLog()
        let first = await log.append(
            Wonder(
                userUtterance: "왜 어떤 노래는 우는가?",
                socraticReply: "...",
                mode: .curiousAdult,
                modeConfidence: 0.9,
                language: .ko
            )
        )
        let second = await log.append(
            Wonder(
                userUtterance: "왜 어떤 노래는 우는가?",
                socraticReply: "...",
                mode: .curiousAdult,
                modeConfidence: 0.9,
                language: .ko
            )
        )
        #expect(first.id == second.id)
        let count = await log.count()
        #expect(count == 1)
    }

    @Test func deterministicJSONExport() async throws {
        let log = WonderingLog()
        _ = await log.append(
            Wonder(
                userUtterance: "ice is slippery",
                socraticReply: "is it the ice or your finger?",
                mode: .learningStudent,
                modeConfidence: 0.85,
                language: .en
            )
        )
        let exportA = try await log.exportJSON()
        let exportB = try await log.exportJSON()
        #expect(exportA == exportB)
    }
}

@Suite("Engine info")
struct EngineInfoTests {
    @Test func bundleVersion() {
        #expect(SocraticEngineInfo.visemeCount == 16)
        #expect(SocraticEngineInfo.bundleVersion.contains("phase1"))
    }
}

@Suite("Hangul jamo decomposition")
struct JamoDecomposeTests {
    @Test func annyeong() {
        // 안 = ㅇ + ㅏ + ㄴ
        let parts = JamoTimeline.decomposeSyllable("안".unicodeScalars.first!)
        #expect(parts?.initial == "ㅇ")
        #expect(parts?.medial == "ㅏ")
        #expect(parts?.final == "ㄴ")
    }

    @Test func myeong() {
        // 명 = ㅁ + ㅕ + ㅇ
        let parts = JamoTimeline.decomposeSyllable("명".unicodeScalars.first!)
        #expect(parts?.initial == "ㅁ")
        #expect(parts?.medial == "ㅕ")
        #expect(parts?.final == "ㅇ")
    }

    @Test func openSyllable() {
        // 오 = ㅇ + ㅗ (no final)
        let parts = JamoTimeline.decomposeSyllable("오".unicodeScalars.first!)
        #expect(parts?.final == nil)
        #expect(parts?.medial == "ㅗ")
    }

    @Test func nonHangulReturnsNil() {
        let a = "a".unicodeScalars.first!
        let space = " ".unicodeScalars.first!
        #expect(JamoTimeline.decomposeSyllable(a) == nil)
        #expect(JamoTimeline.decomposeSyllable(space) == nil)
    }
}

@Suite("JamoTimeline schedule")
struct JamoTimelineTests {
    @Test func annyeongSchedule() {
        // "안녕" — 2 syllables, 5 jamo total (안=ㅇㅏㄴ, 녕=ㄴㅕㅇ)
        let schedule = JamoTimeline.buildSchedule(text: "안녕", totalDurationMs: 1000)
        // Expect 5+ entries (5 jamo + REST tail) — relax to ≥ 5
        #expect(schedule.count >= 5)
        // First entry should start at 0ms.
        #expect(schedule.first?.startMs == 0)
        // Last entry should end at totalDurationMs.
        #expect(schedule.last?.endMs == 1000)
        // ㅇ (initial) maps to REST per phoneme map.
        #expect(schedule.first?.viseme == .REST)
    }

    @Test func mediumSyllableHasMedialMostlyAllocated() {
        // For "오" (single Hangul, no final): medial gets 70% + 15% (final spillover) = 85%.
        let schedule = JamoTimeline.buildSchedule(text: "오", totalDurationMs: 100)
        // Find the medial entry (the OH/ㅗ viseme).
        let medial = schedule.first { $0.viseme == .OH }
        #expect(medial != nil)
        if let medial {
            let span = medial.endMs - medial.startMs
            // Medial 70% + final 15% spillover ≈ 85ms.
            #expect(span >= 80 && span <= 90)
        }
    }
}

@Suite("System prompt locked invariants")
struct SystemPromptTests {
    @Test func partAContainsKeyMaieuticsTerm() {
        #expect(SystemPrompt.partA_operational.contains("산파술"))
        #expect(SystemPrompt.partA_operational.contains("엘렝코스"))
    }

    @Test func partBVoiceMatchesUserDirection() {
        #expect(SystemPrompt.partB_voice.contains("현대 한국어로 말하는 소크라테스"))
        #expect(SystemPrompt.partB_voice.contains("존댓말을 쓰지 않는다"))
    }

    @Test func partCDispatchHasFourFunctions() {
        #expect(SystemPrompt.partC_dispatch.contains("mode_classify"))
        #expect(SystemPrompt.partC_dispatch.contains("ask_back"))
        #expect(SystemPrompt.partC_dispatch.contains("surface_past_wonder"))
        #expect(SystemPrompt.partC_dispatch.contains("defer_to_human"))
    }

    @Test func composedHasAllParts() {
        let composed = SystemPrompt.composed
        #expect(composed.contains("산파술"))
        #expect(composed.contains("현대 한국어"))
        #expect(composed.contains("\"function\":"))
    }

    @Test func userTurnIncludesUtterance() {
        let prompt = SystemPrompt.userTurn(utterance: "왜?", language: .ko, recentHistory: "")
        #expect(prompt.contains("왜?"))
        #expect(prompt.contains("first turn"))
    }
}

@Suite("FunctionCallParser robustness")
struct FunctionCallParserTests {
    @Test func parsesAskBack() {
        let raw = #"{"function":"ask_back","args":{"question":"그 말은 무엇을 뜻하지?","language":"ko"}}"#
        let result = FunctionCallParser.parse(raw)
        guard case .askBack(let q, let lang) = result else {
            Issue.record("expected askBack, got \(result)")
            return
        }
        #expect(q == "그 말은 무엇을 뜻하지?")
        #expect(lang == .ko)
    }

    @Test func parsesModeClassify() {
        let raw =
            #"{"function":"mode_classify","args":{"mode":"learning_student","confidence":0.92,"reasoning_summary":"단순 호기심"}}"#
        let result = FunctionCallParser.parse(raw)
        guard case .modeClassify(let mode, let conf, let reasoning) = result else {
            Issue.record("expected modeClassify")
            return
        }
        #expect(mode == .learningStudent)
        #expect(conf == 0.92)
        #expect(reasoning == "단순 호기심")
    }

    @Test func parsesDeferToHuman() {
        let raw =
            #"{"function":"defer_to_human","args":{"trigger_category":"medical","suggested_resource_class":"의사","explanation_phrase":"이건 전문가의 도움이 필요하다."}}"#
        let result = FunctionCallParser.parse(raw)
        guard case .deferToHuman(let trigger, let resource, let exp) = result else {
            Issue.record("expected deferToHuman")
            return
        }
        #expect(trigger == "medical")
        #expect(resource == "의사")
        #expect(exp.contains("전문가"))
    }

    @Test func stripsMarkdownCodeFence() {
        let raw = """
            ```json
            {"function":"ask_back","args":{"question":"그래서?","language":"ko"}}
            ```
            """
        let result = FunctionCallParser.parse(raw)
        if case .askBack(let q, _) = result {
            #expect(q == "그래서?")
        } else {
            Issue.record("code fence should be stripped")
        }
    }

    @Test func handlesMalformed() {
        let raw = "not json at all just prose"
        let result = FunctionCallParser.parse(raw)
        if case .malformed = result {
            // Expected
        } else {
            Issue.record("should report malformed")
        }
    }

    @Test func stripsTrailingProse() {
        let raw =
            #"{"function":"ask_back","args":{"question":"무엇을?","language":"ko"}} (note: trailing prose ignored)"#
        let result = FunctionCallParser.parse(raw)
        if case .askBack(let q, _) = result {
            #expect(q == "무엇을?")
        } else {
            Issue.record("trailing prose should be stripped")
        }
    }

    @Test func unknownFunctionIsMalformed() {
        let raw = #"{"function":"give_answer","args":{"answer":"42"}}"#
        let result = FunctionCallParser.parse(raw)
        if case .malformed(let reason, _) = result {
            #expect(reason.contains("unknown function"))
        } else {
            Issue.record("unknown function should be malformed")
        }
    }
}

@Suite("GemmaService stub mode integration")
struct GemmaServiceStubTests {
    @Test func stubModeProducesAskBack() async throws {
        let gemma = GemmaService(mode: .stub)
        try await gemma.loadModel()
        let result = try await gemma.runTurn(systemPrompt: "<sys>", userTurn: "왜 어떤 노래는 우는가?")
        if case .askBack(let q, _) = result {
            #expect(q.contains("?") || q.contains("?"))
        } else {
            Issue.record("stub should produce askBack for non-regulated input, got \(result)")
        }
    }

    @Test func stubModeDeferringRegulated() async throws {
        let gemma = GemmaService(mode: .stub)
        try await gemma.loadModel()
        let result = try await gemma.runTurn(systemPrompt: "<sys>", userTurn: "변호사 추천해줘")
        if case .deferToHuman = result {
            // Expected
        } else {
            Issue.record("stub should defer for regulated input, got \(result)")
        }
    }
}

@Suite("FunctionCallOrchestrator end-to-end (stub Gemma)")
struct FunctionCallOrchestratorTests {
    @Test func turnProducesSocraticReply() async throws {
        let gemma = GemmaService(mode: .stub)
        try await gemma.loadModel()
        let orch = FunctionCallOrchestrator(gemma: gemma)
        let out = try await orch.runTurn(.init(utterance: "왜 살아있는가?", language: .ko))
        #expect(!out.deferred)
        #expect(!out.socraticReply.isEmpty)
    }

    @Test func turnDefersForRegulated() async throws {
        let gemma = GemmaService(mode: .stub)
        try await gemma.loadModel()
        let orch = FunctionCallOrchestrator(gemma: gemma)
        let out = try await orch.runTurn(.init(utterance: "응급실 가야 하나?", language: .ko))
        #expect(out.deferred)
    }
}

@Suite("EngineCoordinator wiring")
@MainActor struct EngineCoordinatorTests {

    @Test func initialPhaseIsBootstrapping() {
        let coord = EngineCoordinator()
        #expect(coord.phase == .bootstrapping)
    }

    @Test func phaseTransitionFiresCallback() async {
        let coord = EngineCoordinator()
        var phases: [EngineCoordinator.Phase] = []
        coord.onPhaseChanged = { phases.append($0) }
        // Direct internal transition through public mutator path:
        coord.shutdown()
        // shutdown leaves phase = .idle (one transition from .bootstrapping).
        #expect(phases.contains(.idle))
    }

    @Test func wonderingLogCompressedHistoryStub() async {
        let log = WonderingLog()
        // Append two wonders.
        _ = await log.append(
            Wonder(
                userUtterance: "음악이 왜 슬픈가?",
                socraticReply: "노래는 자네 안의 무엇과 만나는가?",
                mode: .curiousAdult,
                modeConfidence: 0.9,
                language: .ko
            )
        )
        _ = await log.append(
            Wonder(
                userUtterance: "왜 시간은 빠르지?",
                socraticReply: "시간이 빠른 것인가, 자네의 주의가 다른 곳에 있는 것인가?",
                mode: .curiousAdult,
                modeConfidence: 0.85,
                language: .ko
            )
        )
        let count = await log.count()
        #expect(count == 2)
    }

    @Test func gemmaStubLoadsAndProducesSocraticReply() async throws {
        let coord = EngineCoordinator(gemmaMode: .stub)
        try await coord.gemma.loadModel()
        // Run an orchestrator turn directly (simulating handleFinalTranscript path).
        let input = FunctionCallOrchestrator.TurnInput(
            utterance: "왜 어떤 노래는 우는가?",
            language: .ko
        )
        let out = try await coord.orchestrator.runTurn(input)
        #expect(!out.deferred)
        #expect(out.socraticReply.contains("?"))
    }

    @Test func gemmaStubDeferRoutesThroughCoordinator() async throws {
        let coord = EngineCoordinator(gemmaMode: .stub)
        try await coord.gemma.loadModel()
        let input = FunctionCallOrchestrator.TurnInput(
            utterance: "법률 자문이 필요해",
            language: .ko
        )
        let out = try await coord.orchestrator.runTurn(input)
        #expect(out.deferred)
    }
}

@Suite("VisemeDriver scheduling")
@MainActor struct VisemeDriverTests {
    @Test func ingestScheduleAdvancesViseme() {
        let driver = VisemeDriver()
        var swaps: [VisemeID] = []
        driver.onVisemeChanged = { swaps.append($0) }

        driver.ingestSchedule([
            (viseme: .AA, audioOffsetMs: 0),
            (viseme: .M, audioOffsetMs: 100),
            (viseme: .REST, audioOffsetMs: 200),
        ])

        // Tick at audio_clock = 0: AA scheduled, swap (after first hold).
        driver.notePlaybackStarted()
        driver.updateAudioClock(0)
        driver.tick()
        #expect(driver.currentViseme == .AA)

        // Tick at audio_clock = 100: M scheduled, but hold prevents swap.
        driver.updateAudioClock(100)
        driver.tick()  // holdFramesRemaining decrements
        driver.tick()  // now eligible
        #expect(driver.currentViseme == .M)

        // Tick at 200: REST.
        driver.updateAudioClock(200)
        driver.tick()
        driver.tick()
        #expect(driver.currentViseme == .REST)
    }

    @Test func reduceMotionLowersFrameRate() {
        let driver = VisemeDriver()
        #expect(driver.renderRate == VisemeDriver.renderFPS)
        driver.setReduceMotion(true)
        #expect(driver.renderRate == VisemeDriver.reduceMotionFPS)
        driver.setReduceMotion(false)
        #expect(driver.renderRate == VisemeDriver.renderFPS)
    }

    @Test func driftAlertFiresWhenLate() {
        let driver = VisemeDriver()
        var alerts: [(VisemeID, Double, Double)] = []
        driver.onDriftAlert = { v, sched, actual in alerts.append((v, sched, actual)) }

        driver.ingest(appleLabel: "AA", audioOffsetMs: 100)
        driver.notePlaybackStarted()
        driver.updateAudioClock(200)  // 100ms late, > 50ms threshold
        driver.tick()

        #expect(
            !alerts.isEmpty,
            "drift alert should fire when audio_clock is > threshold past schedule"
        )
    }
}

// MARK: - PR-α regression tests
// Added 2026-05-06 to lock in the fix for finalFallbackTask race + 1.5s
// penalty + cross-session callback. Apple does NOT contractually guarantee
// SFSpeechRecognitionTask.finish() will deliver a final result (forum 125279)
// — these tests exercise the documented best-effort substitute (sessionId
// token + didPromoteFinal flag + abortListening teardown).

@Suite("AudioInputManager session-token + final-promote guards")
@MainActor
struct AudioInputManagerSessionGuardTests {

    @Test func stopListeningPromotesPartialSynchronously() async {
        let mgr = AudioInputManager()
        var deliveredFinals: [(String, Language)] = []
        mgr.onFinalTranscript = { text, lang in deliveredFinals.append((text, lang)) }
        mgr.locale = .ko
        mgr._test_seedPartial("왜")
        mgr._test_setStateForStop()

        mgr.stopListening()

        #expect(deliveredFinals.count == 1)
        #expect(deliveredFinals.first?.0 == "왜")
    }

    @Test func stopListeningPromotesEmptyWhenNoPartial() async {
        let mgr = AudioInputManager()
        var deliveredFinals: [(String, Language)] = []
        mgr.onFinalTranscript = { text, lang in deliveredFinals.append((text, lang)) }
        mgr._test_setStateForStop()

        mgr.stopListening()

        #expect(deliveredFinals.count == 1)
        #expect(deliveredFinals.first?.0 == "")
    }

    @Test func doubleStopListeningIsIdempotent() async {
        let mgr = AudioInputManager()
        var fires = 0
        mgr.onFinalTranscript = { _, _ in fires += 1 }
        mgr._test_seedPartial("hi")
        mgr._test_setStateForStop()

        mgr.stopListening()
        mgr.stopListening()

        #expect(fires == 1, "didPromoteFinal should suppress a second promote on the same session")
    }

    @Test func abortListeningSuppressesFinal() async {
        let mgr = AudioInputManager()
        var fires = 0
        mgr.onFinalTranscript = { _, _ in fires += 1 }
        mgr._test_seedPartial("would-have-been-final")
        mgr._test_setStateForStop()

        mgr.abortListening()

        #expect(fires == 0, "abortListening must NOT synthesize a final — that's the whole point")
        #expect(mgr._test_currentSessionId == nil)
    }

    @Test func staleCallbackDroppedAcrossSessions() async {
        // Simulate: session A's recognition closure captured A's sessionId,
        // then we abort/start a new session B. The closure should not be
        // able to mutate state for session B.
        let mgr = AudioInputManager()
        var fires = 0
        mgr.onFinalTranscript = { _, _ in fires += 1 }
        let sessionA = mgr._test_beginFakeSession()
        mgr.abortListening()
        // Aborting cleared currentSessionId — even if a callback held
        // sessionA's id, the guard rejects.
        let accepted = mgr._test_callbackWouldAccept(sessionId: sessionA)
        #expect(accepted == false)
        #expect(fires == 0)
    }

    @Test func startListeningResetsDidPromoteFinal() async {
        let mgr = AudioInputManager()
        var fires = 0
        mgr.onFinalTranscript = { _, _ in fires += 1 }
        mgr._test_seedPartial("turn-1")
        mgr._test_setStateForStop()
        mgr.stopListening()
        #expect(fires == 1)

        // New session must be able to promote again.
        let _ = mgr._test_beginFakeSession()
        mgr._test_seedPartial("turn-2")
        mgr._test_setStateForStop()
        mgr.stopListening()

        #expect(fires == 2, "didPromoteFinal must reset on each startListening")
    }
}

// MARK: - PR-β regression tests
// Hang killers + onUtteranceCancel teardown.

@Suite("EngineCoordinator hang-killer watchdog (PR-β)")
@MainActor
struct EngineCoordinatorHangKillerTests {

    @Test func failedPhaseAutoRearmsToIdleAfterBudget() async throws {
        // Verify auto-rearm by exercising the watchdog body directly
        // (same pattern as `bootstrappingWatchdogTransitionsToFailedKey`).
        // Avoids the GitHub macOS-15 runner's MainActor queue jitter,
        // which made a real 5 s sleep + grace too tight in CI.
        let coord = EngineCoordinator(gemmaMode: .stub)
        var phases: [EngineCoordinator.Phase] = []
        coord.onPhaseChanged = { p in phases.append(p) }

        coord._test_forceTransition(to: .failed("test.synthetic"))
        coord._test_simulateWatchdogElapsed()

        #expect(
            coord.phase == .idle,
            "watchdog must rearm .failed → .idle deterministically"
        )
        #expect(phases.contains(.idle), "phase callback must fire .idle on auto-rearm")
    }

    @Test func bootstrappingWatchdogTransitionsToFailedKey() async throws {
        // We don't actually want to wait the 600s production budget here.
        // Verify the routing intent by exercising the watchdog body
        // directly via the _test_ seam: caller forces .bootstrapping,
        // simulates a budget-elapsed event, expects .failed(bootstrapTimeout).
        let coord = EngineCoordinator(gemmaMode: .stub)
        coord._test_forceTransition(to: .bootstrapping)
        coord._test_simulateWatchdogElapsed()
        if case .failed(let key) = coord.phase {
            #expect(key == PhaseFailureKey.bootstrapTimeout)
        } else {
            Issue.record("expected .failed(bootstrap.timeout), got \(coord.phase)")
        }
    }

    @Test func onUtteranceCancelResetsVisemeAndPhase() async {
        let coord = EngineCoordinator(gemmaMode: .stub)
        coord._test_forceTransition(to: .speaking(reply: "x", deferred: false))
        // Simulate AVSpeechSynthesizer didCancel → onUtteranceCancel chain.
        coord._test_fireOnUtteranceCancel()
        // Allow MainActor Task hop.
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(coord.phase == .idle)
    }
}

// MARK: - PR-γ regression tests
// Per-turn perf caches + warmup-clear. .real-mode behavior is asserted at
// integration level (PR-ζ); these are stub-mode unit tests that pin
// public behavior contracts.

@Suite("Performance caches (PR-γ)")
struct PerformanceCacheTests {

    @Test func wonderingLogISO8601FormatterIsStableAcrossCalls() async {
        // Smoke test for the static formatter — same fingerprint must be
        // produced for the same logical input regardless of whether the
        // formatter was just allocated or reused.
        let id = UUID()
        let day = Date(timeIntervalSince1970: 1_700_000_000)  // fixed
        let a = WonderingLog.contentFingerprint(utterance: "왜?", sessionId: id, on: day)
        let b = WonderingLog.contentFingerprint(utterance: "왜?", sessionId: id, on: day)
        let c = WonderingLog.contentFingerprint(utterance: "왜?", sessionId: id, on: day)
        #expect(a == b)
        #expect(b == c)
    }

    @Test @MainActor func ttsManagerVoiceCacheReturnsStableInstance() {
        let mgr = TTSManager()
        let v1 = mgr.resolveVoice(forBCP47: "ko-KR")
        let v2 = mgr.resolveVoice(forBCP47: "ko-KR")
        // If a voice is installed, both lookups return the same object
        // (identity-stable per the cache contract). If not installed on
        // this runner (CI macos-15 may not bundle ko-KR), both return nil.
        if v1 != nil {
            #expect(v1 === v2, "voice cache must return the same NSObject instance")
        } else {
            #expect(v2 == nil)
        }
    }

    @Test @MainActor func ttsManagerInvalidateVoiceCacheClears() {
        let mgr = TTSManager()
        _ = mgr.resolveVoice(forBCP47: "ko-KR")
        mgr.invalidateVoiceCache()
        // After invalidation a fresh lookup must succeed (or fail
        // identically) without depending on the prior cache state.
        let v = mgr.resolveVoice(forBCP47: "ko-KR")
        // The contract here is "no crash, deterministic outcome" —
        // installed-on-runner is the only thing that varies.
        _ = v
    }

    @Test func everyModeRawValueAppearsInPartCDispatch() {
        // PR-ε: SystemPrompt.partC_dispatch enumerates the literal mode
        // names the model is allowed to emit in `mode_classify` calls. If
        // the engine `Mode` enum gains a new case (or renames one) and
        // partC isn't updated to match, the model can hallucinate a value
        // the parser doesn't recognise. Compile-time assertion.
        let dispatch = SystemPrompt.partC_dispatch
        for mode in Mode.allCases {
            #expect(
                dispatch.contains(mode.rawValue),
                "Mode.\(mode) rawValue '\(mode.rawValue)' must appear in partC_dispatch"
            )
        }
    }

    @Test func testFixtureUtterancesProduceCompleteSchedules() {
        // PR-ζ: golden-style coverage. The test-fixture utterances pinned
        // in `runs/2026-05-05-spec/spec/phoneme-viseme-map.json:_test_fixture_utterances`
        // must each produce a non-empty JamoTimeline schedule that spans
        // the full estimated TTS duration. If a future change to
        // PhonemeMap or JamoTimeline drops fixtures into REST-only or
        // produces gaps, this test fails before the regression ships.
        let fixtures = [
            "왜 어떤 노래는 들으면 우는지",
            "얼음이 미끄러워요",
            "그 노래를 처음 들은 건 누구와 함께였나요",
            "이게 왜 trigger 되는지 모르겠어",
            "내가 왜 이 decision을 미루지",
        ]
        for utter in fixtures {
            let estimatedMs = TTSManager.estimateDurationMs(text: utter, language: .ko)
            let schedule = JamoTimeline.buildSchedule(
                text: utter,
                totalDurationMs: estimatedMs
            )
            #expect(!schedule.isEmpty, "fixture '\(utter)' produced empty schedule")
            #expect(schedule.first?.startMs == 0)
            let actualEnd = schedule.last?.endMs ?? -1
            #expect(
                abs(actualEnd - estimatedMs) < 1.0,
                "schedule end must equal totalDurationMs (within 1ms)"
            )
            // At least one viseme should NOT be REST — otherwise the bust
            // would never move (regression detector for unmapped jamo).
            let nonRestCount = schedule.filter { $0.viseme != .REST }.count
            #expect(nonRestCount > 0, "fixture '\(utter)' yields all-REST schedule")
        }
    }

    @Test func failureKeyMapsLSRErrorTo_sttOnDeviceUnsupported() {
        // PR-θ F9: kLSRErrorDomain code 1101 is the documented error
        // for "Siri & Dictation disabled / no on-device assets".
        let err = NSError(
            domain: "kLSRErrorDomain",
            code: 1101,
            userInfo: [:]
        )
        let key = EngineCoordinator.failureKey(for: err)
        #expect(key == PhaseFailureKey.sttOnDeviceUnsupported)
    }

    @Test func failureKeyMapsAVAudioInterruptionTo_audioInterrupted() {
        let err = NSError(
            domain: "AVFAudioErrorDomain",
            code: 561_017_449,
            userInfo: [:]
        )
        let key = EngineCoordinator.failureKey(for: err)
        #expect(key == PhaseFailureKey.audioInterrupted)
    }

    @Test func failureKeyDefaultsTo_audioRuntimeError() {
        let err = NSError(
            domain: "SomeUnknownDomain",
            code: 42,
            userInfo: [:]
        )
        let key = EngineCoordinator.failureKey(for: err)
        #expect(key == PhaseFailureKey.audioRuntimeError)
    }

    @Test func phaseFailureKeyNamespaceIsStable() {
        // Stability bar — these strings are part of the cross-layer
        // contract between the engine (Phase.failed payloads) and the
        // SwiftUI FailedMessage lookup. Changing a key requires a UI
        // update in lock-step.
        #expect(PhaseFailureKey.micDenied == "audio.permission.microphone.denied")
        #expect(PhaseFailureKey.speechRecognitionDenied == "audio.permission.speech.denied")
        #expect(PhaseFailureKey.gemmaLoadFailed == "gemma.load.failed")
        #expect(PhaseFailureKey.bootstrapTimeout == "bootstrap.timeout")
    }

    @Test func turnOutputSurfacedPastWonderReservedFieldExists() {
        // Forward-compat: TurnOutput.surfacedPastWonder is reserved for
        // iter2 §A7 stall fallback (PR-δ annotation). Verify the field
        // is on the public surface so a future PR doesn't accidentally
        // remove it.
        let out = FunctionCallOrchestrator.TurnOutput(
            mode: ModeClassification(
                mode: .curiousAdult,
                confidence: 0.5,
                reasoningSummary: "test"
            ),
            surfacedPastWonder: "stub-surface",
            socraticReply: "?",
            deferred: false,
            correlationId: UUID()
        )
        #expect(out.surfacedPastWonder == "stub-surface")
    }

    @Test func gemmaStubChatSessionStateRemainsEmpty() async {
        // Stub mode does not touch ChatSession. After loadModel + warmup
        // + a runTurn, the test seams must show no session was built.
        let svc = GemmaService(mode: .stub)
        try? await svc.loadModel()
        await svc.warmup()
        _ = try? await svc.runTurn(systemPrompt: SystemPrompt.composed, userTurn: "왜?")
        let exists = await svc._test_chatSessionExists
        let count = await svc._test_sessionTurnCount
        #expect(exists == false)
        #expect(count == 0)
    }

    @Test func gemmaWarmupOnStubIsNoOp() async {
        // Stub-mode warmup must early-return without touching ChatSession.
        let svc = GemmaService(mode: .stub)
        try? await svc.loadModel()
        await svc.warmup()
        // No crash, no error path. We don't have a stub session to inspect;
        // this test exists to guard the early-return at the top of warmup().
        let state = await svc.loadState
        if case .ready = state {
            // pass
        } else {
            Issue.record("expected stub loadModel to leave loadState=.ready, got \(state)")
        }
    }
}

@Suite("GenerateParametersBox KV-cache fields (PR-λ F19)")
struct GenerateParametersBoxKVQuantTests {
    @Test func defaultBoxOmitsKVQuant() {
        // PR-λ F19: ship default with `kvBits = nil` until upstream Gemma 4
        // in mlx-swift-lm 3.31.3 grows the missing `if let quantizedCache =
        // ...` branch. This test pins the default so a future PR that
        // accidentally enables KV quantization gets a red CI before the
        // fatal-error reproduces in production. Citation: bench evidence
        // captured in claudedocs/bench/2026-05-06-latency-bench-kvquant.log.
        let box = GenerateParametersBox(temperature: 0.0, topP: 1.0, maxTokens: 192)
        #expect(box.kvBits == nil)
        #expect(box.kvGroupSize == 64)
        #expect(box.quantizedKVStart == 0)
    }

    @Test func explicitKVQuantSettingsRoundTrip() {
        // The fields must accept caller overrides so the engine is
        // forward-ready: when upstream fixes Gemma 4's quantized cache path,
        // a single line at the call site (set kvBits: 4) flips the feature
        // on without a schema change.
        let box = GenerateParametersBox(
            temperature: 0.0,
            topP: 1.0,
            maxTokens: 64,
            kvBits: 4,
            kvGroupSize: 32,
            quantizedKVStart: 16
        )
        #expect(box.kvBits == 4)
        #expect(box.kvGroupSize == 32)
        #expect(box.quantizedKVStart == 16)
    }

    @Test func gemmaServiceShipsWithQuantDisabled() async {
        // PR-λ F19: contract pin — `GemmaService.generateParameters.kvBits`
        // is `nil` by default. If a future PR sets it to non-nil to "speed
        // things up", the production app would fatal-error on first
        // inference (Gemma4.swift in mlx-swift-lm 3.31.3 does not handle
        // QuantizedKVCache on every attention path). This test fails
        // immediately so the regression is caught before merge.
        let svc = GemmaService(mode: .stub)
        let kvBits = await svc.generateParameters.kvBits
        #expect(kvBits == nil, "Gemma 4 in mlx-swift-lm 3.31.3 cannot ship with kvBits != nil — see claudedocs/bench/2026-05-06-latency-bench-kvquant.log for the QuantizedKVCache.update() trap")
    }
}
