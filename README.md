# Atelier per iPad

**IPA device realmente compilata e verificata; progetto funzionalmente incompleto.** Il [run #4](https://github.com/Megami-Hylia/Atelier/actions/runs/40760299865) ha prodotto `Atelier-unsigned.ipa` dal commit `f10dfb4b05c82b17bbef5a9bbeb1fa4d4d80a558`, con Xcode 26.2 e SDK iOS 26.2. Il controllo del file scaricato su Windows conferma eseguibile arm64 per iOS device, famiglia solo iPad, libreria Metal, 192 preset/asset inclusi e assenza di firma/provisioning.

Questa è un’implementazione nativa SwiftUI/UIKit/Metal in sviluppo, non una replica completa o verificata di Procreate. Il passaggio successivo del run #4 è fallito nella selezione del simulatore: **nessun test funzionale è stato eseguito in quel run**. Firma/installazione, Apple Pencil e prestazioni su iPad reale non sono verificate. I sorgenti successivi includono ulteriori correzioni e modifiche ai preset: finché una nuova build non riesce, l’IPA attestata resta quella del commit indicato. [BUILD_STATUS.md](BUILD_STATUS.md) conserva la provenienza della consegna effettiva.

Il prodotto è pensato per funzionare offline senza acquisti, abbonamenti, pubblicità o strumenti a pagamento. Il codice dell’incremento e le risorse dei pennelli sono originali. Le categorie e il riferimento 5.4.14 organizzano il confronto richiesto; non implicano identità di pennelli, algoritmi o compatibilità proprietaria.

Per lavorare da Windows partire da [README_WINDOWS.md](README_WINDOWS.md). La compilazione usa Xcode e gli SDK Apple su macOS remoto. `Atelier-unsigned.ipa` va firmata in un secondo momento per installarla su un iPad standard. L’autenticazione GitHub e la firma Apple sono passaggi distinti; la build unsigned riuscita non ha usato segreti Apple.

Documenti da leggere:

- [FEATURE_PARITY.md](FEATURE_PARITY.md): inventario completo del perimetro e stato di ogni funzione.
- [BRUSH_PARITY.md](BRUSH_PARITY.md), [BRUSH_PARAMETERS.md](BRUSH_PARAMETERS.md), [PRESET_CATALOG.md](PRESET_CATALOG.md): preset originali, copertura e controlli implementati/mancanti.
- [ACCEPTANCE.md](ACCEPTANCE.md): criteri A–F separati e prove funzionali/GPU/hardware ancora da svolgere.
- [REFERENCE.md](REFERENCE.md): fonti effettivamente consultate e materiali non disponibili.
- [ARCHITECTURE.md](ARCHITECTURE.md): percorso di rendering/persistenza e limiti dell’incremento.
- [NEXT_STEPS.md](NEXT_STEPS.md): stato conservato per proseguire senza ridurre la richiesta.
- [BUILD_STATUS.md](BUILD_STATUS.md): stato della compilazione e attivazione del runner.

La cartella `Atelier/` contiene app, engine, modelli e risorse; `AtelierTests/` contiene prove di modello; `scripts/` contiene generazione/verifiche e avvio build; `.github/workflows/` contiene la CI. `BUILD_REPORT.json` e i rapporti di verifica accompagnano l’artefatto CI realmente prodotto. La tavola visiva resta da generare con un’esecuzione riuscita dei test del renderer; la verifica strutturale dell’IPA non la sostituisce.

