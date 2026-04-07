# MG01 SIEM Dashboard - Alignment Audit Against game_design

## Purpose

This document audits the existing SIEM planning docs against game_design source documents.

Reviewed source set:

- game_design/minigame_design_guide.md
- game_design/minigame_planning.md
- game_design/new_objects_planning.md
- game_design/healthcare_draft/gdd.md
- game_design/healthcare_draft/gdd_walkthrough.md

Reviewed SIEM planning docs:

- planning_notes/siem/MG01_siem_implementation_plan.md
- planning_notes/siem/MG01_siem_ui_ideas_and_visual_direction.md

## Non-Negotiable MG01 Requirements (From game_design)

1. Minigame category: HTML/CSS.
2. Scenario position: Room 2, Ravi Anand's laptop.
3. Core mechanic: mixed alert stream with row actions DISMISS or ESCALATE.
4. Correct critical IoCs include:

- Encoded PowerShell execution.
- LSASS access.
- Anomalous SMB write volumes.
- Cross-zone RDP sessions.

5. Outcome variables:

- Success path writes siem_escalated = true.
- Missed critical path writes siem_missed_alerts = true.

6. Re-entry behavior: minigame state must persist on reopen.
7. Runtime injection support: siem_new_alert event can add alerts.
8. Required visual structure:

- Header text: NORTHGATE TRUST // SIEM CONSOLE.
- Dark charcoal panel background (#1a1a2e).
- Left alert pane (~70%) and right escalation queue (~30%).
- Bottom status bar with ALERTS PENDING and TIME REMAINING.
- Result banner text includes full failure wording: CRITICAL ALERTS MISSED - INCIDENT ESCALATED.

9. Required visual behavior:

- CRIT flashes at 1 Hz.
- Dismissed rows fade and shift left.
- Escalated rows show green left border and move to queue.

## What Is Already Correct in Current SIEM Plans

1. Framework approach is correct: MinigameScene-based HTML/CSS minigame.
2. Interaction model is correct: per-row DISMISS/ESCALATE triage.
3. Scenario integration intent is correct: Ravi laptop in Room 2.
4. Global variable writebacks use the correct names (siem_escalated / siem_missed_alerts).
5. Event model includes siem_new_alert and ransomware-driven alert surge behavior.
6. Persistence is explicitly planned (save/restore state on reopen).
7. Critical IoC examples match the game_design narrative.

## Mismatches Found

1. UI plan header branding is not aligned:

- Uses SAFETYNET/ops-suite style header instead of required NORTHGATE TRUST // SIEM CONSOLE.

2. UI plan layout departs from required two-pane structure:

- Introduces a dedicated third telemetry column.
- game_design specifies two-pane composition (left log + right escalation queue).

3. UI plan color tokens diverge from specified background:

- Uses alternate dark values instead of required #1a1a2e base direction.

4. UI plan severity naming drifts from game_design naming:

- Adds INFO and uses MEDIUM/CRITICAL wording instead of MED/CRIT naming in visual labels.

5. Failure banner text is abbreviated in the UI plan:

- Must retain full message: CRITICAL ALERTS MISSED - INCIDENT ESCALATED.

6. UI plan does not explicitly lock button color mapping:

- game_design explicitly calls for DISMISS dark grey and ESCALATE amber.

## Audit Conclusion

The implementation plan is mostly aligned on mechanics and integration.
The UI ideas plan needs a strict alignment pass for naming, structure, and exact visual callouts from game_design.

No expansion of feature scope is required.
No new gameplay systems are required.
