"use client";
import { useEffect, useState } from "react";

const SECTION_IDS = ["hero", "lesson-1", "lesson-2", "lesson-3", "lesson-4"];
const LABELS = [
  "Lesson 0 · pre-flight",
  "Lesson 1 · what this is",
  "Lesson 2 · the tone",
  "Lesson 3 · abstention",
  "Lesson 4 · on-device proof",
];

export default function ProgressRail() {
  const [activeIdx, setActiveIdx] = useState(0);

  useEffect(() => {
    const obs = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (!e.isIntersecting) return;
          const idx = SECTION_IDS.indexOf(e.target.id);
          if (idx >= 0) setActiveIdx(idx);
        });
      },
      { rootMargin: "-30% 0px -50% 0px" }
    );
    SECTION_IDS.forEach((id) => {
      const el = document.getElementById(id);
      if (el) obs.observe(el);
    });
    return () => obs.disconnect();
  }, []);

  return (
    <div className="progress-rail">
      <span>He Was Socrates · gate H1</span>
      <div className="pips">
        {SECTION_IDS.map((id, i) => (
          <div
            key={id}
            className={`pip ${i < activeIdx ? "done" : ""} ${i === activeIdx ? "active" : ""}`}
            title={LABELS[i]}
          />
        ))}
      </div>
      <div className="meta-right">
        <span>Profile · max</span>
        <span>Run · r-20260507-010321</span>
      </div>
    </div>
  );
}
