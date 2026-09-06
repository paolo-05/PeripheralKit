# Verifiche di PeripheralKit — 6 settembre 2026

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
- Dopo la ricompilazione, macOS richiede di riabilitare Accessibilità e Monitoraggio input: prova fisica della correzione in attesa dell'utente. Nessun permesso è stato concesso automaticamente.
- Nessun riferimento al vecchio nome nei file versionati attuali. Componenti dismessi spostati nel Cestino; impostazioni correnti preservate.
