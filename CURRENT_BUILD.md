# Build corrente

Commit compilato e testato: `2dbccf6d0ffacdf3e38539280a6dbdfe15669523`.
[Workflow e prove native](https://github.com/Megami-Hylia/Atelier/actions/runs/40973187554).
IPA dedicata: `Atelier-tratti-fluidi-2dbccf6.ipa` (arm64, solo iPad, unsigned).
SHA-256: `e4da5f1be4dec3d02486febaad19d24319295fafe23fe34c3bd06efb5ae5e2eb`.

**58 test nativi superati, zero falliti e zero saltati**, simulatore iPad A16 / iOS 26.2 / x86_64. Include 22 nuovi test del percorso di disegno: campionamento adattivo, curve, stabilizzazione, pressione e inclinazione, combinazione, confronto Metal incrementale/replay, correzioni Pencil, salvataggio/undo/redo, 8192 campioni e cache con 200 tratti. Anche i sei test del validatore IPA sono passati.

Controllo: **Azioni → Pref. → Stabilizzazione tratto**. I nuovi tratti conservano scala e stabilizzazione nel documento; quelli precedenti mantengono il planner originale. Vedere [DRAWING_PIPELINE.md](DRAWING_PIPELINE.md).

Nessuna prova su iPad fisico: questi risultati non misurano latenza o FPS di iPad 9 / iPadOS 26.4. Il costo GPU dipende ancora da tela, densità, dimensioni e filtri del pennello.
