# Verifica delle impostazioni dei pennelli

[Run 41120843683](https://github.com/Megami-Hylia/Atelier/actions/runs/41120843683), commit `5d563f0a54171f48f21923c4101313d1d44d256b`: **67 test superati, zero falliti/saltati**. Nove nuovi casi comprendono tre valori per ognuno dei 76 controlli e un confronto effettivo dei pixel Metal con dipendenze attive. I valori ciclici/binari possono dare due risultati distinti su tre campioni. Sono verificati anche persistenza, assegnazioni della pressione, opacità/flusso/accumulo, zeri, preview e suoi componenti, stabilizzazione globale/locale, snapshot e rendering incrementale con previsioni per pennello/gomma/sfumino.

[Matrice esportata dai test](verification/BRUSH_SETTINGS_MATRIX.json), [cause e correzioni](BRUSH_SETTINGS_FIX.md). Esecuzione sintetica su simulatore, non prova hardware o misura di latenza/FPS. La stessa sorgente ha prodotto una IPA Release arm64 per dispositivo, strutturalmente verificata anche su Windows.

---

# Verifica del percorso di disegno aggiornato

[Run 40973187554](https://github.com/Megami-Hylia/Atelier/actions/runs/40973187554), commit `2dbccf6d0ffacdf3e38539280a6dbdfe15669523`: **58 test superati, zero falliti/saltati**. Rapporto effettivo `test-summary.json` e `TEST SUCCEEDED` acquisiti dall'artefatto CI. Esecuzione su iPad A16 simulato, iOS 26.2, x86_64, Xcode 26.2. Build device Release arm64 distinta e IPA verificata anche su Windows.

I nuovi test comprendono 15 `StrokeGeometryTests`, tre `CurvedStrokeIntegrationTests` e quattro `HistoryCacheTests`. Verificano densità a zoom diversi; duplicati e campioni ravvicinati; pressione/inclinazione e angoli; tocchi singoli, tratti brevi/rapidi; stabilizzazione, espressione del movimento e dettagli; equivalenza fra pacchetti e replay anche con pennelli combinati; confronto dei pixel Metal per pennello/gomma/sfumino, previsioni e stime tardive; salvataggio e undo/redo; 8192 campioni elaborati una sola volta; cache con 200 tratti e budget condiviso.

Nessun test hardware né misura di latenza/FPS. Dettagli e limiti: [DRAWING_PIPELINE.md](../DRAWING_PIPELINE.md) e [PERFORMANCE_STATUS.md](../PERFORMANCE_STATUS.md).

---

# Risultati dei test nativi

Rapporto aggiornato il **29 ottobre 2026** dopo il download delle prove. Esecuzione CI del **28 ottobre 2026**, [run #6](https://github.com/Megami-Hylia/Atelier/actions/runs/40763569979), commit `5871e5dfe7a1da879806fd86e737598ec242bb3a`.

Il file effettivo `Atelier-build-diagnostics/tests/test-summary.json` dichiara **Passed: 15 test superati, zero fallimenti, zero test saltati**. `test.log` conferma otto XCTest `RendererTests`, sette test Swift Testing `BrushTests` e `TEST SUCCEEDED`. Il bundle `AtelierTests.xcresult` e gli allegati del renderer sono stati scaricati insieme ai log.

| Ambiente di esecuzione | Valore registrato |
|---|---|
| Piattaforma | iOS Simulator |
| Modello simulato | iPad (A16) |
| Architettura simulatore | x86_64 |
| Sistema simulato | iOS/iPadOS 26.2, build 23C54 |
| Mac host | macOS 26.6.1 |
| Input di disegno | campioni sintetici, non Apple Pencil fisica |

Il campo generico `hardware: iPad` del manifest grafico proviene da `UIDevice.model` nel simulatore. Non descrive un iPad fisico collegato. La build device Release arm64 e il pacchetto unsigned sono artefatti distinti dalla build Debug x86_64 utilizzata per questi test.

## RendererTests — 8/8 superati

| Test eseguito | Evidenza ottenuta | Limite della prova |
|---|---|---|
| `testDeterministicReplayAndSpacingAffectPixels` | replay identico e differenze PNG modificando spacing, grana, taper, pressione e hue jitter | pochi casi sintetici; non tutti i parametri né fedeltà al riferimento |
| `testUndoRedoReopenPreservePixelsAndParameters` | contenuti e risultato grafico uguali dopo undo/redo e salvataggio/caricamento | istanza documento ricreata nel test, non riavvio del processo o crash |
| `testEraserChangesAlphaAndSmudgeMovesExistingPigment` | gomma riduce alpha di oltre metà nel punto campionato; sfumino porta pigmento in una posizione prima trasparente | singolo scenario e impronta; non tutte le famiglie o mescolanza completa |
| `testOpaqueStrokeHasNoTransparentTileSeam` | alpha maggiore di 0,95 nei tre pixel attorno al confine x=256 | tratto opaco senza grana; non verifica tutte le cuciture o il pickup ai bordi |
| `testCatalogComparisonFromActualMetalRenderer` | tavola reale di 192 preset e 192 hash PNG distinti con input fissato | hash diversi non certificano distinzione percettiva sufficiente o parità proprietaria |
| `testInvalidDocumentCannotReplaceCurrentState` | dimensione invalida, selezione livello inesistente e canvas oltre budget non sostituiscono lo stato | non è un test di allocazione GPU fallita su hardware |
| `testOverBudgetStrokeIsRejectedInsteadOfSilentlyTruncated` | planner segnala errore; commit rifiuta il tratto senza cambiare contenuto | un caso limite sintetico; non misura il budget globale del processo |
| `testDuplicatingDocumentPreservesOriginalFile` | la copia modifica UUID e nome senza cambiare i byte del file originale | flusso di modello; gesto UI galleria non automatizzato |

## BrushTests — 7/7 superati

| Test eseguito | Evidenza ottenuta | Limite della prova |
|---|---|---|
| `customBrushSurvivesSaveReopenAndJSONRoundTrip` | parametri, seed, metadati e asset conservati con nuova istanza dello store e JSON round trip | stesso processo; non `.brush`, `.brushset` o altri formati proprietari |
| `importRejectsInvalidReferencesAndParametersWithoutMutation` | riferimenti e valori invalidi rifiutati senza alterare lo stato | casi selezionati, non fuzzing completo |
| `movingAndRestoringPresetsKeepsPersonalWork` | spostamento, rinomina, ripristino e caricamento conservano il pennello personale | operazioni di modello, non navigazione UI |
| `bundledCatalogContainsDistinctConfigurations` | catalogo con 192 configurazioni, 18 set nuovi da dieci e identificatori distinti | conteggio/configurazioni, non giudizio qualitativo |
| `setAndLibraryOperationsKeepOrderAndBrushData` | libreria vuota esportabile, creazione/duplicazione/riordino/rinomina set e conservazione dopo eliminazione libreria | non tutte le combinazioni e non interazione Files reale |
| `failedDiskWriteRollsBackMemoryAndReportsError` | errore di scrittura su percorso impedito, rollback in memoria e conservazione del file sentinella | errore simulato tramite file al posto di directory; volume non riempito fisicamente |
| `damagedArchiveIsPreservedBeforeReplacement` | archivio corrotto copiato in recovery prima di sostituzione valida | recupero librerie; non crash recovery dei documenti di pittura |

## Tavola grafica estratta

L’allegato PNG `FB711DC0-0C18-4DF1-B93C-D92B55962AE5.png` è stato esportato dal risultato del test, non ricostruito da un renderer alternativo. Il manifest dei preset è `71CCBCA7-56A7-4FA0-A011-1AFA7DAC6970.json`: registra il motore `Atelier MetalPainter`, input sintetico a cento campioni, dimensione 32, colore sRGB fissato e seed di prova 42. Include 192 record e 192 hash distinti. SHA-256 della tavola: `dc1134d1f697d462596aa45551b0fd5cae3370a48f59243ff78ff87b81aee72b`.

La tavola mostra differenze fra famiglie di segni, ma molte varianti hanno profili simili per questo input. La valutazione qualitativa rimane parziale; non si attribuisce equivalenza a pennelli proprietari né si considera chiusa la dotazione Classic. Per il confronto restano necessari campioni e impostazioni della baseline originale 5.4.14.

Non sono stati eseguiti test di Apple Pencil fisica, firma/installazione da Windows, prestazioni su iPad, gesture end-to-end o confronto visivo con l’app originale. I criteri A/F rimangono incompleti e D/E non eseguiti in [ACCEPTANCE.md](../ACCEPTANCE.md).
