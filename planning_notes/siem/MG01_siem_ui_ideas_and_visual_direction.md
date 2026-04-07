# MG01 SIEM Dashboard - UI Ideas and Visual Direction

## Goal

Make MG01 feel like a sibling pane of the existing SAFETYNET visualiser app, not a separate unrelated tool.

Desired player perception:

- "I am still inside the same operations software stack."

## Visual Reference Synthesis

Borrow cues from the visualiser SIEM mode and shell:

- Color language:
  - Green for baseline telemetry.
  - Gold for metadata/highlight.
  - Red for criticals.
  - Cyan for network/source detail.
- Framing language:
  - Pixel corner brackets.
  - Thin technical panel borders.
  - Scanline/noise subtle overlays.
- Type hierarchy:
  - Press Start 2P for labels/headings/status chips.
  - VT323 for dense row data and counters.

Do not duplicate the full music overlay chrome.
Instead, present MG01 as a dedicated module tab in that ecosystem.

## "Same App, Different Pane" Concept

Use a shell title pattern like:

- `SAFETYNET // INCIDENT OPS SUITE`

Module title:

- `MODULE: SIEM TRIAGE (MG01)`

This keeps continuity while communicating functional context shift.

## Layout Blueprint

Three-column operational layout:

1. Left rail (telemetry)

- Threat score block (0-100).
- Timer block.
- Severity counts.
- Tiny sparkline for incoming event pressure.

2. Center main stream (triage list)

- Scrollable event rows with fixed row height.
- Columns: SEV, TIME, SRC, EVENT, ACTIONS.
- Actions per row: DISMISS and ESCALATE.
- Current selection highlight for keyboard support.

3. Right rail (escalation queue)

- Header: `ESCALATED FOR REVIEW`.
- Queue list with criticals pinned top.
- Live count and optional checklist of required critical IDs.

Bottom status strip:

- `PENDING: X | ESCALATED: Y | DISMISSED: Z | TIME: MM:SS`

## Severity and Motion Language

Severity treatments:

- INFO: subdued green text, low-contrast row background.
- LOW: cyan accent.
- MEDIUM: gold accent.
- HIGH: orange accent and border pulse every ~1.5s.
- CRITICAL: red badge with 1Hz blink and stronger left border.

Motion rules:

- Dismiss action: row fades to 35% and shifts left 4px.
- Escalate action: row slides right into queue and receives green "routed" check flash.
- New incoming alerts: drop-in from top with a 120-180ms transition.

Keep animations intentional and brief; avoid noisy perpetual movement.

## Component Ideas

### Header Cluster

- App title + module title.
- Live clock.
- Connection state chip: `SIEM CORE: LIVE`.

### Event Row Template

- Severity chip.
- Timestamp (monospace).
- Source short code.
- Event text line.
- Right-aligned actions.

Optional tiny metadata hover details:

- Country, MITRE tactic, confidence, host/user.

### Queue Row Template

- Severity + short event text.
- Escalation timestamp.
- Mini source badge.

### Result Banner

- Success: green bar `INCIDENT TEAM NOTIFIED`.
- Failure: red bar `CRITICAL ALERTS MISSED`.

## Design Tokens (Proposed)

```css
--siem-bg: #03070c;
--siem-panel: #07111a;
--siem-grid: rgba(0, 255, 65, 0.08);
--siem-text: #a9f7c8;
--siem-green: #00ff41;
--siem-cyan: #00ffff;
--siem-gold: #ffd700;
--siem-orange: #ff6600;
--siem-red: #ff003c;
--siem-border: #0f3b20;
```

Typography:

- Labels/headings: Press Start 2P, 8-10px.
- Data rows: VT323, 16-19px.
- Timer/threat numerics: VT323, 26-34px.

## Micro-Interactions

- Keyboard shortcuts:
  - Up/Down to move row focus.
  - E to escalate selected row.
  - D to dismiss selected row.
- Button states:
  - Hover border glow.
  - Disabled style after decision.
- Audio (optional):
  - Soft click for row action.
  - Distinct alert chirp for new CRITICAL.

## Accessibility and Readability

- Keep contrast above practical readability threshold for low-light scenes.
- Never encode severity by color alone; include explicit severity text chip.
- Provide reduced-motion fallback class if needed.
- Avoid text below 8px in Press Start 2P; for dense data use VT323.

## Mobile/Small View Fallback

When horizontal space is constrained:

- Collapse right queue into a bottom drawer tab (`Escalations`).
- Keep center stream full width.
- Move telemetry stats to compact top strip.

Even if not primary target, this keeps panel robust in varied test setups.

## Thematic Flavor Ideas

- Header operation codename rotates from an approved list (same visualiser concept).
- Top-right hint line from Ravi context:
  - `RAVI: "Filter migration noise, find true IoCs."`
- Subtle map/radar ghost graphic in background at 4-6% opacity.

## Copy Tone

Short, operational, non-cinematic.
Examples:

- `ALERT INGEST ACTIVE`
- `ANALYST ACTION REQUIRED`
- `QUEUE FOR INCIDENT REVIEW`

Avoid dramatic hacker cliches for this module because educational clarity matters.

## Concrete UI Deliverable Checklist

- Shared-shell look aligned with visualiser palette and framing language.
- Distinct SIEM module title and clear triage affordances.
- Three-pane desktop layout plus compact fallback.
- Clear state transitions for pending/dismissed/escalated.
- Result banner and bottom status strip.
- Minimal, meaningful animation set.

## Optional Future Visual Cohesion Step

Create a lightweight shared style file (example: `ops-suite-theme.css`) for reusable tokens and chrome.

MG01 can consume that theme now, and future tools (network map, command board) can migrate later to strengthen suite-level consistency.
