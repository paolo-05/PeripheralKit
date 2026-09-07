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

## Firma e prima installazione

Xcode usa l'identità **PeripheralKit Local Development**, conservata nel portachiavi **login**. La stessa chiave firma Debug e Release: il requisito di identità dipende dal certificato e dal bundle ID, non dall'hash della singola build. Non rigenerare il certificato durante gli aggiornamenti.

Il primo passaggio dalla firma precedente richiede un'ultima autorizzazione in **Accessibilità** e **Monitoraggio input**. Le build successive mantengono l'identità; usa sempre `~/Applications/PeripheralKit.app` per l'installazione. Cambiare certificato, bundle ID o percorso può richiedere nuovi permessi. Il portachiavi login deve essere sbloccato durante la firma: un'eventuale richiesta riguarda la password del tuo account macOS, non una password generata dal progetto.

`Configuration/Local.xcconfig` seleziona il certificato. Su un altro Mac serve importare l'identità completa (certificato e chiave privata) o selezionare un proprio certificato Apple. Xcode interrompe la build se l'identità manca: non ripiega silenziosamente sulla firma ad hoc. Certificato e chiave privata non sono nel repository. La firma locale non sostituisce Developer ID/notarizzazione per distribuire pubblicamente l'app.

1. Chiudi le altre copie e usa **PeripheralKit Install → Run**.
2. In **Generali**, autorizza **Monitoraggio input** per gli RGB e **Accessibilità** per le azioni mouse. Se richiesto, riapri l'app.
3. Abilita **Rimappatura mouse** e, se desiderato, **Avvia al login**.

Le impostazioni RGB e mouse sono conservate in `~/Library/Application Support/PeripheralKit/settings.json`. Gli aggiornamenti non le sovrascrivono. Una configurazione corrotta viene segnalata senza sostituirla.

Per disinstallare: disabilita **Avvia al login**, esci dal menu e sposta l'app nel Cestino. La configurazione resta conservata.

## Cambio Space

In **Mouse → Prova cambio Space**, i due pulsanti inviano la stessa azione usata dalle mappature laterali. Servono almeno due Space e le scorciatoie Ctrl+←/→ abilitate in **Impostazioni di Sistema → Tastiera → Abbreviazioni → Mission Control**. Al primo o ultimo Space non si torna automaticamente all'estremo opposto.

Le scorciatoie vengono inviate al flusso HID, prima della gestione della sessione. Il permesso di invio viene controllato prima di pubblicare eventi; se manca, appare un errore. La diagnostica distingue «Scorciatoia inviata» dalla notifica di sistema `spaceChanged`: l'invio da solo non dimostra che macOS abbia cambiato desktop.

## Funzionalità di questa versione

- App nella barra menu, impostazioni native, stato permessi e diagnostica limitata.
- Pulsante 4 → Space precedente, pulsante 5 → Space successivo.
- Mission Control e scorciatoie personalizzate con codice tasto/modificatori.
- Cattura dei pulsanti aggiuntivi annullabile, con timeout di 15 secondi.
- Consumo/passaggio evento originale, regole disattivabili e interruttore globale.
- Inventario HID con aggiornamento ogni tre secondi.
- RGB diretto Drevo Tyrfing V2 (`0416:a0f8`) e Razer DeathAdder V2 (`1532:0084`).
- Stop sistema e schermi separati; ripristino con attesa e sette tentativi cancellabili per passaggio.

Le mappature sono **globali per tutti i mouse**: Quartz non espone l'identità USB affidabile del dispositivo sorgente. Per gli Spaces, abilita Ctrl+←/→ nelle abbreviazioni Mission Control di macOS; Mission Control usa Ctrl+↑.

Profili per applicazione, isolamento per dispositivo, editor generico e OpenRGB restano nella roadmap. L'app non registra il testo digitato e non dipende da servizi di rete o driver kernel.

## RGB e strumenti CLI

Sono preservati i report HID originali e i profili: static/rainbow/breathing/stream/radar/memory per la tastiera, spectrum/static/breathing per il mouse. Per cambiare colori ed effetti, chiudi l'app e modifica la sezione `rgb` del JSON; `config.example.json` documenta il formato RGB.

