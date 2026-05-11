export default function HeroBust() {
  return (
    <svg
      className="bust-svg"
      viewBox="0 0 200 250"
      xmlns="http://www.w3.org/2000/svg"
      aria-label="halftone bust silhouette"
    >
      <defs>
        <pattern id="halftone-coarse" x="0" y="0" width="6" height="6" patternUnits="userSpaceOnUse">
          <circle cx="3" cy="3" r="1.5" fill="oklch(0.92 0.022 85)" />
        </pattern>
        <pattern id="halftone-fine" x="0" y="0" width="4" height="4" patternUnits="userSpaceOnUse">
          <circle cx="2" cy="2" r="0.7" fill="oklch(0.92 0.022 85)" />
        </pattern>
        <radialGradient id="bust-grad" cx="50%" cy="35%">
          <stop offset="0%" stopColor="oklch(0.92 0.022 85)" stopOpacity="0.95" />
          <stop offset="60%" stopColor="oklch(0.92 0.022 85)" stopOpacity="0.55" />
          <stop offset="100%" stopColor="oklch(0.92 0.022 85)" stopOpacity="0" />
        </radialGradient>
      </defs>
      <ellipse cx="100" cy="80" rx="42" ry="50" fill="url(#bust-grad)" />
      <ellipse cx="100" cy="78" rx="42" ry="50" fill="url(#halftone-coarse)" opacity="0.35" />
      <path d="M 60 130 Q 100 145 140 130 L 160 200 L 40 200 Z" fill="url(#halftone-fine)" opacity="0.25" />
      <line x1="82" y1="78" x2="92" y2="78" stroke="oklch(0.20 0.010 280)" strokeWidth="1.2" opacity="0.85" />
      <line x1="108" y1="78" x2="118" y2="78" stroke="oklch(0.20 0.010 280)" strokeWidth="1.2" opacity="0.85" />
      <line x1="92" y1="98" x2="108" y2="98" stroke="oklch(0.20 0.010 280)" strokeWidth="1" opacity="0.7" />
    </svg>
  );
}
