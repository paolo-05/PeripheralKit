# Verifiche di PeripheralKit — 6 settembre 2026

## Scene, zone e riconnessione, 13 settembre 2026

- Conferma fisica dell’utente: gradiente Razer a cinque colori regolare su entrambe le zone; stop completo e risveglio ripristinano tastiera, mouse, striscia e ciclo software.
- Nuova Release installata con permessi conservati. Dock scollegato e ricollegato: profili USB e gradiente recuperati automaticamente, pulsanti laterali e cambio Space confermati dall’utente.
- Anteprima hardware: logo rosso fisso e rotella con gradiente confermati dall’utente. Il JSON mantiene il profilo originale; Annulla ripristina il gradiente su entrambe le zone, confermato fisicamente.
- Scena “Scrivania” creata dai profili salvati; applicazione UI riuscita, log USB per Drevo/Razer e conferma Bluetooth del controller. Questa scena viene conservata come configurazione iniziale utile.
- Selettore nativo app verificato: assegnazione associata ad Automator, poi riportata a Tutte le app. Regole originali conservate. Precedenza e fallback verificati con XCTest, senza generare input sintetici verso altre app.
- Test automatici includono riconnessione con errori transitori, assenza di riaccensione durante stop, compatibilità scene/zone e interpolazione per zona. **61 test XCTest superati**, nessun fallimento o test saltato. Release finale firmata e installata; permessi conservati.
- Non eseguiti logout/login reale o test prolungati di ore.

## Editor per dispositivo e gradiente, 9 settembre 2026

- Editor riorganizzato con selezione tastiera/mouse, anteprima schematica, lista effetti, palette/HEX e slider. Illuminazione separata da Stop e risveglio; footer persistente con Salva e applica e Annulla modifiche.
- Bozze separate verificate: palette blu in anteprima mentre il JSON conserva il fucsia salvato; HEX non valido disabilita Salva e applica; annullamento ripristina il valore precedente. Permessi conservati dopo installazione della Release firmata.
- Applicazione mirata: test di invio alla sola periferica scelta, anche esclusa dall’automazione, e conservazione del ripristino pendente dell’altra periferica.
- Aggiunto Spectrum completo o Gradiente personalizzato sul mouse: 2–8 colori, riordino, HEX, durata 2–120 secondi, anteprima animata e interpolazione ciclica ultimo→primo. Il gradiente è software e richiede l’app aperta; il comando firmware Spectrum resta invariato senza palette.
- **54 test XCTest superati**, inclusi interpolazione e chiusura del ciclo, validazione/compatibilità/persistenza, limite errori USB, cancellazione per stop e sostituzione con colore fisso.
- Interfaccia del gradiente verificata nell’app installata: aggiunta e riordino dei colori, blocco HEX non valido e annullamento. Nessuna palette di prova salvata; conservato Spectrum completo.
- Verifica hardware finale non eseguita: la CLI rileva zero interfacce HID sia Drevo sia Razer. La progressione fisica dei colori e lo stop/risveglio con gradiente software restano da confermare quando il mouse è collegato.

## Editor RGB del 9 settembre 2026

- Aggiunti selettori nativi per tutti gli effetti Drevo/Razer già supportati, colori condizionali all’effetto, luminosità Drevo e parametri animati in un gruppo espandibile. Le impostazioni si salvano automaticamente; Applica profili invia alle periferiche incluse.
- 47 test XCTest superati. Tre nuove regressioni verificano precedenza dell’applicazione manuale sui reinvii del wake, rifiuto durante lo stop e risultati parziali con esclusione delle periferiche disabilitate.
- Build Release e installazione tramite schema nativo riuscite; firma verificata. Accessibilità e Monitoraggio input restano autorizzati.
- Pagina RGB e stop verificata visivamente nell’app installata. Cambio mouse da Ciclo colori a Colore fisso mostra il controllo colore; Applica profili riporta invio riuscito a Drevo e Razer. Ripristinato Ciclo colori e riapplicati con successo i profili originali (Drevo statico fucsia, Razer spectrum).
- La verifica hardware attesta il successo delle scritture USB dal nuovo pulsante. Non è stata richiesta una nuova conferma ottica dell’utente né provato fisicamente ogni effetto.

## Sessione hardware dell’8 settembre 2026

