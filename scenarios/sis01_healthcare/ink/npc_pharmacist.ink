// ===========================================
// NPC: On-Call Pharmacist
// Scenario: Northgate Hospital
// Role: Drug library verification; pump safety protocols; medication administration oversight
// Triggered: Called to Ward 7 after network isolation when drug library tampering is discovered
// ===========================================

// Global variables managed by scenario - declared locally here and updated by game engine
VAR drug_library_compromised = false
VAR drug_library_restored = false
VAR network_isolated = false
VAR clinical_staff_notified = false

// Local tracking vars for this NPC
VAR pharmacist_arrived = false
VAR library_concern_raised = false
VAR verification_explained = false
VAR suspension_confirmed = false
VAR resumption_confirmed = false

// Global reads: drug_library_compromised, drug_library_restored, clinical_staff_notified
// Global writes: (none)

// ===========================================
// FIRST ENCOUNTER — Arrival on Ward
// ===========================================

=== start ===
#speaker:pharmacist

{not pharmacist_arrived:
    Pharmacist: Sarah called me in. Something about the drug library being compromised?
    ~ pharmacist_arrived = true
    -> arrival_assessment
}

{pharmacist_arrived:
    Pharmacist: What else do you need to know about pump safety?
    -> hub
}


// ===========================================
// ARRIVAL ASSESSMENT
// ===========================================

=== arrival_assessment ===
#speaker:pharmacist

Pharmacist: I've been on-call for the incident response. Infusion pump safety is critical right now.

Pharmacist: If the drug library file was accessed during the attack, any dose limits could be wrong.

* [Yes, morphine DOSE_MAX was tampered with]
    ~ library_concern_raised = true
    Pharmacist: Morphine? That's a high-risk drug. What was the change?
    -> library_verification
    
* [We haven't confirmed the tampering yet]
    Pharmacist: Then that needs to be our first priority. David Osei can run the verification check on the pump management VM.
    -> hub

* [The library has already been restored]
    {drug_library_restored:
        Pharmacist: Good — then the clinical risk is mitigated. I'll do a final check on the restored file.
        ~ resumption_confirmed = true
        -> pump_safety_protocols
    }
    {not drug_library_restored:
        Pharmacist: Has it? I haven't heard that. Let's verify before I release any pump for use.
        -> hub
    }


// ===========================================
// LIBRARY VERIFICATION
// ===========================================

=== library_verification ===
#speaker:pharmacist
~ verification_explained = true

{drug_library_compromised:
    Pharmacist: From 4mg to how much?
    -> library_verification_details
}

{not drug_library_compromised:
    Pharmacist: The verification script on the VM should show the exact change. What did you find?
    -> hub
}


=== library_verification_details ===
#speaker:pharmacist

Pharmacist: Four to forty. That's a factor-of-ten error.

Pharmacist: A nurse could type what looks correct and the pump would silently accept a lethal dose.

Pharmacist: The guardrail is gone. The pump's supposed safety check can't catch it.

* [How do we handle this immediately?]
    -> pump_suspension
    
* [We need to restore the correct library]
    Pharmacist: Yes. And we need to do it now, before any more medication is administered.
    -> pump_suspension

* [What if medication was already given from the tampered library?]
    Pharmacist: Then we have a serious adverse event. Did any Alaris pump administer morphine in the last hour?
    -> hub


// ===========================================
// PUMP SUSPENSION
// ===========================================

=== pump_suspension ===
#speaker:pharmacist
~ suspension_confirmed = true

Pharmacist: Here's what we do:

Pharmacist: All infusion pump medication is suspended immediately. Sarah should have nursing only for now.

Pharmacist: No pump-administered drugs — morphine, heparin, insulin, anything requiring precision dosing.

Pharmacist: Manual administration by syringe driver or IV bolus. Yes, it's slower. Yes, it's more labour-intensive.

Pharmacist: But it's safe.

* [For how long?]
    Pharmacist: Until the restored drug library is verified against the backup hash.
    Pharmacist: David runs the verification script. Once it matches the reference, we're clear to resume.
    -> hub

* [Sarah's team won't like it]
    Pharmacist: Sarah put patient safety first when she called this in. She'll understand.
    Pharmacist: One hour of manual dosing beats one dose of morphine 40mg in a cardiac patient.
    -> hub


// ===========================================
// PUMP SAFETY PROTOCOLS
// ===========================================

=== pump_safety_protocols ===
#speaker:pharmacist
~ verification_explained = true

Pharmacist: Once the library is restored and verified, pumps can resume — but not without a checklist.

Pharmacist: First: I visually inspect the restored library on the VM. Morphine DOSE_MAX is back to 4mg.

Pharmacist: Second: Sarah or a deputy nurse visually confirms the dose on the bedside pump screen before administration.

Pharmacist: Third: I spot-check at least two pump administrations per shift while we're in recovery mode.

* [That's a lot of manual work]
    Pharmacist: It is. But the alternative is one keystroke error and a dead patient.
    Pharmacist: This is exactly why drug libraries exist — and exactly why they need verification.
    -> hub

* [When can we fully resume normal operations?]
    Pharmacist: Once the pump management server is running on the isolated clinical network and all safety checks pass.
    Pharmacist: I'd estimate 24 to 48 hours. Not faster — we're not rushing this.
    -> hub


// ===========================================
// RESUMPTION CONFIRMATION
// ===========================================

=== post_drug_restored ===
#speaker:pharmacist

{drug_library_restored and not resumption_confirmed:
    Pharmacist: Library's verified as clean. I've confirmed it against the backup hash.
    
    Pharmacist: Pumps are safe to resume — with the three-point checklist I mentioned.
    
    ~ resumption_confirmed = true
    
    * [What's the next step for you?]
        Pharmacist: Spot checks and documentation. Every pump administration goes into the incident log.
        Pharmacist: When the NCSC investigator arrives, they'll want to see that we verified every dose.
        -> hub
    
    * [Thank you]
        Pharmacist: Just doing my job. But thank you for taking drug safety seriously. Not everyone does.
        -> hub
}

{not drug_library_restored:
    Pharmacist: The library still isn't restored. Until it is, all pump medication stays suspended.
    -> hub
}


// ===========================================
// REPEATABLE HUB
// ===========================================

=== hub ===
#speaker:pharmacist

+ {not library_concern_raised and drug_library_compromised} [About the drug library tampering]
    -> library_verification

+ {suspension_confirmed and not drug_library_restored} [Status of pump suspension]
    Pharmacist: All pumps are suspended. Manual dosing only until the library is restored and verified.
    -> hub

+ {drug_library_restored and not resumption_confirmed} [Can we resume pump medication?]
    -> post_drug_restored

+ {resumption_confirmed and drug_library_restored} [How are the spot checks going?]
    Pharmacist: All documented. Every dose recorded with timestamp and pump ID.
    Pharmacist: When this is over, audit will have a full record.
    -> hub

+ [Leave conversation]
    {not drug_library_restored:
        Pharmacist: Stay alert. Drug safety is the line we don't cross.
    }
    {drug_library_restored:
        Pharmacist: Good work on getting that library back. Patient safety depends on attention to detail like this.
    }
    #exit_conversation
    -> DONE
