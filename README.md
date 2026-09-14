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

In Mouse, ogni assegnazione può essere limitata a un’app con **Scegli app…**. Le regole dell’app attiva hanno precedenza sulle regole globali; a parità viene usata la prima. **Aggiungi assegnazione** permette di configurare lo stesso pulsante per app diverse. Isolamento per dispositivo, editor generico e OpenRGB restano nella roadmap. L'app non registra il testo digitato e non dipende da servizi di rete o driver kernel.

## RGB e strumenti CLI

Sono preservati i report HID originali e i profili: static/rainbow/breathing/stream/radar/memory per la tastiera, spectrum/static/breathing per il mouse. In **RGB e stop → Illuminazione**, seleziona tastiera o mouse. L’editor mostra un’anteprima indicativa della periferica, effetti, palette e campo HEX; la tastiera offre anche luminosità e parametri degli effetti animati. Le modifiche restano in anteprima: **Salva e applica** salva e invia soltanto il profilo della periferica selezionata; **Annulla modifiche** torna al profilo salvato. I due dispositivi mantengono bozze separate mentre rimani nella pagina; uscire dalla pagina scarta le modifiche non salvate. I valori HEX non validi bloccano l’applicazione.

L’opzione **Includi nello stop e nel ripristino** riguarda l’automazione: il pulsante manuale funziona anche per una periferica esclusa. La scheda **Stop e risveglio** contiene le opzioni di alimentazione condivise. L’anteprima non legge i LED e non è un editor per singolo tasto. Sul Razer, **Configura logo e rotella separatamente** abilita effetti, colori e gradienti indipendenti per le due zone. Disattivandolo, entrambe seguono il profilo della rotella. `config.example.json` continua a documentare il formato RGB.

Per il mouse, **Ciclo colori → Gradiente personalizzato** permette da 2 a 8 colori ordinati, aggiunta/rimozione, riordino, selezione palette/HEX e durata totale da 2 a 120 secondi. L’ultimo colore sfuma di nuovo nel primo. Questo ciclo usa invii periodici di colore fisso da PeripheralKit, non una palette caricata nel comando Spectrum del firmware: richiede l’app aperta e riprende all’avvio quando è il profilo salvato. Stop, nuovo profilo e uscita interrompono i frame precedenti; il ripristino riavvia il ciclo se abilitato. Tre errori consecutivi interrompono l’animazione e vengono segnalati in Diagnostica. **Spectrum completo** resta il ciclo autonomo del firmware.

**Anteprima sulle periferiche** invia temporaneamente le modifiche valide, con un’attesa di 250 ms dopo l’ultima modifica. Annullare, cambiare dispositivo/sezione o chiudere l’editor ripristina il profilo salvato. Salva e applica rende definitive le modifiche. Lo stop interrompe l’anteprima.

**Scene** salva i profili USB e l’ultimo stato/colore richiesto alla striscia. Le scene sono richiamabili dalla stessa pagina e dalla barra menu; indirizzano entrambe le periferiche USB e la striscia attualmente selezionata, se la scena contiene uno stato noto. Gli errori dei singoli dispositivi restano visibili, senza bloccare gli altri.

**Ripristina quando colleghi le periferiche**, attivo per impostazione predefinita in Stop e risveglio, recupera il profilo salvato all’avvio e alla riconnessione USB. Usa l’inventario aggiornato ogni tre secondi e tentativi limitati; durante lo stop non riaccende i dispositivi. Include il gradiente software anche dopo che gli errori di scollegamento lo hanno interrotto.

La CLI `on` applica solo il primo colore di un gradiente personalizzato; il ciclo continuo richiede l’app nella barra menu.


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

L’opzione **Spegni durante lo stop** include la striscia nelle automazioni. Segue le scelte stop sistema/schermi e ripristino della pagina **RGB e stop**, indipendentemente dall’interruttore RGB USB. È disattivata nelle configurazioni precedenti. Premi **Accendi / applica colore** o **Spegni** per memorizzare lo stato richiesto: l’app non presume che una striscia appena selezionata sia accesa e non riaccende una striscia spenta manualmente. Stato richiesto e ultimo colore applicato sono persistenti; le modifiche fatte dal telefono non sono rilevabili.

Al risveglio la striscia viene riconnessa dopo l’attesa configurata (minimo un secondo), con al massimo tre tentativi da 15 secondi e due secondi fra i tentativi. Un nuovo stop, un comando manuale, la disattivazione dell’automazione o la rimozione del controller cancellano il ripristino precedente. Il Bluetooth non rallenta i ripristini USB. Lo spegnimento prima dello stop completo è best effort: macOS può sospendere il Bluetooth prima che connessione e scrittura siano completate. Le conferme e gli errori BLE sono conservati nel log unificato.

“Comando inviato” indica la conferma di scrittura GATT, non una lettura dello stato fisico dei LED. Il protocollo riproduce `RGB-remote/LED_source.py`: power `CC 23/24 33`, colore `56 R G B 19 F0 AA`. Non tutti i controller venduti come HappyLighting usano questo protocollo. Il controller deve esporre una sola caratteristica scrivibile sia con sia senza risposta nei servizi non GAP/GATT, come nello script di riferimento; in caso di ambiguità l’app non scrive.
