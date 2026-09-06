# PeripheralKit

Utility nativa macOS 14+ per rimappare i pulsanti aggiuntivi del mouse e gestire gli RGB di Drevo Tyrfing V2 e Razer DeathAdder V2 durante stop e risveglio.

## Sviluppo, test e installazione in Xcode

Apri **PeripheralKit.xcodeproj**, scegli **My Mac** come destinazione e usa uno dei due schemi condivisi:

| Schema | Comando Xcode | Risultato |
| --- | --- | --- |
| PeripheralKit | ⌘B, Build | Compila l'app Debug in DerivedData |
| PeripheralKit | ⌘R, Run | Avvia l'app di sviluppo con le impostazioni aperte |
| PeripheralKit | ⌘U, Test | Esegue i test XCTest, senza avviare automazioni o inviare input |
| PeripheralKit | Product → Archive | Crea l'archivio Release in Organizer |
| PeripheralKit Install | ⌘B, Build | Compila Release e installa in `~/Applications/PeripheralKit.app` |
| PeripheralKit Install | ⌘R, Run | Installa e avvia la copia in Applicazioni, senza debugger |

**Chiudi le altre copie di PeripheralKit prima di installare o avviare uno schema diverso.** L'app impedisce istanze simultanee; una copia di sviluppo già aperta potrebbe impedire l'avvio di quella installata.

Il target di installazione dipende dall'app e usa una fase nativa **Copy Files**, eseguita dopo la firma. Non contiene Run Script, pre/post-action shell né comandi di firma personalizzati. Run usa un piccolo launcher Swift compilato da Xcode, che apre la copia installata tramite NSWorkspace. Il launcher legge dal bundle la destinazione risolta da Xcode; gli schemi non contengono percorsi utente assoluti né richiedono espansione shell. La cartella di destinazione è definita in `Configuration/Local.xcconfig`. Il prodotto compilato resta in DerivedData: pulire la build non cancella l'app installata. Ricostruire il target di installazione aggiorna l'app; i dati in Application Support restano separati.

Il progetto Xcode è il flusso principale. `Package.swift` rimane soltanto per compatibilità con la CLI e con gli strumenti SwiftPM; non serve per build, test, installazione o archiviazione in Xcode.

## Firma e vecchia richiesta di password

La firma predefinita Xcode è **Sign to Run Locally** (`CODE_SIGN_IDENTITY = -`). Non usa chiavi private e non apre il portachiavi `MKSleepRGB`. Non occorre selezionare un Team per eseguire questa copia locale.

Il vecchio installer creava un portachiavi dedicato con una password casuale, distinta dalla password dell'account macOS, e la salvava in `~/Library/Application Support/MKSleepRGB/signing/keychain-password`. La richiesta di password di `codesign` riguardava quel portachiavi. **Annulla la vecchia richiesta e usa gli schemi Xcode.** Il portachiavi e i suoi file non vengono modificati né eliminati dal nuovo flusso.

La firma locale è ad hoc: macOS può richiedere di concedere di nuovo i permessi dopo una ricompilazione. Per una firma persistente o per distribuire l'app, configura il tuo Team e il certificato appropriato in **Signing & Capabilities**. Un archivio locale non è automaticamente notarizzato o pronto per la distribuzione pubblica.

## Prima installazione e migrazione RGB

1. Chiudi le copie di sviluppo o anteprima e usa **PeripheralKit Install → Run**.
2. In **Generali**, autorizza **Monitoraggio input** per il controllo HID. Se macOS lo richiede, chiudi e riapri l'app installata.
3. Premi **Migra da MKSleepRGB**. La migrazione crea un backup verificato del LaunchAgent, arresta il vecchio servizio e ne archivia la registrazione; il codice è Swift nativo e invoca `launchctl` direttamente, senza shell.
4. Abilita **Avvia al login** se desiderato. Lo stato reale di `SMAppService`, compresa l'eventuale approvazione richiesta in Impostazioni, appare in Generali.
5. Per le mappature, autorizza **Accessibilità** e abilita **Rimappatura mouse**.

La migrazione è disponibile soltanto dalla copia installata in Applicazioni, dopo il permesso HID e con una configurazione valida. Fino ad allora il vecchio daemon resta responsabile degli RGB. Il JSON precedente e il portachiavi restano intatti. Se l'arresto fallisce, il LaunchAgent originale viene conservato.

