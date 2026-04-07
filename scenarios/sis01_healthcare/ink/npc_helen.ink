// ===========================================
// NPC: Helen Carver (Information Governance Lead / DPO)
// Scenario: Northgate Hospital
// Role: ICO 72-hour notification clock; backup recovery advisory; CLAIM-HC-007
// CyBOK links: CLAIM-HC-007 (incident response plan), GDPR/DPA obligations
// ===========================================

// Global variables managed by scenario - declared locally here and updated by game engine
VAR network_isolated = false
VAR backup_restore_initiated = false

VAR helen_trust = 0
VAR topic_ico = false
VAR topic_backup = false
VAR topic_ir_plan = false
VAR ico_notified = false
VAR hc007_assessed = false
VAR backup_initiated = false

// Global reads: network_isolated, restore_operations, backup_initiated
// Global writes: ico_notified, safety_claim_hc007_assessed

// ===========================================
// FIRST ENCOUNTER
// ===========================================

=== start ===
#speaker:helen_carver

Helen: You need to know something important before anything else.

Helen: Under UK GDPR, we have 72 hours from the point of awareness to notify the ICO of a personal data breach.

Helen: That clock started when Ravi logged the incident. We have less than 71 hours left.

* [That's plenty of time]
    Helen: It sounds like it. But notification requires an assessment. We need to know what data was accessed.
    Helen: If we can't determine the scope, we notify anyway — and that looks worse.
    -> hub

* [When exactly did the clock start?]
    Helen: Ravi logged the SIEM alert at 09:47. That's our moment of awareness.
    Helen: Any delay in notification after that needs a documented reason.
    -> hub

* [What do we need to do?]
    -> backup_advisory


// ===========================================
// BACKUP ADVISORY
// ===========================================

=== backup_advisory ===
#speaker:helen_carver
~ topic_backup = true

Helen: Two priorities running in parallel. First: recovery.

Helen: The backup console in the server room holds our last clean state — eighteen hours ago.

Helen: Ravi can give you access details. There's a PIN on the console — Ravi knows it.

* [What's the recovery process?]
    Helen: The console has three restore options. Choose carefully — a cloud restore triggers an 18-hour timer.
    Helen: An on-site restore from tape is faster but requires physical media from the secure cabinet.
    Helen: Either way, document what you choose and why. The ICO will ask.
    -> hub

* [What's the second priority?]
    Helen: Notification. Once we have enough information to assess scope, we send the ICO notification.
    Helen: I can draft it — I just need to know: was patient data accessed or just encrypted in place?
    -> hub


// ===========================================
// CLAIM-HC-007
// ===========================================

=== safety_case_hc007 ===
#speaker:helen_carver
~ topic_ir_plan = true
~ hc007_assessed = true

Helen: CLAIM-HC-007: "Incident response decisions that impact clinical safety are made through integrated IT and clinical decision-making."

Helen: [Points to the Trust Safety Case document] This claim is about governance. It says that critical decisions like network isolation require both IT security and clinical sign-off.

Helen: When you get David's clinical code and Ravi's IT code and enter them together on the dual-auth panel, you're honouring this claim. Both perspectives, both accountabilities.

Helen: That's one of the few promises in the safety case we can actually keep right now.

* [So dual-auth is a safety control?]
    Helen: Exactly. It prevents one function — IT or clinical — from making a decision that affects patient safety unilaterally.
    Helen: Both must agree. Both must take responsibility.
    #set_global:safety_claim_hc007_assessed:true
    -> hub

* [What if we can't get both codes?]
    Helen: Then the dual-auth panel won't activate. The system is designed that way.
    Helen: In an extreme emergency with one person unavailable, there's an override, but that needs executive authorisation and is documented as a deviation.
    #set_global:safety_claim_hc007_assessed:true
    -> hub

* [What happens after isolation?]
    Helen: We document that the isolation decision was made through integrated governance. That goes in the post-incident report.
    Helen: And we recover systems within the defined window. That's the RTO commitment in the same claim.
    #set_global:safety_claim_hc007_assessed:true
    -> hub


// ===========================================
// ICO ADVISORY
// ===========================================

=== ico_advisory ===
#speaker:helen_carver
~ topic_ico = true

Helen: The ICO notification template is on my terminal. I need two things from you.

Helen: One: confirmation of what data was potentially accessed. Patient records? Staff records? Both?

Helen: Two: your sign-off as the incident lead that we've taken reasonable steps to contain the breach.

* {network_isolated} [Network is isolated — breach is contained]
    Helen: Good. That's "reasonable steps." I'll document the isolation time and method.
    Helen: I'll send the notification with a provisional scope. We can supplement it once forensics are done.
    ~ ico_notified = true
    #set_global:ico_notified:true
    #complete_task:notify_ico
    -> hub

* {not network_isolated} [Network isn't isolated yet]
    Helen: Then we can't say the breach is contained. The notification will need to reflect ongoing risk.
    Helen: Isolate the network, then come back to me.
    #influence_decreased
    -> hub

* [What if we get the scope wrong?]
    Helen: Better to over-report than under-report. The ICO treats good-faith notification favourably.
    Helen: Concealment or delay — that's where the serious fines come from.
    -> hub


// ===========================================
// POST-ISOLATION
// ===========================================

=== post_isolation ===
#speaker:helen_carver

{not ico_notified:
    Helen: Network isolated — that's the containment step I needed.
    Helen: Come and see me about the ICO notification. We're within the window but we shouldn't delay.
}
{ico_notified:
    Helen: ICO has been notified. We're on record as having acted promptly.
    Helen: Now it's about restoration and the post-incident report.
}

* [What do we do now?]
    Helen: Backup restoration, then scope assessment.
    Helen: I'll start drafting the incident report in parallel.
    -> hub


// ===========================================
// POST-BACKUP RESTORATION
// ===========================================

=== post_backup ===
#speaker:helen_carver
~ backup_initiated = true

Helen: Systems are coming back. That's the RTO met — just.

Helen: I need you to sign off the restoration record. Type, method, timestamp, authorising individual.

Helen: This goes into the SIRI — Serious Incident Requiring Investigation — report.

* [Consider it done]
    Helen: Thank you. Helen: Dr Sharma from the NCSC will want this documentation for her debrief.
    #complete_task:restore_operations
    -> hub

* [What's a SIRI?]
    Helen: It's the NHS framework for investigating serious incidents. This qualifies on multiple grounds.
    Helen: Ransomware on a cardiac ward with patient safety implications — that's a SIRI.
    -> hub


// ===========================================
// REPEATABLE HUB
// ===========================================

=== hub ===
#speaker:helen_carver

+ {not topic_backup} [Tell me about the backup process]
    -> backup_advisory

+ {not hc007_assessed} [Tell me about CLAIM-HC-007]
    -> safety_case_hc007

+ {not topic_ico or not ico_notified} [ICO notification]
    -> ico_advisory

+ {network_isolated and not backup_initiated} [Systems are isolated — what's next?]
    Helen: Restore from backup. The console is in the server room.
    Helen: Get Ravi's PIN, choose a restore method, and document everything.
    -> hub

+ [Leave conversation]
    {not ico_notified:
        Helen: Don't forget the ICO clock. Come back to me when network is isolated.
    }
    {ico_notified:
        Helen: Good work. Keep the documentation tight.
    }
    #exit_conversation
    -> DONE
