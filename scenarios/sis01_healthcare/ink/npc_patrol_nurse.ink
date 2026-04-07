// ===========================================
// NPC: Patrol Nurse (Staff Nurse, unnamed)
// Scenario: Northgate Hospital
// Role: Background colour; Bed 4 escalation reinforcement; drug safety reaction
// Note: Patrol behaviour drives this NPC. Dialogue is brief — she is always busy.
// ===========================================

// Global variables managed by scenario - declared locally here and updated by game engine
VAR bed4_escalated = false
VAR drug_library_compromised = false

VAR patrol_acknowledged = false
VAR bed4_mentioned = false
VAR drug_warning_given = false

// ===========================================
// DEFAULT (patrol loop, player interrupts)
// ===========================================

=== patrol_idle ===
#speaker:patrol_nurse

{not patrol_acknowledged:
    Nurse: Sorry — mid-round. Everything okay?
    * [Just checking in]
        Nurse: We're managing. Barely.
        ~ patrol_acknowledged = true
        #exit_conversation
        -> DONE
    * [How is the ward coping?]
        Nurse: Running spot checks every fifteen minutes by hand. It's not enough for these patients.
        ~ patrol_acknowledged = true
        -> hub
}

{patrol_acknowledged:
    Nurse: Still here. Need something?
    -> hub
}

=== hub ===
#speaker:patrol_nurse

+ {not bed4_mentioned} [How is the patient in Bed 4?]
    ~ bed4_mentioned = true
    Nurse: Mrs Fletcher? She's been unsettled. Charge nurse is keeping a close eye.
    {not bed4_escalated:
        Nurse: Someone should really escalate that to the registrar.
    }
    {bed4_escalated:
        Nurse: Dr Hassan's been down. Good thing someone flagged it.
    }
    -> hub

+ [Anything I should know?]
    Nurse: Just... get the monitors back online. Please.
    -> hub

+ [Leave her to her rounds]
    Nurse: Back to it then.
    #exit_conversation
    -> DONE


// ===========================================
// RUSHING TO BED 4 (triggered when bed4_escalated = true, NPC rerouted)
// ===========================================

=== rushing_bed4 ===
#speaker:patrol_nurse

Nurse: No time — Bed 4. Talk to Sarah if you need something.

#exit_conversation
-> DONE


// ===========================================
// AFTER DRUG TAMPER DISCOVERED
// ===========================================

=== post_drug ===
#speaker:patrol_nurse

{not drug_warning_given:
    ~ drug_warning_given = true
    Nurse: Charge nurse has suspended pump medication pending library verification.
    Nurse: We're going to manual dosing. More paperwork, but it's safe.
    * [Is that manageable?]
        Nurse: It has to be. Patient safety first.
        -> hub
    * [Good call by Sarah]
        Nurse: She always puts patients first. That's why she's charge nurse.
        -> hub
}

{drug_warning_given:
    Nurse: Pumps are still suspended. Waiting on library confirmation.
    -> hub
}
