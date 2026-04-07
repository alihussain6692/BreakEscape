// ===========================================
// NPC: Dr Priya Sharma (NCSC Investigator)
// Scenario: Northgate Hospital
// Role: Post-incident debrief; safety case review; closing learning synthesis
// Triggered: when debrief_started = true (player has restored operations or time has elapsed)
// CyBOK links: All three claims; incident learning; SIS framework; organisational resilience
// ===========================================

// Global variables managed by scenario - declared locally here and updated by game engine
VAR bed4_escalated = false
VAR drug_tamper_found = false
VAR drug_library_restored = false
VAR network_isolated = false
VAR ico_notification_sent = false
VAR hc001_claim_assessed = false
VAR hc003_claim_assessed = false
VAR hc007_claim_assessed = false
VAR ico_deadline_missed = false
VAR vpn_anomaly_identified = false

VAR debrief_stage = 0
VAR topic_outcomes = false
VAR topic_claims = false
VAR topic_regulatory = false
VAR topic_root_cause = false
VAR closing_reached = false

// Global reads: bed4_escalated, drug_tamper_found, drug_library_restored,
//               network_isolated, restore_operations, ico_notification_sent,
//               hc001_claim_assessed, hc003_claim_assessed, hc007_claim_assessed,
//               major_incident_declared, ico_deadline_missed

// ===========================================
// ENTRY POINT — Debrief opens
// ===========================================

=== start ===
#speaker:dr_sharma

Dr Sharma: Good. Let's sit down. I'm Dr Priya Sharma — NCSC Healthcare Resilience team.

Dr Sharma: I've been briefed on the incident timeline. I'm here for the post-incident review, not to assign blame.

Dr Sharma: But I do need honest answers. What we learn here shapes guidance for every NHS Trust in England.

* [Where do we start?]
    -> patient_outcomes

* [Is this being recorded?]
    Dr Sharma: Everything goes into the NCSC incident database — anonymised. No names, no Trust identifiers.
    Dr Sharma: The learning matters. The blame doesn't — that's for the internal SIRI process.
    -> hub

* [What happens after this review?]
    Dr Sharma: We produce a structured finding. It goes to NHS England, DSPT team, and back to you.
    Dr Sharma: Recommendations are non-binding — but Trusts that ignore them tend to appear in our reports again.
    -> hub


// ===========================================
// PATIENT OUTCOMES
// ===========================================

=== patient_outcomes ===
#speaker:dr_sharma
~ topic_outcomes = true

Dr Sharma: First question: patient outcomes. Were any patients harmed?

{bed4_escalated:
    Dr Sharma: Bed 4 was escalated early. That's the right call — monitoring the unmonitored.
    Dr Sharma: Mrs Fletcher was reviewed by the registrar. No adverse outcome.
}
{not bed4_escalated:
    Dr Sharma: Bed 4 wasn't escalated during the incident window.
    Dr Sharma: Mrs Fletcher experienced an extended period without monitoring. She was fortunate.
    Dr Sharma: That near-miss needs to be in the SIRI report.
    #influence_decreased
}

{drug_library_restored:
    Dr Sharma: Drug library was identified as tampered and restored before any compromised doses were administered.
    Dr Sharma: That's CLAIM-HC-003 working — eventually.
}
{drug_tamper_found and not drug_library_restored:
    Dr Sharma: The drug library tamper was found but not restored during the incident.
    Dr Sharma: Were pumps suspended? If medication continued from a tampered library, we have a serious patient safety event.
    #influence_decreased
}
{not drug_tamper_found:
    Dr Sharma: The drug library anomaly wasn't detected during the incident.
    Dr Sharma: That's a significant gap. A morphine DOSE_MAX of 40mg instead of 4mg is potentially lethal.
    #influence_decreased
}

-> hub


// ===========================================
// SAFETY CLAIMS REVIEW
// ===========================================

=== safety_claims ===
#speaker:dr_sharma
~ topic_claims = true

Dr Sharma: Let's go through the safety case claims. Three were active during this incident.

Dr Sharma: CLAIM-HC-001: Network segmentation. Was it assessed before the isolation decision?

{hc001_claim_assessed:
    Dr Sharma: Good. David Osei reviewed it. The VPN perimeter gap was noted.
    Dr Sharma: That's honest safety case management — acknowledging where the claim didn't hold.
}
{not hc001_claim_assessed:
    Dr Sharma: It wasn't formally assessed. You isolated without reviewing the claim.
    Dr Sharma: The outcome was correct, but the process wasn't. Safety cases exist precisely for this.
    #influence_decreased
}

Dr Sharma: CLAIM-HC-003: Drug library integrity. Assessed?

{hc003_claim_assessed:
    Dr Sharma: Reviewed with David. The correct response — check the claim, verify the library.
}
{not hc003_claim_assessed:
    Dr Sharma: Not reviewed. A safety claim directly affecting patient lives went unchecked.
    Dr Sharma: If a nurse had administered morphine from that tampered library, we'd be having a very different conversation.
    #influence_decreased
}

Dr Sharma: CLAIM-HC-007: Incident response RTO. Met?

{hc007_claim_assessed:
    Dr Sharma: Assessed with Helen. The RTO was tight but the decision to escalate was documented.
}
{not hc007_claim_assessed:
    Dr Sharma: Not reviewed. You managed to recover, but without a framework.
    Dr Sharma: Lucky this time. Not a robust position.
    #influence_decreased
}

