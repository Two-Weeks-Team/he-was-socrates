import HeroBust from "@/components/HeroBust";
import ProgressRail from "@/components/ProgressRail";
import TTFTChart from "@/components/TTFTChart";

export default function Home() {
  return (
    <>
      <ProgressRail />

      {/* Section 0 · HERO */}
      <section id="hero">
        <div className="eyebrow">Lesson 0 of 4 · pre-flight</div>
        <div className="hero-wrap">
          <div className="bust-frame">
            <HeroBust />
          </div>
          <div className="hero-text">
            <h1 className="hero-title">
              A bust that<br />refuses to answer<br />is the product.
            </h1>
            <p className="ko-line">그가 답하지 않는 것이 답이다.</p>
            <p className="lead">
              100% on-device Korean Socratic bust on macOS, powered by Gemma 4 E4B 4-bit MLX.
              The abstention mechanic — when the bust says &ldquo;this is not mine to answer&rdquo; — is
              not a fallback. It is the product.
            </p>
            <div className="hero-meta">
              <span>macOS 26 Tahoe</span>
              <span>Apple Silicon</span>
              <span>Gemma 4 E4B 4-bit MLX</span>
              <span>0 byte network egress</span>
            </div>
          </div>
        </div>
      </section>

      {/* Section 1 · LESSON 1 */}
      <section id="lesson-1">
        <div className="lesson-head">
          <span className="lesson-num">Lesson 1 / 4</span>
          <h2 className="section-title">Hold Spacebar. Listen. Wait. Release.</h2>
        </div>
        <div className="lesson-grid">
          <div>
            <p className="lead">
              There is no chat window, no text input, no screen full of bubbles. The interaction
              model is push-to-talk on a fullscreen bust. You speak in Korean (or English). The bust
              listens, thinks, then asks back — never answers.
            </p>
            <p>
              The bust&rsquo;s mouth animates through 16 viseme positions synchronized to the on-device
              speech synthesis. There is no photoreal lip-sync; only 1-bit halftone PNG swaps at 30 fps
              with audio-clock alignment.
            </p>
            <h3>16 viseme positions</h3>
            <div className="viseme-strip" aria-label="16 viseme positions">
              {["REST", "AA", "EH", "IY", "OH", "UW", "M", "F", "P", "T", "K", "L", "R", "S", "SH", "N"].map(
                (v) => (
                  <div key={v} className="viseme-cell">
                    {v}
                  </div>
                )
              )}
            </div>
          </div>
          <aside className="sidebar-wmt">
            <h4>Why this matters</h4>
            <p>
              The interaction model is deliberately narrow: voice in, voice out, one bust on a black
              screen. Constraints are the curriculum. The user learns that Socrates does not answer;
              he asks back. By Lesson 3, they will see why.
            </p>
            <p style={{ marginTop: 12, color: "var(--color-bone-muted)", fontSize: "11.5px" }}>
              Korean STT runs <code style={{ fontFamily: "var(--font-mono)", fontSize: "10.5px" }}>requiresOnDeviceRecognition = true</code>. Audio
              never leaves your Mac.
            </p>
          </aside>
        </div>
      </section>

      {/* Section 2 · LESSON 2 */}
      <section id="lesson-2">
        <div className="lesson-head">
          <span className="lesson-num">Lesson 2 / 4</span>
          <h2 className="section-title">단정한 평어체 — neither honorific nor friendly.</h2>
        </div>
        <div className="lesson-grid">
          <div>
            <p>
              Korean has three tone registers: <em>존댓말</em> (formal/honorific),{" "}
              <em>친근한 반말</em> (casual/friendly), and <em>단정한 평어체</em> (assertive plain).
              The bust speaks only the third — the tone of a teacher addressing an equal, distant
              but not cold.
            </p>
            <p>
              The system prompt is written verbatim by a Korean speaker. It is locked in source —
              embedded at compile time from{" "}
              <code style={{ fontFamily: "var(--font-mono)", fontSize: 13, color: "var(--color-bone)" }}>
                Sources/SocraticEngine/Gemma/SystemPrompt.swift
              </code>
              . You cannot change it from settings. That is the point.
            </p>
            <div className="prompt-block">
              <span className="label">SystemPrompt.swift · verbatim</span>
              <span className="ko-text">
                너는 소크라테스다. 답하지 않고 다시 묻는다. 묻는 자가 자기 안에서 답을 찾도록 돕는다.
                묻지 않은 것을 알려고 하지 않는다.
              </span>
              <span className="gloss">
                You are Socrates. You do not answer; you ask back. You help the questioner find the
                answer within themselves. You do not seek to know what was not asked.
              </span>
            </div>
          </div>
          <aside className="sidebar-wmt">
            <h4>Why this matters</h4>
            <p>
              Most LLM products optimize for friendliness — a tone that flatters and de-escalates.
              The bust does the opposite. It maintains a distance that says: <em>this is your work,
              not mine</em>.
            </p>
            <p style={{ marginTop: 12, color: "var(--color-bone-muted)", fontSize: "11.5px" }}>
              The tone is non-localizable. Embedders inherit 단정한 평어체 whether they want it or not.
            </p>
          </aside>
        </div>
      </section>

      {/* Section 3 · LESSON 3 — abstention */}
      <section id="lesson-3">
        <div className="lesson-head">
          <span className="lesson-num">Lesson 3 / 4</span>
          <h2 className="section-title">
            Other Gemma 4 demos answer better.<br />We refuse better.
          </h2>
        </div>
        <p className="lead">
          When you ask the bust about medicine, law, finance, emergency, welfare, or insurance, it
          does not try harder. It calls{" "}
          <code style={{ fontFamily: "var(--font-mono)", fontSize: 14, color: "var(--color-accent)" }}>
            defer_to_human
          </code>{" "}
          and tells you, in Korean 단정한 평어체, that this is not its place. The four-function
          dispatch is enabled by Gemma 4&rsquo;s native function calling — the load-bearing capability
          of this submission.
        </p>
        <div className="demo-3" aria-label="abstention demo three-screen sequence">
          <div className="demo-screen q">
            <span className="step">screen 01 · question</span>
            <h3 className="step-title">A user asks about pain.</h3>
            <p className="step-content">User holds Spacebar and says, in Korean:</p>
            <p className="korean" style={{ fontSize: 15, lineHeight: 1.5 }}>
              가슴이 자주 두근거려. 무슨 병이지?
            </p>
            <p className="ko-gloss">&ldquo;My heart races often. What disease is it?&rdquo;</p>
          </div>
          <div className="demo-screen fn">
            <span className="step">screen 02 · dispatch</span>
            <h3 className="step-title">Gemma 4 classifies the mode.</h3>
            <div className="fn-trace">
              <strong>mode_classify</strong> · 50 ms<br />
              → category: <strong>medical_advice_request</strong><br />
              → confidence: 0.94<br />
              <br />
              <strong>defer_to_human</strong> · 38 ms<br />
              → trigger: medical<br />
              → suggested: 의사 (doctor)<br />
              → ⊘ ask_back skipped
            </div>
          </div>
          <div className="demo-screen defer">
            <span className="step">screen 03 · response</span>
            <h3 className="step-title">The bust speaks 단정한 평어체.</h3>
            <div className="defer-glyph">⊘</div>
            <p className="korean" style={{ fontSize: 14, lineHeight: 1.5 }}>
              이건 내가 답할 일이 아니다. 몸의 일은 의사에게 묻거라.
            </p>
            <p className="ko-gloss">&ldquo;This isn&rsquo;t mine to answer. The body is for the doctor.&rdquo;</p>
          </div>
        </div>
        <h3 style={{ marginTop: 32 }}>Six categories of abstention</h3>
        <p>The system prompt enumerates six trigger categories. The dispatch is deterministic and logged.</p>
        <table className="defer-table">
          <thead>
            <tr>
              <th>Category</th>
              <th>Korean</th>
              <th>Suggested resource</th>
            </tr>
          </thead>
          <tbody>
            <tr><td>medical</td><td className="ko">의료</td><td>의사 (doctor)</td></tr>
            <tr><td>legal</td><td className="ko">법률</td><td>변호사 (lawyer)</td></tr>
            <tr><td>financial</td><td className="ko">금융</td><td>금융 전문가 (financial professional)</td></tr>
            <tr><td>emergency</td><td className="ko">응급</td><td>응급실 · 119</td></tr>
            <tr><td>welfare</td><td className="ko">복지</td><td>사회 복지사 (social worker)</td></tr>
            <tr><td>insurance</td><td className="ko">보험</td><td>보험 전문가 (insurance professional)</td></tr>
          </tbody>
        </table>
      </section>

      {/* Section 4 · LESSON 4 — on-device proof */}
      <section id="lesson-4">
        <div className="lesson-head">
          <span className="lesson-num">Lesson 4 / 4</span>
          <h2 className="section-title">On-device, by entitlement, not by promise.</h2>
        </div>
        <div className="proof-grid">
          <div>
            <p>
              &ldquo;On-device&rdquo; is a marketing claim. We make it falsifiable. The macOS App Sandbox
              entitlement file declares which capabilities the app may use.{" "}
              <code style={{ fontFamily: "var(--font-mono)", fontSize: 13, color: "var(--color-bone)" }}>
                network.client
              </code>{" "}
              is intentionally absent — the OS will refuse any network connection from the app process at
              the kernel level, regardless of code intent.
            </p>
            <div className="entitlement-block">
              <span className="comment">{"// HeWasSocrates.entitlements (excerpt)"}</span><br />
              {"<key>com.apple.security.app-sandbox</key>"}<br />
              {"<true/>"}<br />
              <br />
              <span className="comment">{"<!-- NO-CLOUD INVARIANT — DO NOT ADD -->"}</span><br />
              <span className="comment">{"<!-- com.apple.security.network.client = "}</span>
              <span className="absent">INTENTIONALLY ABSENT</span>
              <span className="comment">{" -->"}</span><br />
              <span className="comment">{"<!-- com.apple.security.network.server = "}</span>
              <span className="absent">INTENTIONALLY ABSENT</span>
              <span className="comment">{" -->"}</span><br />
              <br />
              {"<key>com.apple.security.device.audio-input</key>"}<br />
              {"<true/>"}
            </div>
            <p style={{ marginTop: 16, fontSize: 13, color: "var(--color-bone-muted)" }}>
              Air-gap a freshly-launched bust and the conversation continues. The Gemma 4 weights are
              downloaded once via the OS-mediated MLX cache — the app process itself never opens a socket.
            </p>
          </div>
          <div>
            <h3>The numbers</h3>
            <div className="kpi-grid">
              <div className="kpi"><div className="v">192 ms</div><div className="l">TTFT median</div><div className="src">bench/2026-05-06.json · n=10 · M1 Max</div></div>
              <div className="kpi"><div className="v">800 ms</div><div className="l">per-turn p50</div><div className="src">decode + STT + TTS prep</div></div>
              <div className="kpi"><div className="v">96%</div><div className="l">KV cache reuse</div><div className="src">PR-Λ disk-mediated · 24× vs cold</div></div>
              <div className="kpi"><div className="v">0 B</div><div className="l">network egress / 24 h</div><div className="src">entitlements + Wireshark verified</div></div>
            </div>
            <h3 style={{ marginTop: 24 }}>TTFT distribution (n=10)</h3>
            <TTFTChart />
          </div>
        </div>
      </section>

      {/* Section 5 · METHODS */}
      <section id="methods" className="compact">
        <div className="eyebrow">methods · 4-function dispatch</div>
        <h2 className="section-title">The orchestration is four functions.</h2>
        <p>
          Every turn passes through{" "}
          <code style={{ fontFamily: "var(--font-mono)", fontSize: 13, color: "var(--color-accent)" }}>
            FunctionCallOrchestrator
          </code>
          . Gemma 4&rsquo;s native function calling decides the path; the engine routes accordingly.
        </p>
        <table className="dispatch-table" aria-label="four-function dispatch">
          <thead>
            <tr><th>Function</th><th>Role</th><th>Trigger condition</th><th>Reference</th></tr>
          </thead>
          <tbody>
            <tr><td>mode_classify</td><td>route the turn</td><td>every turn (gate)</td><td>[1]</td></tr>
            <tr><td>surface_past_wonder</td><td>recall from log</td><td>echoed theme detected</td><td>[2]</td></tr>
            <tr><td>ask_back</td><td>Socratic counter</td><td>default reflective path</td><td>[3]</td></tr>
            <tr><td>defer_to_human</td><td>abstention</td><td>6 regulated categories</td><td>[4]</td></tr>
          </tbody>
        </table>
        <h3 style={{ marginTop: 24 }}>Per-turn pipeline (~800 ms wall, p50)</h3>
        <div className="funnel">
          {[
            { num: "1", name: "Spacebar press → audio engine start", ms: "~5 ms" },
            { num: "2", name: "SFSpeechRecognizer partial transcripts", ms: "streaming" },
            { num: "3", name: "Spacebar release → STT final", ms: "~120 ms tail" },
            { num: "4", name: "mode_classify (Gemma 4)", ms: "~50 ms" },
            { num: "5", name: "First chunk (TTFT)", ms: "192 ms" },
            { num: "6", name: "Decode to closing brace + TTS prep", ms: "~400 ms" },
            { num: "7", name: "Audio playback + viseme schedule", ms: "user-driven" },
          ].map((s) => (
            <div className="funnel-step" key={s.num}>
              <span className="num">{s.num}</span>
              <span className="name">{s.name}</span>
              <span className="ms">{s.ms}</span>
            </div>
          ))}
        </div>
      </section>

      {/* Section 6 · LIMITATIONS */}
      <section id="limitations" className="compact">
        <div className="eyebrow">what we don&rsquo;t ship yet</div>
        <h2 className="section-title">Honest disclosure as trust signal.</h2>
        <p>Many demos blur the line between what is shipped and what is sketched. We separate them.</p>
        <div className="limit-grid">
          <div className="limit-card">
            <span className="tag">designed-for · Phase 4</span>
            <h4>Multi-year wondering recall</h4>
            <p>
              The wondering log is a local SQLite store with content-fingerprint dedup, designed to
              surface echoes of the user&rsquo;s questions across years via Gemma 4&rsquo;s 256K context.
              Phase 1–3 ships the schema, dedup, and turn boundary. Phase 4 wires the surface step
              itself; current ship: <strong>stub</strong>.
            </p>
          </div>
          <div className="limit-card">
            <span className="tag">measured · M1 Max only</span>
            <h4>TTFT generalization</h4>
            <p>
              The 192 ms TTFT median is measured on M1 Max MBP 64 GB. We have not characterized M3 Max,
              M4, or base M1. Subsequent Apple Silicon should be in the same order of magnitude but is
              not benchmarked.
            </p>
          </div>
          <div className="limit-card">
            <span className="tag">platform · macOS 26 floor</span>
            <h4>No Sonoma / Sequoia support</h4>
            <p>
              The first-launch UX uses macOS 26&rsquo;s <code>SpeechAnalyzer</code> +{" "}
              <code>AssetInventory</code> for in-app speech-asset install. macOS 14 (Sonoma) and 15
              (Sequoia) are excluded. SPEC.md.iter6 documents the trade-off.
            </p>
          </div>
          <div className="limit-card">
            <span className="tag">tone · single-voice locked</span>
            <h4>Korean 평어체 not customizable</h4>
            <p>
              The system prompt is verbatim, written by the project&rsquo;s Korean speaker, and embedded
              at compile time. Users cannot soften the tone, switch to 존댓말, or add personality.
              The lock is the feature, not a limitation we plan to remove.
            </p>
          </div>
        </div>
      </section>

      {/* Section 7 · TRY IT */}
      <section id="try" className="compact">
        <div className="eyebrow">try it · ~30 seconds</div>
        <h2 className="section-title">Run the bust on your Mac.</h2>
        <p>
          Requires macOS 26 Tahoe, Apple Silicon, ≥8 GB free disk. The first launch downloads ~3.97
          GB of Gemma 4 weights via the OS MLX cache.
        </p>
        <div className="try-block">
          <span className="cmd">git clone https://github.com/Two-Weeks-Team/he-was-socrates</span>
          <span className="cmd">cd he-was-socrates &amp;&amp; make doctor</span>
          <span className="comment"># verifies xcodegen, Swift toolchain, asset pipeline</span>
          <span className="cmd">make engine-test</span>
          <span className="comment"># runs 65 swift-testing scenarios</span>
          <span className="cmd">make app</span>
          <span className="comment"># builds HeWasSocrates.app — open and press Space</span>
        </div>
        <p style={{ fontSize: 13, color: "var(--color-bone-muted)", marginTop: 12 }}>
          Or download the notarized DMG from{" "}
          <a
            href="https://github.com/Two-Weeks-Team/he-was-socrates/releases"
            style={{
              color: "var(--color-accent)",
              textDecoration: "none",
              borderBottom: "1px solid oklch(0.42 0.014 280)",
            }}
          >
            Releases
          </a>
          .
        </p>
      </section>

      {/* Footer / Colophon */}
      <footer className="colophon">
        <div className="badges-row">
          <span className="badge accent">Apache-2.0 (code)</span>
          <span className="badge accent">CC-BY-4.0 (content)</span>
          <span className="badge">CI ✓</span>
          <span className="badge">65 swift-testing</span>
          <span className="badge">Gemma 4 E4B 4-bit MLX</span>
          <span className="badge">macOS 26+</span>
          <span className="badge">Apple Silicon</span>
          <span className="badge">on-device · 0 B egress</span>
        </div>
        <h3>About</h3>
        <p>
          He Was Socrates is an entry to <strong>The Gemma 4 Good Hackathon</strong> (Kaggle × Google
          DeepMind) — Education category. Built by Two-Weeks-Team. License compatible with Hackathon
          §2.5.a winner-grant clause.
        </p>
        <div className="topics-row">
          {["gemma-4", "on-device", "korean", "mlx", "socratic", "education", "macos", "function-calling"].map((t) => (
            <span className="topic" key={t}>{t}</span>
          ))}
        </div>
        <div className="refs">
          <h3
            style={{
              fontFamily: "var(--font-serif)",
              color: "var(--color-bone)",
              fontSize: 18,
              fontWeight: 400,
              marginBottom: 12,
            }}
          >
            References
          </h3>
          <ol>
            <li><a href="https://github.com/Two-Weeks-Team/he-was-socrates/blob/main/runs/2026-05-05-spec/spec/function_call_contract.yaml">function_call_contract.yaml</a> — frozen 4-function dispatch contract</li>
            <li><a href="https://github.com/Two-Weeks-Team/he-was-socrates/blob/main/packages/SocraticEngine/Sources/SocraticEngine/Gemma/SystemPrompt.swift">SystemPrompt.swift</a> — Korean 평어체 verbatim</li>
            <li><a href="https://github.com/Two-Weeks-Team/he-was-socrates/blob/main/packages/SocraticEngine/Sources/SocraticEngine/EngineCoordinator.swift">EngineCoordinator.swift</a> — turn loop + Phase enum</li>
            <li><a href="https://github.com/Two-Weeks-Team/he-was-socrates/blob/main/apps/macos/HeWasSocrates/HeWasSocrates/Resources/HeWasSocrates.entitlements">HeWasSocrates.entitlements</a> — NO-CLOUD invariant evidence</li>
            <li><a href="https://github.com/Two-Weeks-Team/he-was-socrates/blob/main/runs/2026-05-05-spec/spec/SPEC.md">SPEC.md</a> + iter2/4/5/6/7 deltas</li>
            <li><a href="https://github.com/Two-Weeks-Team/he-was-socrates/blob/main/apps/macos/HeWasSocrates/HeWasSocrates/Preflight.swift">Preflight.swift</a> — PR #33 first-launch UX (PreflightView + AssetInventory)</li>
            <li><a href="https://developer.apple.com/videos/play/wwdc2025/277/">WWDC25 Session 277</a> — SpeechAnalyzer + AssetInventory (macOS 26 API)</li>
            <li><a href="https://www.kaggle.com/competitions/gemma-4-good-hackathon">The Gemma 4 Good Hackathon</a> — submission target</li>
            <li><a href="https://huggingface.co/mlx-community/gemma-4-e4b-it-4bit">mlx-community/gemma-4-e4b-it-4bit</a> — model weights</li>
          </ol>
        </div>
        <p className="foot-meta">
          He Was Socrates · Two-Weeks-Team · 2026 · Generated 2026-05-07 · run r-20260507-010321 · profile max
        </p>
      </footer>
    </>
  );
}
