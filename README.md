# Atelier per iPad

**Progetto incompleto.** Questo pacchetto contiene un incremento nativo SwiftUI/UIKit/Metal dedicato al sistema pennelli, ai documenti e alla pipeline unsigned. Non è una replica completa o verificata di Procreate. La build nativa non è stata eseguita in questo ambiente Windows e **l’IPA non è stata generata**.

Il prodotto è pensato per funzionare offline senza acquisti, abbonamenti, pubblicità o strumenti a pagamento. Il codice dell’incremento e le risorse dei pennelli sono originali. Le categorie e il riferimento 5.4.14 organizzano il confronto richiesto; non implicano identità di pennelli, algoritmi o compatibilità proprietaria.

Per lavorare da Windows partire da [README_WINDOWS.md](README_WINDOWS.md). La compilazione usa Xcode e gli SDK Apple su macOS remoto. Il risultato previsto dopo una build riuscita è `Atelier-unsigned.ipa`, da firmare in un secondo momento per installarlo su un iPad standard. L’autenticazione GitHub e la firma Apple sono passaggi distinti.

Documenti da leggere:

- [FEATURE_PARITY.md](FEATURE_PARITY.md): inventario completo del perimetro e stato di ogni funzione.
- [BRUSH_PARITY.md](BRUSH_PARITY.md), [BRUSH_PARAMETERS.md](BRUSH_PARAMETERS.md), [PRESET_CATALOG.md](PRESET_CATALOG.md): preset originali, copertura e controlli implementati/mancanti.
- [ACCEPTANCE.md](ACCEPTANCE.md): criteri A–F separati e prove funzionali/GPU/hardware ancora da svolgere.
- [REFERENCE.md](REFERENCE.md): fonti effettivamente consultate e materiali non disponibili.
- [ARCHITECTURE.md](ARCHITECTURE.md): percorso di rendering/persistenza e limiti dell’incremento.
- [NEXT_STEPS.md](NEXT_STEPS.md): stato conservato per proseguire senza ridurre la richiesta.
- [BUILD_STATUS.md](BUILD_STATUS.md): stato della compilazione e attivazione del runner.

La cartella `Atelier/` contiene app, engine, modelli e risorse; `AtelierTests/` contiene prove di modello; `scripts/` contiene generazione/verifiche e avvio build; `.github/workflows/` contiene la CI. I rapporti CI e le prove visive reali saranno prodotti soltanto dall’esecuzione dei rispettivi strumenti. I test locali non sostituiscono compilazione Swift/Metal o misure su iPad.