Le impostazioni sono in `~/Library/Application Support/PeripheralKit/settings.json`. Al primo avvio, se il nuovo JSON non esiste, viene importato quello di `~/Library/Application Support/MKSleepRGB/config.json`. I backup di migrazione si trovano nella sottocartella `migration`. Una configurazione corrotta viene segnalata senza sovrascriverla.

Per disinstallare: disabilita **Avvia al login**, esci dal menu e sposta l'app nel Cestino. La configurazione resta conservata. Nessuno script è necessario.

## Funzionalità di questa versione

- App nella barra menu, impostazioni native, stato permessi e diagnostica limitata.
- Pulsante 4 → Space precedente, pulsante 5 → Space successivo.
- Mission Control e scorciatoie personalizzate con codice tasto/modificatori.
- Cattura dei pulsanti aggiuntivi annullabile, con timeout di 15 secondi.
- Consumo/passaggio evento originale, regole disattivabili e interruttore globale.
- Inventario HID con aggiornamento ogni tre secondi.
- RGB diretto Drevo Tyrfing V2 (`0416:a0f8`) e Razer DeathAdder V2 (`1532:0084`).
- Stop sistema e schermi separati; ripristino con attesa e cinque tentativi cancellabili.

Le mappature sono **globali per tutti i mouse**: Quartz non espone l'identità USB affidabile del dispositivo sorgente. Per gli Spaces, abilita Ctrl+←/→ nelle abbreviazioni Mission Control di macOS; Mission Control usa Ctrl+↑.

Profili per applicazione, isolamento per dispositivo, editor generico e OpenRGB restano nella roadmap. L'app non registra il testo digitato e non dipende da servizi di rete o driver kernel.

## RGB e compatibilità CLI

Sono preservati i report HID originali e i profili: static/rainbow/breathing/stream/radar/memory per la tastiera, spectrum/static/breathing per il mouse. Per cambiare colori ed effetti, chiudi l'app e modifica la sezione `rgb` del JSON; `config.example.json` documenta il formato RGB.

Il ripristino riguarda il **profilo configurato**, memorizzato prima dello stop, non un effetto impostato esternamente nel firmware. La selezione RGB è per modello. Dopo l'attesa configurata, il ripristino ritenta a intervalli 0, 250 ms, 500 ms, 1 s e 2 s solo sugli adapter falliti. Un nuovo stop cancella il ripristino precedente.

Le scritture HID sono fuori dal thread UI. La notifica `NSWorkspace.willSleepNotification` non garantisce il completamento USB prima della sospensione: lo spegnimento resta best effort, senza trattenere il Mac con un'assertion.

Il binario del bundle conserva i comandi `devices`, `check`, `authorize`, `on`, `off`, `test` e `daemon`, con `--config` per il vecchio JSON. Non eseguire il daemon CLI insieme all'app installata. La modalità sicura si attiva aggiungendo `--safe-mode` in **Edit Scheme → Run → Arguments**; sospende rimappatura e cattura senza modificare le preferenze.

## Architettura e verifiche

Il target XCTest è senza app host: compila gli stessi file di produzione escludendo gli entry point, senza avviare l'app né accedere alla configurazione reale. I test raccolgono gli eventi Quartz in memoria e simulano HID e launchctl. Le prove fisiche di pulsanti, sleep/wake e login restano separate.

- [Architettura e API](ARCHITECTURE.md)
- [Perimetro MVP](MVP.md)
- [Verifiche eseguite](VERIFICATION.md)
- [Apple: schemi Xcode](https://developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project)
- [Apple: firma del codice](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html)

I pacchetti originali sono preservati. Riferimenti storici: [RazerControl, MIT](https://github.com/pol-cova/RazerControl), [OpenRazer](https://github.com/openrazer/openrazer), [dtv2](https://github.com/cobacdavid/dtv2), [DrevoTyrfing](https://github.com/dennisblokland/DrevoTyrfing) e [HIDAPI](https://github.com/libusb/hidapi). Le attribuzioni dei riferimenti originali vanno completate prima di una distribuzione pubblica.