- Baseline XCTest Xcode: 34 test superati, nessun fallimento. Il runner richiede esecuzione fuori dal sandbox; il primo tentativo limitato non costituisce un fallimento dell’app.
- App installata: Accessibilità e Monitoraggio input autorizzati; login registrato come attivo (non ancora provato con logout/login in questa sessione).
- HID reale: Drevo presente con due interfacce, Razer con quattro. Interfaccia RGB Drevo accessibile, firmware Razer 2.0.
- Ciclo CLI spento/acceso di due secondi riuscito su entrambe le periferiche e confermato visivamente dall’utente.
- Striscia Triones selezionata: spegnimento e ritorno al fucsia confermati dall’utente. Un tentativo di riconnessione ha mostrato timeout; il successivo ha ottenuto conferma GATT. Non si considera dimostrata l’assenza di errori transitori BLE.
- Stop completo alle 14:00:48, wake alle 14:01:22: utente conferma ripristino di tastiera e mouse, striscia rimasta accesa sulla versione precedente. Log: eventi schermo ravvicinati, Razer ripristinato alle 14:01:27; Drevo al settimo tentativo alle 14:01:43, reinvii completati alle 14:01:50.
- Scollegamento/ricollegamento dock e cambio Space con entrambi i pulsanti: rilevamento e funzionamento confermati dall’utente.
- Striscia senza alimentazione: timeout visibile e comandi riabilitati, nessun blocco UI. Rialimentata, connessione e colore nuovamente confermati da GATT.
- Nuova automazione BLE: 44 test XCTest superati, inclusi dieci test per compatibilità JSON, persistenza e validazione dello stato richiesto, stato spento/sconosciuto, sovrapposizione schermo/sistema, limite tentativi, cancellazione manuale, disattivazione/rimozione, nuovo stop e ripristino disabilitato anche durante una riconnessione. Release firmata compilata e installata con identico requisito designato; entrambi i permessi conservati.
- Automazione BLE attivata tramite UI e stato acceso memorizzato. Stop completo alle 14:18:07, spegnimento GATT confermato alle 14:18:08; sistema sveglio alle 14:18:22, schermi alle 14:18:23, striscia ripristinata alle 14:18:26. Utente conferma tutte le luci spente durante lo stop e ripristinate al risveglio. USB senza errori in questo ciclo, reinvii Drevo terminati alle 14:18:31. Precedente coppia stop/wake ravvicinata alle 14:17:56 recuperata senza comandi BLE obsoleti riportati nei log.
- Spegnimento manuale striscia alle 14:19:03; stop 14:19:54 e wake 14:20:12: nessuna riaccensione BLE nei log e utente conferma striscia rimasta spenta, USB ripristinati. Drevo recuperata al terzo tentativo, sequenza conclusa alle 14:20:23.
- Release finale reinstallata tramite schema nativo: firma verificata, impostazioni BLE persistenti (`requestedOn: false` dopo lo spegnimento manuale) e nessun invio BLE all’avvio. Ricerca reale trova lo stesso controller Triones; annullamento termina la ricerca e riabilita i controlli. Colore riapplicato con successo prima della prova schermi.
- Soli schermi: `displaysDidSleep` alle 14:22:29, spegnimento BLE confermato alle 14:22:30; `displaysDidWake` alle 14:23:11, senza stop sistema. Primo tentativo BLE terminato in timeout alle 14:23:18, ripetizione automatica dopo due secondi e successo alle 14:23:22. Utente conferma tutte le luci spente e ripristinate. Anche il recupero da errore BLE transitorio è quindi verificato fisicamente. Drevo recuperata al terzo tentativo, Razer al primo. App lasciata in esecuzione con automazione BLE attiva e colore originale fucsia ripristinato.

### Limiti delle verifiche dell’8 settembre

Logout/login reale, revoca del permesso Bluetooth e indisponibilità BLE durante un intero ripristino automatico non provati fisicamente. Avvio al login verificato come registrazione attiva; tentativi limitati e cancellazioni del ripristino BLE coperti dai test simulati. La conferma fisica di uno stop riuscito non garantisce che macOS conceda sempre il tempo necessario alla scrittura Bluetooth.

## Funzionalità confermate

- L'utente conferma il corretto funzionamento della gestione RGB attuale.
- Il servizio precedente non è caricato e la sua registrazione è assente.
- Il JSON PeripheralKit contiene i profili RGB e le regole mouse attivi; viene conservato durante aggiornamento e pulizia.
- Le scorciatoie macOS Ctrl+←/→ risultano abilitate e corrispondono alle azioni configurate.

## Correzione cambio Space

- Invio degli eventi spostato al livello HID, prima dell'elaborazione delle scorciatoie di sessione.
- Controllo del permesso di pubblicare eventi; errore esplicito se macOS lo nega.
- Prova manuale delle due direzioni nella pagina Mouse e diagnostica distinta fra invio e notifica spaceChanged.
- Regressioni per destinazione HID, coppie di eventi, modificatori, rifiuto dell'invio e conservazione della configurazione RGB.
- I test Quartz raccolgono gli eventi in memoria, senza pubblicare input globale.

