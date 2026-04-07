// Export minigame framework
export { MinigameFramework } from './framework/minigame-manager.js';
export { MinigameScene } from './framework/base-minigame.js';

// Export minigame implementations
export { LockpickingMinigamePhaser } from './lockpicking/lockpicking-game-phaser.js';
export { DustingMinigame } from './dusting/dusting-game.js';
export { NotesMinigame, startNotesMinigame, showMissionBrief } from './notes/notes-minigame.js';
export { BluetoothScannerMinigame, startBluetoothScannerMinigame } from './bluetooth/bluetooth-scanner-minigame.js';
export { BiometricsMinigame, startBiometricsMinigame } from './biometrics/biometrics-minigame.js';
export { ContainerMinigame, startContainerMinigame, returnToContainerAfterNotes, returnToConversationAfterNPCInventory } from './container/container-minigame.js';
export { PhoneChatMinigame, returnToPhoneAfterNotes } from './phone-chat/phone-chat-minigame.js';
export { PersonChatMinigame } from './person-chat/person-chat-minigame.js?v=11';
export { PinMinigame, startPinMinigame } from './pin/pin-minigame.js';
export { PasswordMinigame } from './password/password-minigame.js';
export { TextFileMinigame, returnToTextFileAfterNotes } from './text-file/text-file-minigame.js';
export { TitleScreenMinigame, startTitleScreenMinigame } from './title-screen/title-screen-minigame.js';
export { RFIDMinigame, startRFIDMinigame, returnToConversationAfterRFID } from './rfid/rfid-minigame.js';
export { VmLauncherMinigame } from './vm-launcher/vm-launcher-minigame.js';
export { FlagStationMinigame } from './flag-station/flag-station-minigame.js?v=6';
export { RansomwareDisplayMinigame } from './ransomware-display/ransomware-display-minigame.js';
export { SiemDashboardMinigame } from './siem/siem-dashboard-minigame.js';
export { NetworkSegmentationMapMinigame, startNetworkSegmentationMapMinigame } from './network-segmentation-map/network-segmentation-map-minigame.js';
export { DualAuthMinigame } from './dual-auth/dual-auth-minigame.js';

// Initialize the global minigame framework for backward compatibility
import { MinigameFramework } from './framework/minigame-manager.js';
import { LockpickingMinigamePhaser } from './lockpicking/lockpicking-game-phaser.js';

// Make the framework available globally 
window.MinigameFramework = MinigameFramework;

// Add global helper functions for debugging
window.restartMinigame = () => {
    if (window.MinigameFramework) {
        window.MinigameFramework.restartCurrentMinigame();
    } else {
        console.log('MinigameFramework not available');
    }
};

window.closeMinigame = () => {
    if (window.MinigameFramework) {
        window.MinigameFramework.forceCloseMinigame();
    } else {
        console.log('MinigameFramework not available');
    }
};

// Import the dusting minigame
import { DustingMinigame } from './dusting/dusting-game.js';

// Import the notes minigame
import { NotesMinigame, startNotesMinigame, showMissionBrief } from './notes/notes-minigame.js';

// Import the bluetooth scanner minigame
import { BluetoothScannerMinigame, startBluetoothScannerMinigame } from './bluetooth/bluetooth-scanner-minigame.js';

// Import the biometrics minigame
import { BiometricsMinigame, startBiometricsMinigame } from './biometrics/biometrics-minigame.js';

// Import the container minigame
import { ContainerMinigame, startContainerMinigame, returnToContainerAfterNotes, returnToConversationAfterNPCInventory } from './container/container-minigame.js';

// Import the phone chat minigame (Ink-based NPC conversations)
import { PhoneChatMinigame, returnToPhoneAfterNotes } from './phone-chat/phone-chat-minigame.js';

// Import the person chat minigame (In-person NPC conversations)
import { PersonChatMinigame } from './person-chat/person-chat-minigame.js?v=10';

