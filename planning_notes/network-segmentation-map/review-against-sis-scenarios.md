# MG-04 Network Segmentation Map Audit

## Scope And Precedence

This document reviews the current MG-04 implementation against the healthcare documentation under [planning_notes/sis_scenarios](../sis_scenarios/).

Precedence used for this audit:

1. [case_1_healthcare_game_design/minigame_planning.md](../sis_scenarios/case_1_healthcare_game_design/minigame_planning.md)
2. [case_1_healthcare_game_design/gdd.md](../sis_scenarios/case_1_healthcare_game_design/gdd.md)
3. [case_1_healthcare_game_design/scenario_implementation_notes.md](../sis_scenarios/case_1_healthcare_game_design/scenario_implementation_notes.md)
4. [case_1_healthcare_information_pack/system_architecture/network_architecture.md](../sis_scenarios/case_1_healthcare_information_pack/system_architecture/network_architecture.md)
5. [case_1_healthcare_information_pack/system_architecture/system_overview.md](../sis_scenarios/case_1_healthcare_information_pack/system_architecture/system_overview.md)
6. [case_1_healthcare_information_pack/storylines/northgate_incident.md](../sis_scenarios/case_1_healthcare_information_pack/storylines/northgate_incident.md)
7. Live scenario wiring in [scenarios/sis01_sis_healthcare/scenario.json.erb](../../scenarios/sis01_sis_healthcare/scenario.json.erb)

Lower-priority planning notes in [planning_notes/network-segmentation-map](.) were treated as secondary context only. If they conflict with the healthcare sources above, the healthcare sources win.

## Executive Summary

MG-04 is close in topology, state handling, and narrative intent, and the interaction model is now implemented. It is not fully aligned with the healthcare specification yet.

The two remaining blocking issues are:

1. The live scenario still uses a readable `smartscreen` stub instead of the interactive minigame.
2. The rule-toggle affordance does not match the explicit OPEN/CLOSED widget style described in the healthcare minigame planning notes.

The implementation now includes line-click rule toggling with enlarged hitboxes, per-rule consequence updates, attack-path overlays, and SEVER gating after first rule interaction.

## Criteria Review

### Topology And Labels

| Criterion                                                                      | Status | Notes                                                                                                         |
| ------------------------------------------------------------------------------ | ------ | ------------------------------------------------------------------------------------------------------------- |
| Four zones are rendered                                                        | MATCH  | External, Enterprise IT, Clinical/Device, and Legacy Flat Segment are present in the minigame implementation. |
| Canonical device names are used                                                | MATCH  | Device labels match the healthcare network architecture source rather than abbreviated placeholders.          |
| Legacy flat segment is shown explicitly                                        | MATCH  | The legacy ward segment is present as a distinct fourth zone, which is required by the information pack.      |
| External / Enterprise / Clinical connection structure matches the architecture | MATCH  | The primary topology follows the healthcare network architecture diagram.                                     |

### Interaction Model

| Criterion                                           | Status   | Notes                                                                                                   |
| --------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------- |
| Three legacy exception rules are part of the design | MATCH    | Rule 1, Rule 2, and Rule 3 are represented in the implementation logic and consequence text.            |
| Rule toggles are present in the live UI             | MATCH    | Rules are toggleable by clicking the line paths (with larger invisible hit targets).                    |
| Toggle affordance matches healthcare widget spec    | MATCH    | The implementation uses visible line-click toggles, which is the preferred and clearer interaction model. |
| Consequence panel changes by rule state             | MATCH    | The panel expands and contracts per toggle state.                                                       |
| Attack-path overlays are available                  | MATCH    | Red attack-path overlays appear when a rule is toggled open.                                            |
| network_rules_reviewed is set by the minigame       | MATCH    | The implementation writes `network_rules_reviewed` on first rule interaction.                           |
| SEVER is gated until the first toggle               | MATCH    | The button is disabled on open and only becomes active after the first rule interaction.                |

### SEVER Flow

