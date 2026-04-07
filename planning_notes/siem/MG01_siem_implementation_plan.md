# MG01 SIEM Dashboard - Implementation Plan

## Scope and Intent

MG01 is an interactive SIEM triage minigame where the player classifies alerts as DISMISS or ESCALATE under time pressure.

Primary learning objective:

- Teach alert fatigue and false-positive discrimination in a mixed stream of migration noise and true attack indicators.

Scenario objective:

- Correctly escalate the critical indicators to set `siem_escalated = true`.
- Incorrect handling (especially dismissing critical alerts) sets `siem_missed_alerts = true`.

Design objective:

- Build as a normal minigame pane inside the existing Break Escape minigame framework, while visually reading as another panel in the same software family as the SAFETYNET visualiser SIEM mode.

## Constraints Gathered From Existing Docs/Code

From game design docs:

- MG01 is minigame #1 in the healthcare flow and occurs in Room 2 (Ravi laptop).
- It must include a scrollable live event log and player triage actions.
- Correct critical set includes: encoded PowerShell, LSASS access, anomalous SMB write volume, cross-zone RDP session.
- It should support state persistence while open/close and allow injected alerts via events.

From runtime architecture:

- Minigames are classes extending `MinigameScene`.
- Registration is in `public/break_escape/js/minigames/index.js`.
- Trigger entry points are typically from `public/break_escape/js/systems/minigame-starters.js` and `unlock-system.js` lockType routing.
- Event bus is `window.eventDispatcher` (on/emit/off).
- Cross-system reactive state should be written via `window.npcManager.setGlobalVariable(...)`.

From visual references:

- Existing SIEM-like visual language in `public/break_escape/js/music/bond-visualiser.js` and `public/break_escape/css/bond-visualiser.css`.
- Strong candidate visual tokens to reuse:
  - Palette: green/gold/red/cyan on near-black.
  - Pixel corners, framed panels, scanline/noise treatment.
  - Press Start 2P and VT323 hierarchy.
  - Dense telemetry pane composition.

## Recommended Technical Approach

Implement MG01 as an HTML/CSS minigame (not Phaser) extending `MinigameScene`.

Reasoning:

- Existing docs explicitly classify SIEM dashboard as HTML/CSS.
- UI behavior is list + controls + queue + timer, which is DOM-friendly and easier to theme.
- Faster iteration for text-heavy interaction and accessibility.

## File Plan

1. Add minigame scene class:

- `public/break_escape/js/minigames/siem/siem-dashboard-minigame.js`

2. Add styles:

- `public/break_escape/css/siem-dashboard-minigame.css`

3. Register scene:

- Update `public/break_escape/js/minigames/index.js`
- Register key: `siem-dashboard` (or `siem` if no naming collision risk)

4. Add starter helper:

- Update `public/break_escape/js/systems/minigame-starters.js`
- Add `startSiemDashboardMinigame(...)`

5. Route from interaction layer:

- Preferred: add lockType handling in `public/break_escape/js/systems/unlock-system.js` for `lockType: "siem_dashboard"`.
- Alternative (if object is non-lock terminal): trigger via object interaction handler directly.

6. Ensure CSS load path:

- If engine uses centralized CSS includes, add stylesheet there.
- If minigames self-inject styles, follow existing project pattern used by other minigames.

## Scenario Contract

For scenario objects representing the SIEM laptop, use scenarioData such as:

```json
{
  "locked": true,
  "lockType": "siem_dashboard",
  "name": "Ravi Anand Laptop",
  "scenarioData": {
    "mgId": "MG01",
    "timeLimitSec": 180,
    "requiredCriticalIds": ["ALRT-001", "ALRT-005", "ALRT-012", "ALRT-018"],
    "autoInject": true,
    "seed": "northgate_day1"
  }
}
```

Notes:

- Keep server authority for final scenario gating if applicable.
- Client minigame is UX and progression signaling, but backend validation should remain authoritative for unlock-critical paths.

## Runtime Data Model (In-Minigame)

```js
state = {
  startedAt: number,
  remainingSec: number,
  alerts: Array<Alert>,
  escalatedIds: Set<string>,
  dismissedIds: Set<string>,
  pendingIds: Set<string>,
  criticalIds: Set<string>,
  triageHistory: Array<{id, action, ts}>,
  finished: boolean
}
```

Alert shape:

```js
{
  id: string,
  severity: 'INFO' | 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL',
  timestamp: string,
  source: string,
  description: string,
  iocType: string,
  critical: boolean,
  status: 'pending' | 'dismissed' | 'escalated'
}
```

## Completion Logic

Suggested rule set:

- Success if all critical alerts are escalated before timer expiry.
- Failure if timer expires with any critical un-escalated.
- Optional immediate fail mode: dismissing any critical alert marks hard failure.

