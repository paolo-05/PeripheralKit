# PeripheralKit

Utility nativa per macOS 14+: pulsanti del mouse, scorciatoie e automazioni RGB per le periferiche. Evoluzione di MKSleepRGB, con app nella barra dei menu e preferenze SwiftUI. Nessuna dipendenza esterna o servizio di rete.

## Questa versione

- Pulsante 4 → Space precedente, pulsante 5 → Space successivo.
- Mission Control e scorciatoie personalizzate tramite codice tasto e modificatori.
- Cattura di un pulsante extra, annullabile e con timeout di 15 secondi.
- Consumo o passaggio dell'evento originale, regole disattivabili e interruttore globale.
- Inventario HID aggiornato ogni tre secondi, permessi e diagnostica.
- RGB diretto Drevo Tyrfing V2 (`0416:a0f8`) e Razer DeathAdder V2 (`1532:0084`).
- Stop sistema e schermi separati; ripristino con attesa e cinque tentativi cancellabili.
- Avvio al login con `SMAppService`.

Le mappature sono **globali per tutti i mouse**. Quartz non espone un'identità USB affidabile del dispositivo sorgente; l'inventario HID non viene usato per attribuire arbitrariamente i click. Il primo incremento implementa la shell e l'input del brief, mantenendo il controllo RGB originale. Profili per applicazione, isolamento per dispositivo, editor generico e OpenRGB restano nella roadmap.

## Build e avvio

```sh
./scripts/build.sh
open dist/PeripheralKit.app
```

Il bundle è generato in `dist/PeripheralKit.app`. Si può anche aprire `PeripheralKit.xcodeproj` in Xcode e avviare il target PeripheralKit. Swift Package Manager resta disponibile per CLI e test. Non serve XcodeGen.

Al primo avvio l'app mostra le preferenze; in seguito resta nella barra menu. **La rimappatura è inizialmente disabilitata.** Autorizza Accessibilità e attivala quando vuoi usare le assegnazioni. Il permesso Monitoraggio input serve all'accesso HID RGB. Le richieste partono soltanto dai pulsanti dedicati, non ripetutamente all'avvio.

Per gli Spaces, abilita Ctrl+←/→ nelle abbreviazioni Mission Control di macOS. L'azione Mission Control usa Ctrl+↑. Le abbreviazioni possono essere personalizzate nelle assegnazioni.

## Installazione e migrazione

```sh
./scripts/install.sh
```

Lo script compila e verifica la firma prima della migrazione, installa `~/Applications/PeripheralKit.app`, arresta il vecchio LaunchAgent e ne sposta il plist in `~/Library/Application Support/PeripheralKit/migration/`. Conserva l'app precedente, il JSON RGB e l'identità di firma locale. Un'eventuale versione precedente di PeripheralKit viene archiviata nella stessa cartella migration. L'app registra poi l'avvio al login: lo stato effettivo, compresa l'eventuale approvazione richiesta da macOS, appare in Generali.

L'app importa `~/Library/Application Support/MKSleepRGB/config.json` soltanto se non esiste ancora `~/Library/Application Support/PeripheralKit/settings.json`. Il vecchio JSON non viene modificato. Una configurazione corrotta viene segnalata e non sovrascritta; correggila e riapri l'app.

**Durante una semplice anteprima del bundle, se il vecchio plist è ancora installato, PeripheralKit sospende il proprio controllo RGB.** MKSleepRGB continua così a gestire le luci fino alla migrazione.

L'installer riusa l'identità locale di firma MKSleepRGB/PeripheralKit se già disponibile. Puoi specificarne una con `CODESIGN_IDENTITY`. Non crea nuovi certificati né modifica la lista dei portachiavi. Senza identità disponibile usa la firma ad hoc, che può richiedere di riconcedere i permessi dopo una ricompilazione. Il nuovo bundle ID `com.local.peripheralkit` richiede comunque autorizzazioni proprie: quelle del vecchio daemon non vengono trasferite.

Per disabilitare l'avvio al login e chiudere l'app conservandone i dati:

```sh
./scripts/uninstall.sh
```

## RGB: comportamento preservato e limiti

Il controllo usa gli stessi report HID già presenti nel daemon, isolati dietro `RGBDeviceAdapter`. La tastiera continua a supportare static, rainbow, breathing, stream, radar e memory; il mouse spectrum, static e breathing. Per modificare colori/effetti chiudi l'app e modifica la sezione `rgb` di `settings.json`; il formato interno è quello di `config.example.json`.

Il ripristino riguarda il **profilo configurato**, memorizzato prima dello stop. Non viene letto lo stato arbitrario del firmware o di altre app. La selezione RGB è per modello (Drevo/Razer), non per singolo esemplare dello stesso modello.

Stop schermi e stop sistema vengono combinati: un risveglio del sistema non accende le luci se gli schermi restano spenti e la relativa opzione è attiva. Dopo il ritardo configurato, vengono effettuati tentativi a intervalli di 0, 250 ms, 500 ms, 1 s e 2 s, riprovando soltanto gli adapter falliti. Un nuovo stop cancella il ripristino in corso.

Le scritture HID avvengono fuori dal thread UI. `NSWorkspace.willSleepNotification` offre una notifica, non una garanzia che USB completi prima della sospensione: come nel daemon, il comando di spegnimento resta best effort. L'app non trattiene il Mac con un'assertion di alimentazione.

## CLI compatibile

```sh
.build/release/mksleep-rgb devices
.build/release/mksleep-rgb check
.build/release/mksleep-rgb test --config config.example.json
.build/release/mksleep-rgb daemon --config config.example.json
```

Sono preservati anche `on`, `off` e `authorize`. Non eseguire il daemon contemporaneamente alla nuova app installata. `test` modifica realmente le luci per due secondi; `devices` è una lettura dell'inventario. La CLI `daemon` conserva la logica precedente; i nuovi retry e le opzioni UI appartengono all'app.

Modalità sicura, a PeripheralKit già chiuso:

```sh
open -n ~/Applications/PeripheralKit.app --args --safe-mode
```

La modalità sicura non modifica le preferenze salvate e impedisce rimappatura e registrazione dei pulsanti. Il controllo RGB resta indipendente.

## Test e documentazione

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox
```

25 test coprono pacchetti originali, matcher, identità, consumo down/up, cattura, azioni, persistenza, migrazione, cache RGB e retry/cancellazione. I test delle azioni costruiscono eventi Quartz ma li raccolgono in memoria, senza inviarli: richiedono una sessione grafica con accesso al WindowServer e possono fallire in un sandbox di esecuzione restrittivo.

- [Architettura, API, permessi e rischi](ARCHITECTURE.md)
- [Perimetro MVP e accettazione fisica](MVP.md)
- [Verifiche eseguite](VERIFICATION.md)

## Riferimenti dei protocolli

I pacchetti del daemon sono stati conservati, non riscritti da codice GPL. I riferimenti storici sono [RazerControl, MIT](https://github.com/pol-cova/RazerControl), [OpenRazer](https://github.com/openrazer/openrazer), [dtv2](https://github.com/cobacdavid/dtv2), [DrevoTyrfing](https://github.com/dennisblokland/DrevoTyrfing) e [HIDAPI](https://github.com/libusb/hidapi). Prima di una distribuzione pubblica resta da completare una verifica delle attribuzioni e delle licenze dei riferimenti originali.
