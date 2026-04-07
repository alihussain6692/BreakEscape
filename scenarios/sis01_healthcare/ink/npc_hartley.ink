// ===========================================
// NPC: Dr Fiona Hartley (Clinical Director)
// Scenario: Northgate Hospital
// Role: Patient data accountability; disclosure law; Major Incident declaration
// CyBOK links: Legal/regulatory context; data controller obligations
// Priority: Medium — she is available once debrief_started is false but becomes central
//           if the ICO deadline is missed
// ===========================================

// Global variables managed by scenario - declared locally here and updated by game engine
VAR ico_notification_sent = false
VAR restore_operations = false
VAR ico_deadline_missed = false

VAR hartley_trust = 0
VAR topic_patient_data = false
VAR topic_disclosure = false
VAR topic_major_incident = false
VAR deadline_warned = false

// Global reads: ico_notification_sent, restore_operations, ico_deadline_missed
// Global writes: major_incident_declared

// ===========================================
// FIRST ENCOUNTER
// ===========================================

=== start ===
#speaker:dr_hartley

Dr Hartley: I need to understand the patient data exposure before I can speak to the board.

Dr Hartley: We are the data controller. Whatever happened to that data is our liability.

* [What data is at risk?]
    -> patient_data

* [The ICO has already been notified]
    {ico_notification_sent:
        Dr Hartley: Good. That's the right call. What was the assessed scope?
        ~ hartley_trust += 10
        -> hub
    }
    {not ico_notification_sent:
        Dr Hartley: Has it? I haven't seen anything from Helen.
        Dr Hartley: If that notification hasn't gone, we need to fix that now.
        -> hub
    }

* [We should declare a Major Incident]
    -> topic_major_incident_talk


// ===========================================
// PATIENT DATA
// ===========================================

=== patient_data ===
#speaker:dr_hartley
~ topic_patient_data = true

Dr Hartley: We hold records for 40,000 registered patients. That includes diagnoses, medications, next-of-kin.

Dr Hartley: The ransomware encrypted files — but did it exfiltrate them first?

Dr Hartley: That's the question the ICO will ask. "Was data taken, or merely locked?"

* [We don't know yet]
    Dr Hartley: Then we notify as a precaution and update the ICO when forensics complete.
    Dr Hartley: The worst outcome is knowing data was taken and failing to disclose. That's a six-figure fine.
    ~ hartley_trust += 5
    -> hub

* [The network logs should tell us]
    Dr Hartley: Correct. Large outbound transfers in the hours before the ransom screen appeared.
    Dr Hartley: Check the SIEM for outbound data volume. If there's a spike — we assume exfiltration.
    -> hub

* [We should assume the worst]
    Dr Hartley: That's the prudent legal position. Assume exfiltration, disclose promptly, update as facts emerge.
    ~ hartley_trust += 10
    -> hub


// ===========================================
// DISCLOSURE LAW
// ===========================================

=== disclosure_law ===
#speaker:dr_hartley
~ topic_disclosure = true

Dr Hartley: UK GDPR Article 33. 72-hour notification to the supervisory authority — that's the ICO.

Dr Hartley: Article 34 if there's a high risk to individuals — direct notification to affected patients.

Dr Hartley: We're a healthcare organisation. The threshold for "high risk" is lower than for, say, a retailer.

* [Do we need to contact patients directly?]
    Dr Hartley: Almost certainly — once we've assessed scope.
    Dr Hartley: Clinical records are special category data. Any breach involving them likely triggers Article 34.
    -> hub

* [What are the penalties for missing the deadline?]
    Dr Hartley: Up to £17.5 million or four percent of global turnover under UK GDPR.
    Dr Hartley: For an NHS Trust, the reputational damage is arguably worse than the fine.
    -> hub

* [Helen is handling the notification]
    Dr Hartley: Good. Make sure she has everything she needs. I'll co-sign the notification as data controller.
    -> hub


// ===========================================
// MAJOR INCIDENT DISCUSSION
// ===========================================

=== topic_major_incident_talk ===
#speaker:dr_hartley
~ topic_major_incident = true

Dr Hartley: Major Incident declaration. That's not a decision I take lightly.

Dr Hartley: It triggers the NHS England reporting chain, media protocols, executive escalation.

* [We've exceeded the monitoring RTO]
    {restore_operations:
        Dr Hartley: Systems are recovering — I'd say we're at the boundary.
        Dr Hartley: If monitoring is back within the hour, we can document near-miss rather than full Major Incident.
        -> hub
    }
    {not restore_operations:
        Dr Hartley: Then I have no choice.
        Dr Hartley: Major Incident declared. The command board in the Incident Room becomes the operational hub.
        #set_global:major_incident_declared:true
        #complete_task:declare_major_incident
        -> hub
    }

* [Not yet — we're close to recovery]
    Dr Hartley: I'll hold for thirty minutes. If monitoring isn't restored by then, I'm declaring.
    Dr Hartley: Document this conversation. Time-stamped decision points matter.
    -> hub


// ===========================================
// POST-ICO NOTIFICATION
// ===========================================

=== post_ico ===
#speaker:dr_hartley

{ico_notification_sent:
    Dr Hartley: Helen told me the ICO notification has gone. Good.
    Dr Hartley: We're on record as having acted within the window. That counts for a great deal.
    ~ hartley_trust += 15
}
{not ico_notification_sent:
    Dr Hartley: The notification still hasn't gone?
    Dr Hartley: Every hour we delay now increases our exposure. Please get Helen to send it.
    #influence_decreased
}

-> hub


// ===========================================
// ICO DEADLINE MISSED
// ===========================================

=== deadline_missed ===
#speaker:dr_hartley
~ deadline_warned = true

Dr Hartley: The 72-hour window has passed and we haven't notified the ICO.

Dr Hartley: I have to self-report the delay. That will be noted in any investigation.

Dr Hartley: This is exactly the kind of governance failure that ends careers and costs organisations millions.

* [We can still notify late]
    Dr Hartley: We can — and we must. Late notification with a clear reason is better than no notification.
    Dr Hartley: Document everything: what delayed us, what we were doing instead, who made the call.
    #influence_decreased
    -> hub

* [I didn't know about the deadline]
    Dr Hartley: Helen Carver told you at the start. The clock was running from minute one.
    Dr Hartley: This is why information governance isn't optional in a cyber incident.
    #influence_decreased
    -> hub


// ===========================================
// REPEATABLE HUB
// ===========================================

=== hub ===
#speaker:dr_hartley

+ {not topic_patient_data} [What data are we responsible for?]
    -> patient_data

+ {not topic_disclosure} [What are our legal obligations?]
    -> disclosure_law

+ {not topic_major_incident} [Should we declare a Major Incident?]
    -> topic_major_incident_talk

+ {ico_notification_sent and not hartley_trust >= 20} [The ICO notification has been sent]
    -> post_ico

+ {ico_deadline_missed and not deadline_warned} [About the ICO deadline...]
    -> deadline_missed

+ [Leave conversation]
    {not ico_notification_sent:
        Dr Hartley: The ICO clock is running. Don't let it expire.
    }
    {ico_notification_sent:
        Dr Hartley: We're compliant. Focus on restoration.
    }
    #exit_conversation
    -> DONE
