# MG01 SIEM Dashboard - Strict Alignment Revision Plan (No Scope Expansion)

## Objective

Apply only minimal corrections so SIEM planning matches game_design exactly.

This plan does not add new features.
This plan does not change scenario flow.
This plan only resolves mismatches.

## Revision Set A - Required Corrections

### A1. Title and Header Identity

Change UI direction to use the exact in-world title:

- NORTHGATE TRUST // SIEM CONSOLE

Keep optional visual cues from the existing visualiser only where they do not alter this identity.

### A2. Layout Structure

Use the exact two-pane arrangement from game_design:

- Left pane (~70%): alert log stream.
- Right pane (~30%): escalated-for-review queue.

Remove the extra telemetry column from the primary layout.

### A3. Background and Base Tone

Use dark charcoal direction centered on:

- #1a1a2e

Other accent colors remain severity-driven and consistent with game_design.

### A4. Severity Labels and Badge Mapping

Use game_design label set in the UI:

- LOW, MED, HIGH, CRIT

Badge colors:

- LOW = grey
- MED = amber
- HIGH = orange
- CRIT = red (1 Hz flash)

### A5. Button Color Contract

Lock button visuals to game_design:

- DISMISS = dark grey
- ESCALATE = amber

### A6. Result Banner Copy

Use exact copy contract:

- Success: INCIDENT TEAM NOTIFIED
- Failure: CRITICAL ALERTS MISSED - INCIDENT ESCALATED

### A7. Status Bar Copy

Use exact status line structure:

- ALERTS PENDING: X | TIME REMAINING: MM:SS

## Revision Set B - Clarifications (Still No New Features)

### B1. Time Presentation Clarification

Preserve both game_design time elements without adding mechanics:

1. Header includes live system clock (top-right).
2. Bottom status bar includes countdown TIME REMAINING.

### B2. Event and Variable Name Lock

Keep exact interaction names for scenario compatibility:

- Event input: siem_new_alert
- Global outputs: siem_escalated, siem_missed_alerts

No aliasing or renaming.

### B3. Critical IoC Canonical Set

Keep the fixed canonical critical set in all examples and logic references:

- Encoded PowerShell execution
- LSASS access
- Anomalous SMB write volumes
- Cross-zone RDP sessions

## Revision Set C - Keep As-Is

The following existing planning choices should remain unchanged:

1. HTML/CSS implementation approach.
2. MinigameScene lifecycle integration and cleanup model.
3. Re-entry state persistence requirement.
4. Dynamic alert injection support while open.
5. Outcome signaling to downstream NPC/objective/command-board flow via existing global variable names.

## Acceptance Checklist

A revised SIEM planning package is aligned when all are true:

1. Header text exactly matches NORTHGATE TRUST // SIEM CONSOLE.
2. Primary layout is two-pane 70/30 as specified.
3. Required background direction uses #1a1a2e.
4. Severity labels and colors match LOW/MED/HIGH/CRIT mapping.
5. DISMISS/ESCALATE colors match dark grey/amber.
6. Result banner failure copy includes INCIDENT ESCALATED.
7. Global variable and event names match game_design exactly.
8. No additional features beyond game_design are introduced.

## Implementation Note

When updating the existing two SIEM planning docs in a later edit pass, apply only A1-A7 and B1-B3.
Do not modify scenario mechanics beyond those alignment corrections.