| Criterion                              | Status | Notes                                                                 |
| -------------------------------------- | ------ | --------------------------------------------------------------------- |
| Confirmation modal appears             | MATCH  | The modal copy and buttons are present.                               |
| network_isolated is written on confirm | MATCH  | The implementation writes the global flag and emits the change event. |
| Post-sever visual state is shown       | MATCH  | The red X / disconnected state is rendered after confirmation.        |
| Auto-complete after isolation          | MATCH  | The minigame completes after the configured delay.                    |

### Narrative And State

| Criterion                                                     | Status | Notes                                                                                               |
| ------------------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------- |
| The map teaches incomplete segmentation as the attack surface | MATCH  | The consequence panel and labels frame the legacy rules as the vulnerable paths.                    |
| The security-safety trade-off is explicit                     | MATCH  | The consequence text explains the EHR and fleet-console impact of isolation.                        |
| Downstream state changes are wired into the scenario          | MATCH  | The healthcare scenario is designed to drive EHR and fleet-console fallout from `network_isolated`. |
| Prior isolation is detected on reopen                         | MATCH  | The minigame checks persisted state and shows the severed condition.                                |

### Visual Design

| Criterion                                               | Status   | Notes                                                                                                       |
| ------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------- |
| Pixel-art layout and panel structure                    | MATCH    | The overall minigame layout follows the documented full-panel style.                                        |
| Padlock and warning icons are used on the network lines | MATCH    | The visual primitives match the documentation intent.                                                       |
| Connection routing is readable and non-overlapping      | MATCH    | The current routing avoids the worst collisions with the device list blocks.                                |
| Legacy bridge `NO SEGMENTATION` label is present        | MATCH    | The legacy bridge label is rendered on the curved enterprise-to-legacy path.                              |
| Zone border colors match the healthcare visual spec     | PARTIAL  | The current CSS color order does not match the zone color order described in the healthcare planning notes. |

## Live Scenario Wiring Review

This section confirms the live scenario wiring for MG-04.

| Item                                                     | Status    | Notes                                                                                                          |
| -------------------------------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------- |
| `scenario.json.erb` uses the interactive minigame        | OK        | The `network_map_screen` object now uses the interactive `network-segmentation-map` type.                      |
| The stub sets `network_rules_reviewed` on read           | OK        | That state write is now handled by the minigame on first toggle interaction.                                    |
| The minigame type is referenced from the scenario object | OK        | The live scenario now points at the interactive minigame object.                                                |
| The minigame is registered in the client                 | OK        | The JavaScript implementation exists and is registered in the minigame framework.                              |
| Interaction routing exists in the client                 | OK        | The system can route a `network-segmentation-map` object to the minigame.                                      |

## Contradictions Between Docs

The healthcare documentation is not perfectly self-consistent on the draft interaction model, but the implementation now follows the higher-priority toggle-gated spec.

| Conflict                  | What It Says                                                                                                                                                                     | Audit Decision                                                    |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| Draft SEVER behavior      | Some draft UI notes say SEVER is immediately enabled in draft mode.                                                                                                              | Lower priority and no longer followed by the implementation.      |
| Healthcare minigame spec  | [minigame_planning.md](../sis_scenarios/case_1_healthcare_game_design/minigame_planning.md) says the player must toggle at least one exception rule before SEVER becomes active. | This wins, and the implementation now matches it.                 |
| Scenario stub vs minigame | The live scenario now uses the interactive minigame instead of the readable wall-display stub.                                                                                      | Resolved. |

## Findings

### What Matches Well

- The four-zone topology is present and grounded in the healthcare architecture source.
- The implementation models the three exception rules and the downstream isolation effect.
- The confirmation, isolation, and post-sever states are all implemented.
- The healthcare storyline is preserved: the user is deciding how to contain a compromise that already affects patient care.

### What Still Fails The Full Spec

- The zone color treatment is still slightly off compared with the planning notes.

## Priority Fix List

1. Align the zone border colors with the healthcare visual spec.

## Bottom Line

MG-04 is now structurally aligned with the healthcare interaction model, but it is not yet a perfect match to the healthcare documentation set.

The implementation matches the topology, toggle interaction model, and downstream security-safety narrative well. The remaining open issue is the zone color treatment noted above.