// Import the PIN minigame
import { PinMinigame, startPinMinigame } from './pin/pin-minigame.js';

// Import the password minigame
import { PasswordMinigame } from './password/password-minigame.js';

// Import the text file minigame
import { TextFileMinigame, returnToTextFileAfterNotes } from './text-file/text-file-minigame.js';

// Import the title screen minigame
import { TitleScreenMinigame, startTitleScreenMinigame } from './title-screen/title-screen-minigame.js';

// Import the RFID minigame
import { RFIDMinigame, startRFIDMinigame, returnToConversationAfterRFID } from './rfid/rfid-minigame.js';

// Import the VM launcher minigame
import { VmLauncherMinigame } from './vm-launcher/vm-launcher-minigame.js';

// Import the flag station minigame
import { FlagStationMinigame } from './flag-station/flag-station-minigame.js?v=6';
import { SiemDashboardMinigame } from './siem/siem-dashboard-minigame.js';

// Import ransomware display minigame
import { RansomwareDisplayMinigame } from './ransomware-display/ransomware-display-minigame.js';

// Import the network segmentation map minigame
import { NetworkSegmentationMapMinigame, startNetworkSegmentationMapMinigame } from './network-segmentation-map/network-segmentation-map-minigame.js';

// Import the dual-auth panel minigame
import { DualAuthMinigame } from './dual-auth/dual-auth-minigame.js';

// Register minigames
MinigameFramework.registerScene('lockpicking', LockpickingMinigamePhaser); // Use Phaser version as default
MinigameFramework.registerScene('lockpicking-phaser', LockpickingMinigamePhaser); // Keep explicit phaser name
MinigameFramework.registerScene('dusting', DustingMinigame);
MinigameFramework.registerScene('notes', NotesMinigame);
MinigameFramework.registerScene('bluetooth-scanner', BluetoothScannerMinigame);
MinigameFramework.registerScene('biometrics', BiometricsMinigame);
MinigameFramework.registerScene('container', ContainerMinigame);
MinigameFramework.registerScene('phone-chat', PhoneChatMinigame);
MinigameFramework.registerScene('person-chat', PersonChatMinigame);
MinigameFramework.registerScene('pin', PinMinigame);
MinigameFramework.registerScene('password', PasswordMinigame);
MinigameFramework.registerScene('text-file', TextFileMinigame);
MinigameFramework.registerScene('title-screen', TitleScreenMinigame);
MinigameFramework.registerScene('rfid', RFIDMinigame);
MinigameFramework.registerScene('vm-launcher', VmLauncherMinigame);
MinigameFramework.registerScene('flag-station', FlagStationMinigame);
MinigameFramework.registerScene('ransomware-display', RansomwareDisplayMinigame);
MinigameFramework.registerScene('siem-dashboard', SiemDashboardMinigame);
MinigameFramework.registerScene('network-segmentation-map', NetworkSegmentationMapMinigame);
MinigameFramework.registerScene('dual-auth', DualAuthMinigame);

// Make minigame functions available globally
window.startNotesMinigame = startNotesMinigame;
window.showMissionBrief = showMissionBrief;
window.startBluetoothScannerMinigame = startBluetoothScannerMinigame;
window.startBiometricsMinigame = startBiometricsMinigame;
window.startContainerMinigame = startContainerMinigame;
window.returnToContainerAfterNotes = returnToContainerAfterNotes;
window.returnToConversationAfterNPCInventory = returnToConversationAfterNPCInventory;
window.returnToPhoneAfterNotes = returnToPhoneAfterNotes;
window.returnToTextFileAfterNotes = returnToTextFileAfterNotes;
window.startPinMinigame = startPinMinigame;
window.startTitleScreenMinigame = startTitleScreenMinigame;
window.startRFIDMinigame = startRFIDMinigame;
window.returnToConversationAfterRFID = returnToConversationAfterRFID;
window.startNetworkSegmentationMapMinigame = startNetworkSegmentationMapMinigame;
