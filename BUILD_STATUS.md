> Nuova IPA: [CURRENT_BUILD.md](CURRENT_BUILD.md). I rapporti sotto riguardano la precedente revisione 5871e5d.

# Stato build e criteri distinti

Aggiornamento: 29 ottobre 2026. L’artefatto di consegna corrente proviene dal **run #6**, commit **5871e5dfe7a1da879806fd86e737598ec242bb3a**. Il workflow è concluso con successo: build device, packaging verificato e **15 test nativi superati, zero falliti e zero saltati** sul simulatore iPad.

| Criterio | Stato corrente |
|---|---|
| A. Sorgenti e progetto completati | **Parziale** rispetto al perimetro complessivo; progetto, sorgenti e pipeline presenti. Consultare FEATURE_PARITY.md |
| B. Build nativa dispositivo riuscita | **Riuscita**: Release `iphoneos`, destinazione `generic/platform=iOS`, arm64, run #6 |
| C. IPA unsigned confezionata/verificata | **Riuscita**; scaricata e sottoposta nuovamente al validatore strutturale su Windows |
| D. Firma/installazione Windows | **Non eseguita**; guida ufficiale documentata, modello iPad e versione iPadOS dell’utente non identificati |
| E. Test su iPad reale | **Non eseguiti**; un simulatore non soddisfa questo criterio |
| F. Parità complessiva | **Non dimostrata**; funzioni mancanti e verifiche residue restano nella matrice |

## Artefatto corrente e provenienza

- File: **Atelier-unsigned.ipa**, **703220 byte**.
- SHA-256: **f2d751ebae647943589f4524cca8393da98c637dfabee11b2153c62b8825f4ae**.
- Commit sorgenti: **5871e5dfe7a1da879806fd86e737598ec242bb3a**.
- [Run #6 e relativi artefatti](https://github.com/Megami-Hylia/Atelier/actions/runs/40763569979).
- Runner: **macos-26-intel**, X64, immagine effettiva **20260824.0517.1**.
- macOS **26.6.1 (25G76)**; Xcode **26.2 (17C52)**; SDK iOS **26.2**.
- Compilatore Swift **6.2.3**, modalità linguaggio **5**; compilatore Metal **32023.864**.

Il report macchina `BUILD_REPORT.json` e `ipa-verification.json` sono forniti con l’artefatto; i log e le impostazioni effettive sono nella diagnostica CI. Il repository [Megami-Hylia/Atelier](https://github.com/Megami-Hylia/Atelier) rimane **privato**. La successiva firma non richiede di rendere pubblico il codice.

## Controlli effettivamente superati

La verifica CI e la ripetizione su Windows confermano eseguibile Mach-O `MH_EXECUTE` arm64, `LC_BUILD_VERSION` piattaforma **2** (iOS device), `UIDeviceFamily=[2]`, struttura `Payload/Atelier.app`, nessuna firma/provisioning personale, `default.metallib` compilata, catalogo schema1 con **180 preset in 18 set e 12 Foundations separati**, sei shape e sei grain PNG. Non sono una prova qualitativa dei pennelli o dell’avvio su iPad fisico.

Sei test Python del validatore sono stati eseguiti su fixture sintetiche temporanee: accettazione strutturale e rifiuto di simulatori arm64, firme, architetture/dati troncati, container errati, asset mancanti, cataloghi corrotti e conteggi incompleti. Le fixture non sono artefatti dell’app. Parsing PowerShell, sintassi Bash, plist e scheme XML sono stati controllati localmente.

## Test simulatore e cronologia essenziale

Il run #6 ha eseguito i test su un nuovo **iPad (A16) simulato, iOS 26.2 (23C54), architettura x86_64**, creato esclusivamente per quel run. Il boot è riuscito entro il limite di 300 secondi. Il riepilogo macchina [TEST_SUMMARY.json](docs/verification/TEST_SUMMARY.json) riporta **Passed: 15/15, failed: 0, skipped: 0, expected failures: 0**; `test.log` termina con `TEST SUCCEEDED`. La diagnostica contiene anche il bundle `.xcresult` completo.

Gli otto XCTest `RendererTests` verificano replay deterministico ed effetto dei parametri sui pixel, undo/redo e riapertura, gomma e trasporto del pigmento con smudge, continuità tra tile, rifiuto dei documenti e tratti fuori limite e duplicazione senza alterare l’originale. I sette test Swift Testing `BrushTests` verificano il catalogo e le operazioni/persistenza della libreria, compresi input invalidi, archivio danneggiato ed errore di scrittura.

Il test `testCatalogComparisonFromActualMetalRenderer` ha prodotto la [tavola PNG dei 192 preset](docs/verification/BRUSH_COMPARISON.png) con il renderer **Atelier MetalPainter** realmente eseguito nel simulatore. Il [manifest allegato](docs/verification/BRUSH_RENDER_MANIFEST.json) contiene 192 ID e **192 hash di output distinti**, ottenuti con lo stesso input sintetico `PencilSample.demo` e seed42. Sono una prova circoscritta di esecuzione e distinzione dei pixel per quella traiettoria; non dimostrano parità artistica con Procreate, precisione Pencil, latenza o prestazioni su iPad fisico. La voce `hardware: iPad` del manifest è l’etichetta restituita dall’ambiente simulato; il riepilogo XCTest identifica esplicitamente `iOS Simulator`.

Il run #1 è fallito nell’assegnazione del runner arm64; il #2 in un controllo preliminare che non considerava l’omissione delle impostazioni vuote nel JSON Xcode; il #3 per il componente Metal mancante. Il #4 ha già prodotto una vera IPA, ma non ha eseguito XCTest per la selezione della destinazione. Il #5 ha prodotto una nuova IPA, poi è stato annullato durante il boot bloccato di uno snapshot simulatore preconfigurato. Questi artefatti precedenti non sono l’artefatto corrente indicato sopra.

La build unsigned non legge né richiede Apple ID, certificati, profili personali o segreti Apple. Nome app, bundle identifier e nome IPA restano distinti: Atelier / org.atelier.ipad / Atelier-unsigned.ipa.
