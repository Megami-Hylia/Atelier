# Atelier per iPad

App nativa SwiftUI/UIKit/Metal in sviluppo. La build corrente e la IPA unsigned sono documentate in [CURRENT_BUILD.md](CURRENT_BUILD.md), con commit, hash e [workflow](https://github.com/Megami-Hylia/Atelier/actions/runs/40973187554). I rapporti macchina correnti si trovano in `docs/verification/`.

Il percorso di disegno aggiornato comprende campionamento adattivo allo zoom, curve, stabilizzazione regolabile, rendering incrementale al ritmo dei frame e cache storica limitata. [Architettura e limiti del percorso](DRAWING_PIPELINE.md).

**58 test nativi superati, zero falliti/saltati**, su iPad A16 simulato / iOS 26.2 / x86_64. La build Release arm64 per dispositivo e la struttura della IPA sono state verificate. Firma, installazione e latenza su iPad fisico non sono state provate; la parità complessiva con il riferimento resta incompleta.

Il prodotto è pensato per funzionare offline senza acquisti, abbonamenti, pubblicità o strumenti a pagamento. Il codice dell’incremento e le risorse dei pennelli sono originali. Le categorie e il riferimento 5.4.14 organizzano il confronto richiesto; non implicano identità di pennelli, algoritmi o compatibilità proprietaria.

Per lavorare da Windows partire da [README_WINDOWS.md](README_WINDOWS.md). La compilazione usa Xcode e gli SDK Apple su macOS remoto. `Atelier-unsigned.ipa` va firmata in un secondo momento per installarla su un iPad standard. L’autenticazione GitHub e la firma Apple sono passaggi distinti; la build unsigned riuscita non ha usato segreti Apple.

Documenti da leggere:

- [FEATURE_PARITY.md](FEATURE_PARITY.md): inventario completo del perimetro e stato di ogni funzione.
- [BRUSH_PARITY.md](BRUSH_PARITY.md), [BRUSH_PARAMETERS.md](BRUSH_PARAMETERS.md), [PRESET_CATALOG.md](PRESET_CATALOG.md): preset originali, copertura e controlli implementati/mancanti.
- [ACCEPTANCE.md](ACCEPTANCE.md): criteri A–F separati e prove funzionali/GPU/hardware ancora da svolgere.
- [NATIVE_TEST_RESULTS.md](docs/NATIVE_TEST_RESULTS.md): risultati effettivi del simulatore e tavola dei preset, con limiti espliciti.
- [BRUSH_VISUAL_REVIEW.md](BRUSH_VISUAL_REVIEW.md): confronto della tavola prodotta, somiglianze e difetti dei preset ancora da correggere.
- [REFERENCE.md](REFERENCE.md): fonti effettivamente consultate e materiali non disponibili.
- [ARCHITECTURE.md](ARCHITECTURE.md): percorso di rendering/persistenza e limiti dell’incremento.
- [NEXT_STEPS.md](NEXT_STEPS.md): stato conservato per proseguire senza ridurre la richiesta.
- [BUILD_STATUS.md](BUILD_STATUS.md): stato della compilazione e attivazione del runner.

La cartella `Atelier/` contiene app, engine, modelli e risorse; `AtelierTests/` contiene prove di modello; `scripts/` contiene generazione/verifiche e avvio build; `.github/workflows/` contiene la CI. `BUILD_REPORT.json` e i rapporti di verifica accompagnano l’artefatto CI realmente prodotto; `test-summary.json`, `test.log`, `AtelierTests.xcresult` e gli allegati conservano l’evidenza nativa. La verifica strutturale dell’IPA, i test sintetici del renderer e le prove su iPad sono risultati distinti.

