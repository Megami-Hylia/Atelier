# Build corrente

Commit compilato e testato: `5d563f0a54171f48f21923c4101313d1d44d256b`. [Workflow e prove native](https://github.com/Megami-Hylia/Atelier/actions/runs/41120843683).
IPA: `Atelier-pennelli-5d563f0.ipa` (arm64, solo iPad, unsigned).
SHA-256: `aacc31f25b4db5d91ab8cc33fe7315b478e385bdedaaa36cfe5b61b4acfd1b4d`.

**67 test nativi superati, zero falliti e zero saltati**, su iPad A16 simulato / iOS 26.2 / x86_64, Xcode 26.2. Superati anche i sei test del validatore IPA e il controllo strutturale Windows della stessa IPA.

Nove nuovi casi verificano i 76 controlli a valori minimi, intermedi e massimi, differenze nei pixel con dipendenze attive, persistenza, pressione assegnata, opacità/flusso, stabilizzazione globale e locale, miniatura, pennelli combinati, previsioni, replay, gomma e sfumino. [Matrice effettiva](docs/verification/BRUSH_SETTINGS_MATRIX.json). [Cause e correzioni](docs/BRUSH_SETTINGS_FIX.md).

Rimane il percorso incrementale con campionamento adattivo, curve e cache storica limitata: [DRAWING_PIPELINE.md](DRAWING_PIPELINE.md). I tratti già salvati conservano le formule precedenti; i nuovi congelano la versione dei parametri nel documento.

Nessuna prova su iPad fisico: questi risultati non misurano latenza o FPS di iPad 9 / iPadOS 26.4. Le superfici di copertura sono incluse nel budget raster di 384 MiB; le tele molto grandi possono raggiungerlo.
