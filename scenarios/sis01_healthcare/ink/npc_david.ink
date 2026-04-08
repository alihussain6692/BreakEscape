// ===========================================
// NPC: David Osei (Clinical Safety Engineer)
// Scenario: Northgate Hospital
// Role: Safety case advisor; issues clinical PIN for dual-auth; drug library verification
// CyBOK links: CLAIM-HC-001 (segmentation), CLAIM-HC-003 (drug library integrity)
// ===========================================

// Global variables managed by scenario - declared locally here and updated by game engine
VAR siem_escalated = false
VAR vpn_anomaly_identified = false
VAR network_isolated = false
VAR drug_tamper_found = false

VAR clinical_pin = ""

VAR david_trust = 0
VAR topic_safety_case = false
VAR topic_dual_auth = false
VAR topic_drug_library = false
VAR gave_clinical_code = false
VAR hc001_assessed = false
VAR hc003_assessed = false

// Global reads: siem_escalated, vpn_anomaly_identified, network_isolated, drug_tamper_found, clinical_pin
// Global writes: clinical_eng_authorised, safety_claim_hc001_assessed, safety_claim_hc003_assessed

// ===========================================
// FIRST ENCOUNTER
// ===========================================

=== start ===
#speaker:david_osei

David: You're the team lead? Good. I've been trying to get someone to talk to me about the safety case.

David: I'm the Clinical Safety Engineer. My job is to make sure cyber incidents don't become clinical ones.

David: Before we authorise any major system intervention, I need to walk you through the relevant claims. [Points to the Trust Safety Case document on the table]

