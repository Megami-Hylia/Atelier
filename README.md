# Atelier per iPad

**IPA device realmente compilata e verificata; progetto funzionalmente incompleto.** La consegna corrente `Atelier-unsigned.ipa` proviene dal [run #6](https://github.com/Megami-Hylia/Atelier/actions/runs/40763569979), commit `5871e5dfe7a1da879806fd86e737598ec242bb3a`, con Xcode 26.2 e SDK iOS 26.2. Il controllo del file scaricato su Windows conferma eseguibile arm64 per iOS device, famiglia solo iPad, libreria Metal, 192 preset/asset inclusi e assenza di firma/provisioning. Dimensione: **703.220 byte**; SHA-256: `f2d751ebae647943589f4524cca8393da98c637dfabee11b2153c62b8825f4ae`.

Il run #6 si è concluso con successo: **15 test nativi superati, zero fallimenti e zero test saltati**, sul simulatore iPad (A16), sistema 26.2, architettura x86_64. I test hanno prodotto anche la tavola reale dei 192 preset dal motore Metal, con hash distinti per il tracciato sintetico scelto. I [risultati e i limiti delle prove](docs/NATIVE_TEST_RESULTS.md) distinguono ciò che è stato eseguito da ciò che resta da verificare.

Questa è un’implementazione nativa SwiftUI/UIKit/Metal in sviluppo, non una replica completa o verificata di Procreate. Firma/installazione, Apple Pencil e prestazioni su iPad reale non sono verificate. I test del simulatore non provano la parità generale né la qualità di tutti i preset. L’IPA attuale sostituisce gli artefatti precedenti; [BUILD_STATUS.md](BUILD_STATUS.md) conserva anche la storia dei tentativi senza attribuirne gli esiti alla nuova revisione. Consegna e rapporto aggiornati il **29 ottobre 2026**; sorgenti, build e test CI del 28 ottobre.

Il prodotto è pensato per funzionare offline senza acquisti, abbonamenti, pubblicità o strumenti a pagamento. Il codice dell’incremento e le risorse dei pennelli sono originali. Le categorie e il riferimento 5.4.14 organizzano il confronto richiesto; non implicano identità di pennelli, algoritmi o compatibilità proprietaria.

Per lavorare da Windows partire da [README_WINDOWS.md](README_WINDOWS.md). La compilazione usa Xcode e gli SDK Apple su macOS remoto. `Atelier-unsigned.ipa` va firmata in un secondo momento per installarla su un iPad standard. L’autenticazione GitHub e la firma Apple sono passaggi distinti; la build unsigned riuscita non ha usato segreti Apple.

Documenti da leggere:

- [FEATURE_PARITY.md](FEATURE_PARITY.md): inventario completo del perimetro e stato di ogni funzione.
- [BRUSH_PARITY.md](BRUSH_PARITY.md), [BRUSH_PARAMETERS.md](BRUSH_PARAMETERS.md), [PRESET_CATALOG.md](PRESET_CATALOG.md): preset originali, copertura e controlli implementati/mancanti.
- [ACCEPTANCE.md](ACCEPTANCE.md): criteri A–F separati e prove funzionali/GPU/hardware ancora da svolgere.
- [NATIVE_TEST_RESULTS.md](docs/NATIVE_TEST_RESULTS.md): 15 test effettivamente superati e tavola dei preset, con limiti espliciti.
- [BRUSH_VISUAL_REVIEW.md](BRUSH_VISUAL_REVIEW.md): confronto della tavola prodotta, somiglianze e difetti dei preset ancora da correggere.
- [REFERENCE.md](REFERENCE.md): fonti effettivamente consultate e materiali non disponibili.
- [ARCHITECTURE.md](ARCHITECTURE.md): percorso di rendering/persistenza e limiti dell’incremento.
- [NEXT_STEPS.md](NEXT_STEPS.md): stato conservato per proseguire senza ridurre la richiesta.
- [BUILD_STATUS.md](BUILD_STATUS.md): stato della compilazione e attivazione del runner.

La cartella `Atelier/` contiene app, engine, modelli e risorse; `AtelierTests/` contiene prove di modello; `scripts/` contiene generazione/verifiche e avvio build; `.github/workflows/` contiene la CI. `BUILD_REPORT.json` e i rapporti di verifica accompagnano l’artefatto CI realmente prodotto; `test-summary.json`, `test.log`, `AtelierTests.xcresult` e gli allegati conservano l’evidenza nativa. La verifica strutturale dell’IPA, i test sintetici del renderer e le prove su iPad sono risultati distinti.