Recommended for narrative consistency:

- Do not hard-fail immediately; allow continued triage, then evaluate at timer end or when all critical handled.
- This supports "alerts were there but missed" messaging without abrupt modal interruption.

Outcome writeback:

- On success:
  - `window.npcManager.setGlobalVariable('siem_escalated', true)`
  - `window.npcManager.setGlobalVariable('siem_missed_alerts', false)`
- On failure:
  - `window.npcManager.setGlobalVariable('siem_missed_alerts', true)`

Also emit event for hooks:

```js
window.eventDispatcher.emit("siem_triage_completed", {
  success,
  escalated: [...state.escalatedIds],
  dismissed: [...state.dismissedIds],
  missedCritical: [...missedCriticalIds],
});
```

Then call `this.complete(success)`.

## Event Integration

Subscribe inside `start()` using `this.addEventListener(...)`:

- `siem_new_alert`: append dynamically injected alert rows.
- `global_variable_changed:ransomware_deployed`: border pulse + burst of CRITICAL events.

Example handling:

- `siem_new_alert` payload normalized and inserted at top of stream.
- Debounce render and cap max rows (e.g., 200) to avoid DOM slowdown.

## Persistence Behavior

Required by design docs: reopen should continue prior state.

Implementation options:

1. Session-only in `window.gameState.globalVariables['mg01_siem_state']`.
2. Server sync piggyback through existing state-sync (preferred if scenario requires cross-reload continuity).

Minimum viable persistence:

- Save timer offset, triage actions, and alert statuses on each action.
- Restore in constructor/init when state exists and not completed.

## UX Flow

1. Open panel with seeded alerts and active timer.
2. Player triages rows via DISMISS/ESCALATE.
3. Escalated queue updates right pane and counters.
4. Alerts can arrive in real time.
5. Completion banner appears when conditions met.
6. Variables/events written; minigame closes via framework callback.

## Integration With NPC/Objective Systems

Expected downstream effects based on design docs:

- Ravi dialogue branch unlock tied to `siem_escalated = true`.
- Command board timeline appends SIEM finding events.
- Failure route (`siem_missed_alerts = true`) influences later consequence dialogue.

Therefore ensure:

- Variable names exactly match design docs.
- Result payload includes enough detail for optional NPC flavor reactions.

## Testing Plan

Unit-like checks (manual + script-level):

- Correct triage set -> success path writes expected globals.
- Missed critical -> failure path writes expected globals.
- Reopen state restore works (timer and row statuses).
- `siem_new_alert` injection works while panel is open.
- Event listeners cleaned on close (no duplicate listeners after reopen).

Gameplay checks:

- Room 2 laptop launches MG01 reliably.
- Ravi dialogue changes after success/failure.
- Command board reflects outcome.

Visual checks:

- Readable at target resolutions.
- Button affordance clear under pressure.
- Severity color and flashing behavior obvious but not noisy.

## Implementation Milestones

1. Scaffolding

- Create scene class, styles, registration, starter.

2. Core mechanics

- Seed data, triage actions, queue pane, timer, evaluation.

3. Integration

- Global variables + event emissions + scenario trigger route.

4. Persistence

- Save/restore state on reopen.

5. Visual pass

- Apply visualiser-compatible styling cues.

6. QA and balancing

- Tune timer, alert count, critical/noise ratio, readability.

## Balancing Defaults (Initial)

- Time limit: 180 seconds.
- Total alerts shown: 18 to 24.
- Critical alerts: 4 fixed (the canonical attack chain).
- Noise ratio: roughly 70% benign.
- Auto-injection: 1 to 3 additional alerts during play.

## Risks and Mitigations

Risk: player treats all alerts as ESCALATE spam.

- Mitigation: optional scoring penalty for over-escalation and Ravi feedback on triage quality.

Risk: visual overload harms comprehension.

- Mitigation: strict typography hierarchy, row spacing, severity anchors.

Risk: state desync with scenario progression.

- Mitigation: one authoritative completion write path and explicit completion event payload.

Risk: event listener leaks on reopen.

- Mitigation: register via `this.addEventListener` only, rely on base cleanup.

## Nice-to-Have Extensions

- Scorecard (precision/recall style) in post-result panel.
- Difficulty profiles (easy/normal/hard) by alert ambiguity.
- Context drawer: clicking an alert opens richer forensic details.
- Minor SFX tied to escalate/dismiss and critical arrival.

## Definition of Done

- MG01 launches from the intended in-world terminal.
- Player can complete triage loop with clear success/fail outcomes.
- `siem_escalated` / `siem_missed_alerts` update correctly.
- Re-entry persistence works in-session.
- Visual style reads as the same software ecosystem as existing SIEM visualiser mode.
- No regressions in existing minigame lifecycle behavior.