* [What's a safety case in this context?]
    David: A safety case is a structured argument that a system is acceptably safe to operate. [Pulls out the document]
    David: This is ours — written by the clinical engineering and IT security teams. It spells out the key assumptions we made about how the network is architected and managed.
    David: We have three active claims affected by this incident. I need you to understand them before we act.
    -> safety_case_hc001

* [We're running out of time — can we skip this?]
    David: You can skip it. But if something goes wrong and we haven't assessed the safety implications, that's on the record.
    David: Fifteen minutes with me now could save an inquest later.
    #influence_decreased
    -> hub

* [Walk me through it]
    -> safety_case_hc001


// ===========================================
// CLAIM-HC-001: Network Segmentation
// ===========================================

=== safety_case_hc001 ===
#speaker:david_osei
~ topic_safety_case = true
~ hc001_assessed = true

David: CLAIM-HC-001: "Network segmentation prevents ransomware from propagating to clinical device networks."

David: [Opens the safety case document and points to the claim] This is the cornerstone. We designed a network with three zones — Enterprise, Clinical, and Legacy. Firewalls between them.

David: The claim was written eighteen months ago when we separated the admin network from the clinical network.

David: But look at the network diagram in the IT office — those dual-homed workstations break the firewall boundary. They're exception rules we added for legacy systems. If the attacker entered via one of those exceptions, segmentation didn't stop the spread.

* [So the claim is invalidated?]
    David: Partially. The claim holds for propagation within the hospital. It failed at the perimeter — at the exceptions.
    David: We need to note this for the post-incident review. The dual-homed workstation exceptions were a known gap we never fixed.
    ~ david_trust += 10
    #set_global:safety_claim_hc001_assessed:true
    -> hub

* [Does that mean we shouldn't isolate?]
    David: No — isolation is still the right call. It limits further spread.
    David: But we should document that CLAIM-HC-001 was not a complete safeguard. The exceptions broke it.
    #set_global:safety_claim_hc001_assessed:true
    -> hub

* [What should we do about the dual-homed workstations?]
    David: Post-incident: remove them. Move the legacy devices to a properly firewalled segment with restricted access.
    David: Right now: isolate, recover, then fix the exceptions.
    #set_global:safety_claim_hc001_assessed:true
    -> hub


// ===========================================
// GIVE CLINICAL PIN
// ===========================================

=== give_clinical_code ===
#speaker:david_osei

{not gave_clinical_code:
    {hc001_assessed:
        David: You've engaged with the safety case. That's what I needed to see.
        David: My authorisation code for the dual-auth panel — clinical side: {clinical_pin}.
        David: Use it with Ravi's IT security code. Both are required.
        David: And David: document that CLAIM-HC-001 was assessed before activation.
        ~ gave_clinical_code = true
        #set_global:clinical_eng_authorised:true
        #complete_task:obtain_clinical_code
        -> hub
    }
    {not hc001_assessed:
        David: Before I give you the code, I need you to understand what we're authorising.
        David: Walk through CLAIM-HC-001 with me first.
        -> safety_case_hc001
    }
}

{gave_clinical_code:
    David: You have my code. Use the dual-auth panel when you're ready.
    -> hub
}


// ===========================================
// CLAIM-HC-003: Drug Library Integrity
// ===========================================

=== safety_case_hc003 ===
#speaker:david_osei
~ topic_drug_library = true
~ hc003_assessed = true

David: CLAIM-HC-003: "Infusion pump drug libraries are verified against a trusted hash before clinical use."

David: The drug library on the pump management server may have been tampered with during the attack.

David: If dose limits were altered and a nurse administers a drug without a guardrail warning — that's a patient safety event.

* [How do we verify the library?]
    David: There's a backup hash file on the pump management VM.
    David: Run verify_library.sh — it compares the active library against the reference hash.
    David: If morphine's DOSE_MAX has been changed from 4mg to anything higher, that's your tamper signature.
    #set_global:safety_claim_hc003_assessed:true
    #unlock_task:verify_drug_library
    -> hub

* [Can nurses still use the pumps?]
    David: Not safely until we verify the library. I'd recommend Sarah suspends pump-administered medication.
    David: Manual dosing is slower but the risk profile is known.
    #set_global:safety_claim_hc003_assessed:true
    -> hub

* [What happens if we miss this?]
    David: Best case: a near-miss that gets caught at the bedside. Worst case: a patient receives a fatal dose.
    David: This is exactly the scenario CLAIM-HC-003 was written to prevent.
    #set_global:safety_claim_hc003_assessed:true
    -> hub


// ===========================================
// POST-ISOLATION
// ===========================================

=== post_isolation ===
#speaker:david_osei

{hc001_assessed:
    David: Network isolated. CLAIM-HC-001 partially vindicated.
    David: The segmentation did limit spread once the attacker was inside. The VPN gap is a separate finding.
}
{not hc001_assessed:
    David: Network isolated — but did anyone assess the safety case before we acted?
    David: For the record: CLAIM-HC-001 was not formally reviewed before this intervention.
    #influence_decreased
}

David: Now we need to focus on the drug library. That's CLAIM-HC-003. Don't let it slip.

* [I'm on it]
    -> hub
* [Tell me about CLAIM-HC-003]
    -> safety_case_hc003


// ===========================================
// REPEATABLE HUB
// ===========================================

=== hub ===
#speaker:david_osei

+ {not hc001_assessed} [Tell me about CLAIM-HC-001]
    -> safety_case_hc001

+ {not hc003_assessed} [Tell me about CLAIM-HC-003]
    -> safety_case_hc003

+ {not topic_dual_auth} [How does the dual-auth panel work?]
    ~ topic_dual_auth = true
    David: It's a safeguard we introduced after the last risk assessment.
    David: Any network intervention above a certain impact threshold requires two authorised codes.
    David: One from IT security, one from clinical safety. Neither can act unilaterally.
    David: [Points to safety case document] CLAIM-HC-007 says this integrated decision-making prevents incident response from creating clinical hazards.
    David: So long as we involve both teams, we're honouring that claim.
    -> hub

+ {hc001_assessed and not gave_clinical_code} [I need your authorisation code]
    -> give_clinical_code

+ {drug_tamper_found and not hc003_assessed} [The drug library was tampered with]
    -> safety_case_hc003

+ [Leave conversation]
    David: Safety case documentation goes to the post-incident review. Don't forget that.
    #exit_conversation
    -> DONE
