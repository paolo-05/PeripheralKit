# MKSleepRGB

Utility macOS nativa che spegne l'illuminazione della tastiera Drevo Tyrfing V2 e del mouse Razer DeathAdder V2 quando il Mac o i suoi schermi entrano in stop, poi la ripristina al risveglio. Questo comprende lo spegnimento schermo successivo a `Control-Command-Q` e il timeout di inattività. L'alimentazione del dock USB resta attiva, quindi mouse e tastiera possono continuare a riattivare il Mac.

Non dipende da OpenRGB, Homebrew, Python o driver kernel. Usa direttamente IOKit/HID con gli ID USB rilevati su questa macchina:

- Drevo Tyrfing V2: `0416:a0f8`
- Razer DeathAdder V2: `1532:0084`

## Prova manuale

```sh
./scripts/build.sh
.build/release/mksleep-rgb devices
.build/release/mksleep-rgb check
.build/release/mksleep-rgb test --config config.example.json
```

`test` spegne entrambi i dispositivi per due secondi e ripristina i profili configurati. Se macOS lo chiede, autorizza il processo in **Impostazioni di Sistema > Privacy e sicurezza > Monitoraggio input**.

## Installazione automatica

```sh
./scripts/install.sh
```

Lo script installa un'app locale firmata e un LaunchAgent dell'utente. La firma usa un'identità di code signing locale e persistente: gli aggiornamenti dell'app conservano così la stessa identità per i permessi macOS. I file risultanti sono:

- `~/Applications/MKSleepRGB.app`
- `~/Library/Application Support/MKSleepRGB/config.json`
- `~/Library/Application Support/MKSleepRGB/signing/`
- `~/Library/LaunchAgents/com.local.mksleep-rgb.plist`
- `~/Library/Logs/MKSleepRGB.log`

Al primo avvio macOS deve autorizzare **MKSleepRGB** in **Impostazioni di Sistema > Privacy e sicurezza > Monitoraggio input**. Per mostrare la richiesta:

```sh
open -n ~/Applications/MKSleepRGB.app --args authorize
```

Per disinstallare il LaunchAgent:

```sh
./scripts/uninstall.sh
```

## Configurazione

La configurazione installata è `~/Library/Application Support/MKSleepRGB/config.json`. I modi tastiera sono `static`, `rainbow`, `breathing`, `stream`, `radar`, `memory`; quelli del mouse sono `spectrum`, `static`, `breathing`. I colori usano `#RRGGBB`, mentre luminosità e velocità vanno da 0 a 100.

La Tyrfing V2 non espone un comando affidabile per leggere il profilo corrente: al risveglio viene quindi applicato il profilo scelto nel JSON. L'impostazione predefinita è rainbow per la tastiera e spectrum per il mouse.

## Riferimenti del protocollo

- Il formato Razer a 90 byte e i comandi RGB derivano dal progetto MIT [pol-cova/RazerControl](https://github.com/pol-cova/RazerControl), testato sul DeathAdder V2, e dalla documentazione [OpenRazer](https://github.com/openrazer/openrazer).
- I pacchetti della Drevo derivano dalla documentazione pubblica di [cobacdavid/dtv2](https://github.com/cobacdavid/dtv2) e [dennisblokland/DrevoTyrfing](https://github.com/dennisblokland/DrevoTyrfing).
- La semantica del report ID segue [HIDAPI](https://github.com/libusb/hidapi).