-> hub


// ===========================================
// REGULATORY
// ===========================================

=== regulatory ===
#speaker:dr_sharma
~ topic_regulatory = true

Dr Sharma: Regulatory compliance. ICO notification — made within 72 hours?

{ico_notification_sent:
    Dr Sharma: Notification sent. Helen Carver managed this well.
    Dr Sharma: Any breach of this scale affecting special category health data requires prompt disclosure.
    Dr Sharma: You met the obligation.
}
{ico_deadline_missed:
    Dr Sharma: The 72-hour window passed without notification.
    Dr Sharma: The ICO will look at this. Not just the breach, but the failure to report.
    Dr Sharma: Expect a follow-up assessment from the ICO's healthcare team.
    #influence_decreased
}
{not ico_notification_sent and not ico_deadline_missed:
    Dr Sharma: Notification hasn't been sent yet, but you're still within the window.
    Dr Sharma: That needs to happen before this debrief ends.
}

Dr Sharma: DSPT — Data Security and Protection Toolkit — you'll need to update your submission.

Dr Sharma: This incident is a mandatory disclosure item. It affects your assurance rating.

* [Understood]
    -> hub
* [What does that mean practically?]
    Dr Sharma: Your Trust's data security assurance is publicly reported. A serious incident affects that rating.
    Dr Sharma: It also feeds into your cyber insurance renewal and any NHS England performance review.
    -> hub


// ===========================================
// ROOT CAUSE
// ===========================================

=== root_cause ===
#speaker:dr_sharma
~ topic_root_cause = true

Dr Sharma: Root cause analysis. What was the initial access vector?

{vpn_anomaly_identified:
    Dr Sharma: VPN credential compromise — contractor account c.ellison, no MFA.
    Dr Sharma: That's a textbook initial access finding. Stale account plus absent MFA equals open door.
}
{not vpn_anomaly_identified:
    Dr Sharma: Initial access vector wasn't confirmed during the incident.
    Dr Sharma: Without that, we can't close the gap. The attacker may still have a valid path back in.
    #influence_decreased
}

Dr Sharma: Contributing factors: unpatched VPN endpoint, no MFA enforcement, leavers not deprovisioned.

Dr Sharma: These aren't exotic vulnerabilities. They're standard hygiene failures.

* [What should we have had in place?]
    Dr Sharma: MFA on all remote access. Account deprovisioning SLA — 24 hours maximum.
    Dr Sharma: Privileged access review every 90 days. These are Cyber Essentials baseline requirements.
    -> hub

* [Is this common across NHS Trusts?]
    Dr Sharma: More common than I'd like. Resource constraints, legacy systems, competing priorities.
    Dr Sharma: That's why the NCSC publishes sector-specific guidance. It doesn't require a large budget.
    -> hub


// ===========================================
// CLOSING — Learning synthesis
// ===========================================

=== closing ===
#speaker:dr_sharma
~ closing_reached = true

Dr Sharma: One final question. And I want you to think about it seriously.

Dr Sharma: The safety case claims existed before this attack. The VPN gap was a known risk.

Dr Sharma: Someone — maybe many people — knew the system wasn't fully safe, and operations continued anyway.

Dr Sharma: That's not unusual. It's called "normalisation of deviance." Risk becomes normal because nothing has gone wrong yet.

* [What do you do about that?]
    Dr Sharma: You make the risk visible. Regularly. To people with authority to act on it.
    Dr Sharma: Not in a risk register that nobody reads — in front of the board, in front of the clinicians.
    Dr Sharma: Safety cases only work if they're living documents, not compliance artefacts.
    -> debrief_complete

* [Was this preventable?]
    Dr Sharma: Almost entirely. The technical controls were understood. The process controls were documented.
    Dr Sharma: The gap was organisational — the will to act before an incident, not after.
    -> debrief_complete

* [What changes after today?]
    Dr Sharma: That depends on you. The recommendations will come. Whether they're implemented is a leadership question.
    Dr Sharma: Every Trust that's been through this says "never again." Some mean it.
    -> debrief_complete

=== debrief_complete ===
#speaker:dr_sharma

Dr Sharma: Thank you for your candour today. The review report will be with your board within four weeks.

Dr Sharma: The patients were fortunate. Let's make sure the next Trust doesn't have to rely on fortune.

#complete_task:complete_debrief
#set_global:debrief_complete:true

-> DONE


// ===========================================
// REPEATABLE HUB
// ===========================================

=== hub ===
#speaker:dr_sharma

+ {not topic_outcomes} [Let's start with patient outcomes]
    -> patient_outcomes

+ {not topic_claims} [Review the safety case claims]
    -> safety_claims

+ {not topic_regulatory} [Regulatory compliance]
    -> regulatory

+ {not topic_root_cause} [Root cause analysis]
    -> root_cause

+ {topic_outcomes and topic_claims and topic_regulatory and topic_root_cause and not closing_reached} [Are we done?]
    -> closing

+ {closing_reached} [Closing remarks]
    -> closing

+ [Leave debrief for now]
    Dr Sharma: We can continue. But try to cover all four areas — the findings need to be complete.
    #exit_conversation
    -> DONE