## Flusso Xcode

Schemi condivisi per sviluppo/test/Archive e installazione con Copy Files e launcher Swift. Firma locale senza portachiavi dedicato; nessuno script shell nel lifecycle. Le verifiche precedenti di build, installazione e ⌘R sono riuscite.

## Verifiche fisiche

Il funzionamento RGB è confermato dall'utente. Restano da confermare il cambio Space con i pulsanti fisici dopo questa correzione, il mantenimento dei permessi dopo aggiornamento e l'avvio al login. La prova deve avvenire su un desktop con uno Space adiacente nella direzione scelta.

## Risultato della build aggiornata

- Xcode XCTest: 29 test superati, 0 falliti (rimossi quattro test della migrazione completata, aggiunte due regressioni dell'invio).
- Build Release, installazione tramite PeripheralKit Install e Archive riusciti; firma del bundle verificata con codesign.
- UI installata verificata: nessun banner di migrazione, controlli Prova cambio Space presenti, configurazione RGB e mappature preservate.
- L’utente ha riabilitato Accessibilità e Monitoraggio input. La prima prova UI del solo cambio di destinazione HID non ha confermato spaceChanged: non è stata dichiarata risolta. Nessun permesso è stato concesso automaticamente.
- Nessun riferimento al vecchio nome nei file versionati attuali. Componenti dismessi spostati nel Cestino; impostazioni correnti preservate.

- Completata anche la sequenza esplicita dei modificatori richiesta dal SDK, con test del rilascio in ordine inverso. Suite Xcode nuovamente superata: 29 test.
- La conferma fisica della sequenza completa rimane da ottenere dopo l’aggiornamento; la firma locale può richiedere un nuovo consenso macOS.

## Aggiornamento del 7 settembre: firma e tastiera

- Creato, con consenso esplicito dell’utente, un certificato locale persistente nel portachiavi login. Attendibilità limitata alla firma del codice; nessuna chiave nel repository.
- Debug e Release verificati con codesign: CDHash differenti, identico requisito designato (bundle ID + certificato leaf).
- Tutti i target Xcode usano la medesima identità; eliminato il ripiego automatico sulla firma ad hoc.
- 32 test XCTest superati: incluso il ripristino dopo cinque errori iniziali, reinvii Drevo indipendenti dal mouse e annullamento dei reinvii dopo un nuovo sleep.
- La tastiera riapre HID e reinvia il profilo due volte dopo il primo successo; ogni passaggio ha un massimo di sette tentativi. Lo snapshot resta fino al termine della sequenza.
- I log di alimentazione e ripristino RGB sono persistenti nel log unificato per la diagnosi dopo un riavvio dell’app.
- L’utente conferma la riaccensione fisica della tastiera dopo la prova sleep/wake del 7 settembre. Il successo USB, da solo, non costituisce una lettura dello stato dei LED.

- Verifica reale dei permessi: l’utente ha autorizzato la prima build firmata (Debug). Sostituita con Release, che ha CDHash diverso, e riaperta: Accessibilità e Monitoraggio input ancora autorizzati, rimappatura attiva, nessun nuovo consenso richiesto.
- Build Release, Archive e installazione finali completati con il certificato locale; firma verificata.

- Prova hardware reale alle 21:13–21:14: primo invio Drevo alle 21:13:59, quattro errori IOKit 0xe00002e2 durante il secondo passaggio, recupero alle 21:14:05 e ultimo reinvio alle 21:14:10. Mouse ripristinato indipendentemente alle 21:13:59. L’utente ha confermato «La tastiera si riaccende».

## HappyLighting BLE, 7 settembre

- Aggiunti controllo nativo CoreBluetooth, ricerca e selezione della striscia, colore persistente, accensione/spegnimento e azioni nella barra menu.
- Suite SwiftPM con toolchain Xcode: **34 test superati**. Nuove verifiche dei pacchetti contro lo script Python funzionante e della compatibilità/validazione della configurazione opzionale.
- Build Debug del target Xcode PeripheralKit firmata con l’identità locale: riuscita, output in `/tmp/peripheralkit-happylighting-xcode/Debug/PeripheralKit.app`.
- La prima esecuzione dei test nel sandbox non poteva creare eventi Quartz per tre test preesistenti; rieseguita fuori dal sandbox, tutta la suite passa.
- Nessuna prova BLE fisica né verifica visuale della nuova pagina effettuata. Da verificare: consenso Bluetooth, ricerca/selezione del controller, accensione, colore, spegnimento, timeout con striscia non alimentata. L’app installata non è stata sostituita.
