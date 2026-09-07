# PeripheralKit: architettura

Decisione del 6 settembre 2026: utility macOS 14+, Swift 6, SwiftUI/AppKit, menu bar, senza dipendenze di rete. Il primo incremento implementa milestone 1 e 2; preserva inoltre i protocolli RGB e la CLI esistenti. Nessun editor visuale generico in questo incremento.

## Confini e API

| Sottosistema | API pubblica | Permessi / sandbox | Limiti e fallback |
| --- | --- | --- | --- |
| App e preferenze | SwiftUI, NSStatusItem, NSWindow | Nessun permesso | LSUIElement, finestra riapribile dal menu |
| Input | CGEvent.tapCreate, session event tap attivo | Accessibilità; verificare TCC sul bundle firmato. App distribuita senza App Sandbox | Solo otherMouseDown/Up; niente testo tastiera. Tap non disponibile: nessuna soppressione, stato visibile |
| Azioni | CGEvent keyboard events, post a cghidEventTap | Accessibilità | Ctrl+frecce e Ctrl+su dipendono dalle scorciatoie abilitate in macOS; scorciatoia personalizzabile |
| Dispositivi | IOHIDManager e proprietà IOHIDDevice | Monitoraggio input per accesso HID, richiesta esplicita | Identità VID/PID + seriale, altrimenti location e interfaccia; non stabile cambiando porta |
| Regole | Modelli Codable, matcher sincrono puro | Nessuno | Una regola per pulsante nella UI; prima corrispondenza vince; sequenza di azioni separata dal tap |
| Sleep | NSWorkspace willSleep/didWake e screensDidSleep/Wake | Nessuno | Conserviamo il comportamento già usato. Le notifiche non garantiscono completamento USB prima della sospensione; nessuna assertion che ritardi lo stop |
| RGB | Adapter compilati, IOHIDDeviceSetReport | Accesso HID, no sandbox nella distribuzione locale | Drevo output 32 byte e Razer feature 90 byte già presenti. Ripristino del profilo configurato, NON lettura dello stato arbitrario del firmware |
| Login | SMAppService.mainApp | App bundle installato, eventuale approvazione in Impostazioni | Stato reale del servizio; niente nuovo LaunchAgent |
| Persistenza | JSON atomico in Application Support | Nessuno fuori sandbox | Unico settings.json PeripheralKit, errori esposti senza sovrascrivere file corrotto |
| Diagnostica | Logger unificato + buffer in memoria limitato | Nessuno | Metadati dei soli pulsanti aggiuntivi; nessun contenuto digitato |

## Identità degli eventi

CGEvent non espone un'identità USB pubblica affidabile del mouse sorgente. La lista HID è un inventario e non dimostra quale mouse abbia generato un click. Il primo incremento applica le mappature a tutti i mouse; la cattura dichiara «origine non disponibile». Le condizioni dispositivo rifiutano eventi privi di identità. Non correlare arbitrariamente timestamp HID/Quartz: con più mouse o eventi simultanei sarebbe una falsa garanzia. L'isolamento per dispositivo rimane P1 da investigare con input IOHID e test hardware.

## Flusso

InputEventSource → RuleEngine → ActionExecutor. Il tap valuta solo una fotografia delle regole e decide immediatamente pass-through/soppressione; l'esecuzione viene accodata. Down e up restano accoppiati anche se la regola viene disattivata durante il click. Eventi sintetici marcati; nessun monitor globale di tasti.

SystemEventMonitor → stato combinato sistema/schermo → coordinatore RGB → RGBDeviceAdapter. Una coda seriale separa HID dalla UI; il profilo prima dello stop viene mantenuto fino al ripristino. Le notifiche duplicate non sovrascrivono il profilo. Una generazione cancella i ripristini superati; ogni passaggio usa tentativi a intervalli 0, 250 ms, 500 ms, 1 s, 2 s, 4 s e 8 s dopo il ritardo configurato. Nessun comando RGB viene inviato solo perché si apre l'app.

## Struttura