Il ripristino riguarda il **profilo configurato**, memorizzato prima dello stop, non un effetto impostato esternamente nel firmware. La selezione RGB è per modello. Dopo l'attesa configurata, ogni passaggio ritenta a intervalli 0, 250 ms, 500 ms, 1 s, 2 s, 4 s e 8 s. La Drevo riapre il collegamento HID e reinvia il profilo dopo ulteriori 2 e 5 secondi, anche quando la prima scrittura USB riesce. Il mouse conclude il proprio ripristino indipendentemente. Un nuovo stop cancella tutti i passaggi del risveglio precedente. Il protocollo non offre una verifica ottica: i log attestano l’invio USB, non che i LED siano effettivamente accesi.

Le scritture HID sono fuori dal thread UI. La notifica `NSWorkspace.willSleepNotification` non garantisce il completamento USB prima della sospensione: lo spegnimento resta best effort, senza trattenere il Mac con un'assertion.

Il binario del bundle offre i comandi `devices`, `check`, `authorize`, `on`, `off` e `test`. I comandi RGB usano le impostazioni attuali di PeripheralKit; `--config` accetta un profilo RGB esplicito. La modalità sicura si attiva aggiungendo `--safe-mode` in **Edit Scheme → Run → Arguments**; sospende rimappatura e cattura senza modificare le preferenze.

## Architettura e verifiche

Il target XCTest è senza app host: compila gli stessi file di produzione escludendo gli entry point, senza avviare l'app né accedere alla configurazione reale. I test raccolgono gli eventi Quartz in memoria e simulano HID. Le prove fisiche di pulsanti, sleep/wake e login restano separate.

- [Architettura e API](ARCHITECTURE.md)
- [Perimetro MVP](MVP.md)
- [Verifiche eseguite](VERIFICATION.md)
- [Apple: schemi Xcode](https://developer.apple.com/documentation/xcode/customizing-the-build-schemes-for-a-project)
- [Apple: firma del codice](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html)

I pacchetti originali sono preservati. Riferimenti storici: [RazerControl, MIT](https://github.com/pol-cova/RazerControl), [OpenRazer](https://github.com/openrazer/openrazer), [dtv2](https://github.com/cobacdavid/dtv2), [DrevoTyrfing](https://github.com/dennisblokland/DrevoTyrfing) e [HIDAPI](https://github.com/libusb/hidapi). Le attribuzioni dei riferimenti originali vanno completate prima di una distribuzione pubblica.

## Luci scrivania HappyLighting (BLE)

In **Impostazioni → Luci scrivania**, cerca le strisce Bluetooth e seleziona il tuo controller. La ricerca dura al massimo 15 secondi e mostra nomi Triones, HappyLighting, ELK o LED; puoi anche inserire l’UUID macOS del vecchio script nella configurazione manuale. La selezione non invia comandi.

Scegli un colore e premi **Accendi / applica colore**, oppure **Spegni**. Dopo la selezione, accensione e spegnimento sono disponibili anche nella barra menu. Dispositivo e colore sono salvati nella sezione opzionale `deskLight` della configurazione; i file precedenti continuano a caricarsi.

Il collegamento usa CoreBluetooth direttamente, senza SwiftBar, launcher o Python. macOS richiede il permesso Bluetooth al primo utilizzo. In caso di timeout, verifica alimentazione e distanza e chiudi l’app HappyLighting sul telefono. Ogni operazione rilascia la connessione al termine; gli errori sono visibili nella pagina e nel menu.

Questa versione controlla manualmente una striscia e non la include nello stop/risveglio USB. “Comando inviato” indica la conferma di scrittura GATT, non una lettura dello stato fisico dei LED. Il protocollo riproduce `RGB-remote/LED_source.py`: power `CC 23/24 33`, colore `56 R G B 19 F0 AA`. Non tutti i controller venduti come HappyLighting usano questo protocollo. Il controller deve esporre una sola caratteristica scrivibile sia con sia senza risposta nei servizi non GAP/GATT, come nello script di riferimento; in caso di ambiguità l’app non scrive.
