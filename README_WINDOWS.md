# Atelier da Windows

App nativa esclusivamente iPadOS, Swift/SwiftUI/UIKit/Metal. Nome visibile **Atelier**, bundle identifier **org.atelier.ipad**, artefatto **Atelier-unsigned.ipa**: sono tre impostazioni distinte. Minimo iPadOS 18.0. Le funzioni implementate non richiedono acquisti, abbonamenti o pubblicità.

Il codice viene modificato da Windows. Xcode e gli SDK Apple compilano su macOS remoto; non funzionano nativamente su Windows. La firma non serve a compilare/confezionare l’IPA unsigned. Per eseguirla su un iPad standard occorre successivamente firmarla.

## Stato verificabile

Consultare [BUILD_STATUS.md](BUILD_STATUS.md), [FEATURE_PARITY.md](FEATURE_PARITY.md) e il rapporto della specifica esecuzione CI. Il progetto non è dichiarato completo o identico a Procreate. Versione di iPadOS e modello iPad/Pencil dell’utente non sono ancora noti: la compatibilità del dispositivo e la firma/installazione non sono state provate in questa sessione.

Repository creato privato: [Megami-Hylia/Atelier](https://github.com/Megami-Hylia/Atelier). Le credenziali GitHub e quelle Apple svolgono ruoli diversi. Nessun segreto Apple è necessario o letto dal workflow.

## Prerequisiti e costi della build

Servono accesso autorizzato al repository, permesso di eseguire Actions e disponibilità del runner macOS. Prima dell’avvio controllare **Settings → Billing and licensing → Usage/Budgets**: il piano dell’account e la spesa residua non sono stati misurati qui. Alla consultazione del 28 ottobre 2026, GitHub indica per Free 2.000 minuti mensili e 500 MB di artefatti; il runner macOS standard costa $0,062/minuto oltre l’allowance applicabile. Quote, storage, fiscalità e valuta possono variare. I runner standard dei repository pubblici hanno condizioni diverse; questo repository resta privato. [GitHub: billing Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [limiti e disponibilità](https://docs.github.com/en/actions/concepts/billing-and-usage).

La pipeline fissa `macos-26-intel`, Xcode **26.2 (17C52)**, SDK iOS **26.2**, Release `iphoneos`, destinazione `generic/platform=iOS`, architettura dispositivo `arm64`. Il runner Intel compila normalmente per l’iPad arm64; soltanto i test simulatore usano l’architettura dell’host (`x86_64`). Registra la versione effettiva dell’immagine. Le immagini hosted si aggiornano: la pipeline fallisce se la versione fissata non è disponibile, invece di usare silenziosamente un altro Xcode. Per riproducibilità temporale completa servirebbe un’immagine macOS controllata con la stessa toolchain; la riproducibilità binaria byte per byte non è dimostrata. [Inventario ufficiale macos-26 Intel](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).

## Avvio dal browser

1. Aprire il repository e verificare che `main` contenga `.github/workflows/build-ipad-unsigned.yml`.
2. Aprire **Actions → Build iPad unsigned → Run workflow** e selezionare `main`. `request_id` può restare vuoto.
3. Attendere l’esito. Nel run, scaricare **Atelier-unsigned** ed estrarre lo ZIP esterno prodotto da GitHub. Al suo interno si trova l’IPA con il rapporto e checksum.
4. Scaricare **Atelier-build-diagnostics** per log, impostazioni effettive e risultati XCTest. Un errore dopo il packaging, per esempio nei test simulatore, resta un errore del workflow: un’IPA già confezionata può esistere senza che tutti i test siano passati.

Il workflow deve trovarsi nel branch predefinito per essere avviato manualmente. [Istruzioni ufficiali workflow_dispatch](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).

## Avvio da PowerShell

Installare [Git](https://git-scm.com/download/win) e [GitHub CLI](https://cli.github.com/) dalle fonti ufficiali, quindi autorizzare personalmente GitHub CLI con `gh auth login`. Non incollare token o credenziali nel prompt di chat. Eseguire dalla copia locale:

```powershell
.\scripts\build_from_windows.ps1 -Repository Megami-Hylia/Atelier -Ref main
```

Lo script usa l’accesso GitHub CLI esistente, invia un token di correlazione univoco, segue quel preciso run e scarica l’artefatto in `downloads\<run-id>`. Confronta SHA-256 e rapporto CI; non tratta una semplice richiesta di build come successo. Non modifica l’ExecutionPolicy del computer. In caso di policy restrittiva seguire le regole del proprio amministratore o usare il browser.

Per verificare manualmente il checksum:

```powershell
Get-FileHash -LiteralPath '.\downloads\<run-id>\Atelier-unsigned.ipa' -Algorithm SHA256
```

Il valore deve coincidere con `ipa-verification.json` e `SHA256SUMS.txt`. Il report è relativo a quel commit, non prova che l’app coincida con file modificati successivamente.

## Cosa controlla il packaging

`scripts/build_unsigned_ipa.sh` compila l’app con firma disabilitata anche nelle impostazioni effettive dei target: `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGN_IDENTITY=`. Non usa `-exportArchive`. Copia con `ditto` il bundle per dispositivo e crea lo ZIP preservando permessi e collegamenti.

Su Xcode26 il compilatore Metal può essere un componente separato. Lo script verifica `xcrun metal -v` e, se mancante, scarica il componente ufficiale con `xcodebuild -downloadComponent MetalToolchain`, poi registra la versione effettiva. Questo download avviene sul runner macOS e richiede rete e spazio disco; non usa account Apple personali.

`scripts/verify_ipa.py` controlla la radice `Payload/Atelier.app`, Info.plist generato, famiglia dispositivo esattamente `[2]`, piattaforma `iPhoneOS/iphoneos`, eseguibile Mach-O `MH_EXECUTE` con permesso di esecuzione, `arm64`, `LC_BUILD_VERSION` piattaforma **2** (iOS device), assenza di `LC_CODE_SIGNATURE`, directory di firma e provisioning, e libreria Metal compilata. Rifiuta quindi anche un binario **arm64 per simulatore**.

Controlla inoltre l’effettivo `BrushCatalog.json` incluso nel bundle: schema1, 18 categorie obbligatorie con dieci preset ciascuna e dodici Foundations separati, ID univoci, riferimenti coerenti, seed e parametri numerici validi, tutte le sei shape e sei grain con firma PNG e dimensioni valide. Questa verifica dimostra la presenza offline delle risorse; la distinzione qualitativa dei tratti richiede le prove del renderer. Nessuno di questi controlli esegue l’app su un iPad fisico.

Il progetto imposta `TARGETED_DEVICE_FAMILY=2`, `SUPPORTS_MACCATALYST=NO`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD=NO` e `SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD=NO`. Non esistono target iPhone, Mac, Android o web. `iphonesimulator` serve unicamente ai test iPad e non entra nell’IPA. Un’eventuale distribuzione App Store richiederebbe separatamente una configurazione App Store Connect coerente e l’esclusione della disponibilità sui Mac Apple Silicon; non viene pubblicato nulla in questo flusso.

I test creano un iPad(A16) simulato dedicato sul runtime26.2, con nome univoco per il run, senza riutilizzare gli snapshot preconfigurati dell’immagine. Il boot ha un limite di 300 secondi. Il cleanup riguarda soltanto l’UUID creato dallo script. Un timeout produce una diagnostica esplicita e non diventa un test superato. `test-summary.json` contiene il riepilogo XCTest effettivo, oppure indica che non è disponibile; i PNG allegati provengono dalle prove realmente eseguite.

## Firma e installazione da Windows: Sideloadly

Percorso principale documentato sulle istruzioni ufficiali; **non eseguito su un iPad reale in questa sessione**. Non è possibile dichiarare verificata la combinazione dispositivo/iPadOS ancora sconosciuta.

1. Scaricare [Sideloadly ufficiale](https://sideloadly.io/) per Windows. Il sito richiede le versioni web Apple di iTunes e iCloud, con i collegamenti sul sito, e raccomanda Windows 10 o superiore.
2. Collegare l’iPad sbloccato con USB, confermare **Autorizza questo computer** e verificare che iTunes lo rilevi.
3. Trascinare nell’app locale l’**Atelier-unsigned.ipa effettivamente scaricata da questo progetto**; selezionare l’iPad.
4. Inserire personalmente Apple ID, password ed eventuale codice di autenticazione **solo nel programma locale**. Non salvarli nei sorgenti, nei log, nei segreti CI o nella chat.
5. Avviare l’installazione. Sideloadly applica la firma e il provisioning necessari: non elimina il requisito di firma di iPadOS.
6. Quando richiesto, su iPad autorizzare il profilo in **Impostazioni → Generali → VPN e gestione dispositivo**. Da iPadOS 16, abilitare **Impostazioni → Privacy e sicurezza → Modalità sviluppatore**, riavviare e confermare secondo le indicazioni del dispositivo.

Con account gratuito l’app dura normalmente **7 giorni** e il limite documentato è **3 app** sideloaded attive. Il rinnovo automatico richiede che computer e dispositivo siano raggiungibili via USB/Wi-Fi e configurati; non si promette installazione permanente. Prima di reinstallare salvare i documenti: mantenere account e bundle identifier coerenti evita di sostituire l’app con un’identità diversa. [FAQ Sideloadly: rinnovi, limiti, Developer Mode e problemi](https://sideloadly.io/faq).

## Alternativa: AltStore Classic / AltServer

Usare **Classic**, non AltStore PAL: il file locale di questo progetto è un’IPA da firmare. Installare [AltServer per Windows dalle istruzioni ufficiali](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows), con iTunes/iCloud indicati da quella guida. Collegare e autorizzare l’iPad, abilitare la sincronizzazione Wi-Fi, installare AltStore Classic dal menu AltServer e inserire personalmente le credenziali nel programma locale. Abilitare la modalità sviluppatore quando richiesta.

Aprire in AltStore Classic **My Apps → +** e scegliere l’IPA, con AltServer raggiungibile. La documentazione indica scadenza dopo 7 giorni e massimo 3 app attive, incluso lo slot usato da AltStore Classic; eseguire il refresh prima della scadenza. [Uso e rinnovo delle app](https://faq.altstore.io/altstore-classic/your-altstore), [limiti delle app attive](https://faq.altstore.io/altstore-classic/activating-apps). La firma/installazione di Atelier tramite questo percorso resta da provare sul dispositivo dell’utente.

## Capability e restrizioni

Questa build non contiene file `.entitlements`, estensioni incorporate, iCloud container, App Groups, push, In-App Purchase o accessi protetti da entitlement a pagamento. Disegno Metal, documenti locali e import/export tramite Files non richiedono capability di distribuzione aggiuntive. Il firmatore aggiungerà le voci di identità consentite dal proprio provisioning; validarle sulla copia firmata. Le funzioni future che richiederanno capability diverse devono essere esaminate individualmente: il provisioning gratuito non garantisce tutte le capability Apple. Non rimuovere funzioni o entitlement silenziosamente per far passare la firma.

Per Apple Pencil Pro, hover e funzioni analoghe serve hardware compatibile e una prova reale; la build riuscita non certifica questo supporto.

## Errori e recupero

| Problema | Azione |
|---|---|
| Nessun pulsante Run workflow | Verificare branch predefinito, file workflow e permessi Actions |
| Runner/quote indisponibili | Controllare Billing/Budgets e stato Actions; nessuna build può essere dichiarata eseguita senza runner |
| Xcode fissato non disponibile | Consultare inventario ufficiale, aggiornare esplicitamente pin e report, ripetere i test |
| Errore Swift/Metal o packaging | Leggere `build.log`; nessun artefatto IPA viene presentato come riuscito se la verifica fallisce |
| Fallisce solo XCTest simulatore | Distinguere IPA device verificata da test falliti; consultare `.xcresult` |
| Xcode mostra soltanto destinazioni generiche | Controllare `ARCHS_STANDARD`, i runtime disponibili e il log `simulator-destinations.txt`; lo script inizializza Xcode e attende il boot dell’iPad simulato |
| Firma richiesta da xcodebuild | Controllare tutte le tre impostazioni `CODE_SIGN*`; non aggiungere segreti Apple alla CI |
| iPad non rilevato | USB funzionante, dispositivo sbloccato/autorizzato, driver Apple e guide ufficiali del firmatore |
| App non avviabile dopo sette giorni | Rinnovare con il firmatore; preservare prima i documenti |
| Capability non supportata dal firmatore | Registrare restrizione, non promettere compatibilità né disattivare funzioni senza indicarlo |

Lo stesso `build_unsigned_ipa.sh` può essere eseguito su un Mac remoto autorizzato con la toolchain fissata se Actions non è disponibile. Nessun altro servizio a pagamento è stato selezionato o attivato; prima di proporlo vanno verificate offerte, quote e costi correnti.
