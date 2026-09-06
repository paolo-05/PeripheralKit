# PeripheralKit: primo incremento

## Perimetro autorizzato

Implementare milestone 1 (shell nativa) e 2 (mouse), mantenendo sleep RGB Drevo Tyrfing V2 e Razer DeathAdder V2. Il documento completo resta la roadmap, non una promessa di tutte le feature nella prima versione.

## Verifiche richieste

- App accessoria nella barra menu; preferenze riapribili; uscita e interruttore rimappatura.
- Accessibilità e Monitoraggio input: stato reale, richiesta solo su azione esplicita.
- Pulsanti extra globali, registrazione annullabile, nessun hook ai tasti digitati.
- Button 4 → Ctrl+Left; Button 5 → Ctrl+Right; Mission Control e shortcut personalizzato.
- Consuma/pass-through, regole disattivabili e modalità sicura `--safe-mode`.
- Inventario HID, log limitato, configurazione persistente.
- RGB Drevo/Razer, sleep sistema/schermo, profilo configurato ripristinato al wake.
- Avvio al login via SMAppService, migrazione dal LaunchAgent precedente.
- Test unitari automatici; test fisici e permessi indicati separatamente.

## Non inclusi in questo incremento

Isolamento delle mappature per mouse, profili foreground-app nella UI, editor generico, shell/AppleScript, OpenRGB TCP, plugin dinamici, lettura affidabile dello stato RGB esterno. Nessuna simulazione presentata come supporto reale.

## Accettazione manuale

1. Installare l'app firmata, autorizzare Accessibilità e Monitoraggio input, riaprire se macOS lo richiede.
2. Creare almeno due Spaces, abilitare Ctrl+Left/Right in Impostazioni → Tastiera → Abbreviazioni → Mission Control.
3. Provare pulsanti posteriori/anteriori da Safari e Finder; con consumo attivo non deve avvenire anche Indietro/Avanti.
4. Registrare un pulsante e annullare una seconda registrazione; sinistro e destro non devono essere intercettati.
5. Disabilitare rimappatura; ripetere con `--safe-mode` e verificare input normale.
6. Verificare spegnimento schermo, stop completo, wake e scollegamento/ricollegamento Drevo/Razer.
7. Verificare ripristino rainbow/spectrum o del profilo importato, non di un effetto cambiato da un'altra app.
8. Controllare login dopo installazione e riavvio sessione.
