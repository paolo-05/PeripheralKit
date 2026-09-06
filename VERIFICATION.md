# Verifiche del 6 settembre 2026

## Automatiche

- Baseline MKSleepRGB: 6 test superati prima della ristrutturazione.
- Milestone 1: build SwiftPM e Xcode Debug riuscite; 6 regressioni superate.
- Milestone 2 e integrazione RGB: 25 test superati, nessun errore.
- Build release tramite scripts/build.sh: bundle .app prodotto e firma verificata.
- Xcode Debug sul progetto aggiornato: riuscito.
- Sintassi degli script zsh, plist e git diff --check: validi.

Il sandbox del runner inizialmente impediva ai due test Quartz di accedere al WindowServer. Eseguiti fuori da quel sandbox, tutti e 25 passano. I test non pubblicano input. Il build Xcode nel sandbox emette diagnostica dei servizi Simulator non disponibili e delle cache utente non scrivibili, ma il target macOS compila; nessun warning del compilatore Swift nel build finale.

## Interfaccia e inventario reali

Avviato il bundle .app e verificata l'interfaccia nativa via accessibility tree e screenshot:

- finestra preferenze con sidebar e pagine Generali/Mouse/Dispositivi;
- pulsante 4 → Space precedente e pulsante 5 → Space successivo;
- controlli consumo evento, attivazione e registrazione disabilitata quando manca Accessibilità;
- messaggio esplicito che il servizio RGB precedente gestisce ancora le luci;
- inventario rileva Drevo keyboard 0416:a0f8 e Razer DeathAdder V2 1532:0084, oltre ai dispositivi Apple;
- permessi mancanti mostrati senza richieste automatiche.

## Da verificare con l'utente

- Autorizzazioni TCC del bundle installato e mantenimento dopo aggiornamento firmato.
- Click fisico sui due pulsanti DeathAdder e cambio effettivo di Space da Safari/Finder.
- Consumo di Indietro/Avanti nelle app e cattura fisica.
- Stop/wake reale del Mac, display sleep e re-enumerazione lenta delle periferiche.
- Installazione/migrazione e avvio al successivo login.

Non è stato sospeso il Mac né inviato input sintetico globale durante i test. Il vecchio servizio RGB è conservato fino alla migrazione avviata dall'utente nell'app installata.

## Flusso Xcode nativo (aggiornamento)

- Rimossi build.sh, install.sh, uninstall.sh e la configurazione del certificato dedicato.
- `xcodebuild test`, schema PeripheralKit, destinazione My Mac: 31 test passati, inclusi quattro test di migrazione con servizio simulato e due regressioni per gli argomenti di avvio Xcode/Cocoa.
- Schema PeripheralKit Install: Copy Files verificato prima in una cartella temporanea e poi in `~/Applications`.
- App installata come binario universale arm64/x86_64, firma Xcode «Sign to Run Locally», verificata con codesign.
- Nessuna richiesta al portachiavi MKSleepRGB durante build e installazione.
- La migrazione reale del vecchio servizio e le autorizzazioni TCC restano azioni dell'utente nell'app.

- Verifica nella UI di Xcode: schema PeripheralKit Install, ⌘R, launcher terminato con codice 0; processo avviato da `~/Applications/PeripheralKit.app` con `--settings`.
- Finestra installata verificata: sidebar completa, richiesta dei permessi e migrazione disabilitata fino a Monitoraggio input.
- Archive Release aggiornato riuscito.