- `Sources/PeripheralKit/App/`: lifecycle, menu, preferenze, stato osservabile.
- `Sources/PeripheralKit/Core/`: eventi, condizioni, regole, configurazione JSON.
- `Sources/PeripheralKit/Input/`: event tap e azioni Quartz.
- `Sources/PeripheralKit/Hardware/`: protocolli RGB originali e adapter.
- `Sources/PeripheralKit/System/`: monitor sleep, inventario HID.
- `Tests/PeripheralKitTests/`: pacchetti originali e test di regressione/matcher/persistenza.
- `PeripheralKit.xcodeproj`: app nativa; `Package.swift`: build e test CLI senza dipendenze.

## Rischi e piano

1. Shell app, permessi, diagnostica, build e test.
2. Pulsanti 4/5, cattura annullabile, scorciatoie e soppressione, build e test.
3. Accettazione manuale su DeathAdder: retro → Space precedente, fronte → successivo. Senza permessi e input fisico non dichiarare superata questa verifica.
4. In seguito: identificazione per dispositivo, profili app, editor automazioni, snapshot reale se il protocollo lo permette, OpenRGB opzionale.

Non importare codice GPL da OpenRazer/OpenRGB: i pacchetti esistenti restano isolati, riferimenti MIT RazerControl e documentazione protocollo da riesaminare prima di distribuzione pubblica. Nessuna licenza generale inventata.

## Fonti e verifica API

- [Apple: CGEvent tap](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:))
- [Apple: CGEvent](https://developer.apple.com/documentation/coregraphics/cgevent)
- [Apple: notifiche sleep/wake e limiti](https://developer.apple.com/library/archive/qa/qa1340/_index.html)
- [Apple: SMAppService register](https://developer.apple.com/documentation/servicemanagement/smappservice/register())
- [OpenRazer: riferimento protocollo, non codice importato](https://github.com/openrazer/openrazer/blob/master/driver/razercommon.h)
- [OpenRGB: disponibilità macOS, backend futuro opzionale](https://openrgb.org/releases.html)

Le firme effettive vengono verificate compilando contro il SDK macOS locale. Nessuna API privata né driver kernel.

## Aggiornamento: lifecycle gestito da Xcode

Il progetto Xcode gestisce build, test, archive e installazione. Due schemi condivisi: `PeripheralKit` e `PeripheralKit Install`. Il secondo usa un target aggregato dipendente dall'app e una fase nativa Copy Files, con destinazione configurabile in `Configuration/Local.xcconfig`. Nessuna fase shell, nessun keychain dedicato: firma locale Xcode con certificato persistente `PeripheralKit Local Development` nel portachiavi login.

`PeripheralKitTests` è un target XCTest senza host che compila gli stessi sorgenti di produzione esclusi CLI e main, così i test non avviano monitor, TCC. Le dipendenze hardware sono sostituite da mock.

Le preferenze RGB e mouse sono caricate soltanto dal file PeripheralKit. Il coordinatore RGB dell'app è l'unico monitor di stop/risveglio. La CLI offre operazioni diagnostiche e RGB esplicite, senza un secondo servizio residente.

ActionEngine controlla CGPreflightPostEventAccess e pubblica a cghidEventTap una sequenza marcata: modificatori premuti, down/up del tasto, modificatori rilasciati in ordine inverso. Il tap di ricezione mouse resta a livello sessione. La UI permette di provare il cambio Space; una notifica spaceChanged costituisce una conferma separata dall'invio.

La sequenza segue CGEventCreateKeyboardEvent del SDK Apple, che richiede esplicitamente gli eventi dei modificatori. Tutti gli eventi di una scorciatoia sono creati prima di pubblicarli per evitare modificatori senza rilascio in caso di errore.

## Ripristino USB e identità stabile

La Drevo richiede due reinvii ritardati dopo il primo invio riuscito (attese aggiuntive di 2 e 5 secondi), riaprendo il dispositivo per ogni scrittura. Il coordinatore mantiene lo snapshot finché tutti i passaggi sono terminati; gli adapter procedono in task separati sullo stesso actor e un nuovo sleep invalida l'intera generazione. I log di alimentazione e invio RGB usano il livello notice per permettere diagnosi anche dopo una riapertura dell'app.

Tutti i target riusano `PERIPHERALKIT_SIGNING_IDENTITY`. Il requisito designato combina bundle ID e certificato leaf; non include il cdhash specifico della build. Nessuna chiave nel repository, nessuna rigenerazione o firma ad hoc nel processo di build. La prima transizione di identità richiede nuovamente i consensi macOS.
