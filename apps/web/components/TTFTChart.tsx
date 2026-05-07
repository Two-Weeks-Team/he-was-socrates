export default function TTFTChart() {
  return (
    <svg
      viewBox="0 0 320 140"
      style={{
        width: "100%",
        height: "auto",
        background: "oklch(0.16 0.013 280 / 0.8)",
        border: "1px solid oklch(0.28 0.012 280)",
        borderRadius: 4,
        padding: 8,
      }}
      aria-label="TTFT distribution chart"
    >
      <line x1="20" y1="115" x2="310" y2="115" stroke="oklch(0.42 0.014 280)" strokeWidth="1" />
      <line x1="20" y1="20" x2="20" y2="115" stroke="oklch(0.42 0.014 280)" strokeWidth="1" />
      <text x="20" y="135" fontFamily="ui-monospace" fontSize="9" fill="oklch(0.62 0.014 85)">t1</text>
      <text x="155" y="135" fontFamily="ui-monospace" fontSize="9" fill="oklch(0.62 0.014 85)">t5</text>
      <text x="295" y="135" fontFamily="ui-monospace" fontSize="9" fill="oklch(0.62 0.014 85)">t10</text>
      <line x1="20" y1="65" x2="310" y2="65" stroke="oklch(0.85 0.140 165)" strokeWidth="1" strokeDasharray="3 3" opacity="0.5" />
      <text x="220" y="63" fontFamily="ui-monospace" fontSize="9" fill="oklch(0.85 0.140 165)">p50 192ms</text>
      <line x1="20" y1="85" x2="310" y2="85" stroke="oklch(0.62 0.014 85)" strokeWidth="1" strokeDasharray="2 4" opacity="0.4" />
      <text x="240" y="83" fontFamily="ui-monospace" fontSize="9" fill="oklch(0.62 0.014 85)">p10 181</text>
      <line x1="20" y1="40" x2="310" y2="40" stroke="oklch(0.62 0.014 85)" strokeWidth="1" strokeDasharray="2 4" opacity="0.4" />
      <text x="240" y="38" fontFamily="ui-monospace" fontSize="9" fill="oklch(0.62 0.014 85)">p90 263</text>
      <g fill="oklch(0.85 0.140 165)" opacity="0.85">
        <rect x="28" y="68" width="20" height="47" />
        <rect x="58" y="60" width="20" height="55" />
        <rect x="88" y="64" width="20" height="51" />
        <rect x="118" y="55" width="20" height="60" />
        <rect x="148" y="68" width="20" height="47" />
        <rect x="178" y="50" width="20" height="65" />
        <rect x="208" y="62" width="20" height="53" />
        <rect x="238" y="68" width="20" height="47" />
        <rect x="268" y="42" width="20" height="73" />
        <rect x="282" y="80" width="14" height="35" />
      </g>
    </svg>
  );
}
