# Accettazione e prove

Stato al **28 ottobre 2026**: incremento di sorgenti in lavorazione; la parità complessiva non è dimostrata. I risultati di controlli automatici vanno letti nel rapporto effettivamente prodotto, non dedotti dalla presenza dei test. Una build riuscita non dimostra avvio su iPad o equivalenza con il riferimento.

| Criterio | Stato | Evidenza / passaggio necessario |
|---|---|---|
| A — Sorgenti e progetto completati | **incompleto** | sorgenti dell’incremento e progetto presenti; molte voci della matrice assenti o parziali |
| B — Build nativa device riuscita | **in attesa di esito** | primo tentativo fermato prima di Xcode dalla capacità del runner ospitato; [secondo tentativo](https://github.com/Megami-Hylia/Atelier/actions/runs/40759656717) avviato su macOS Intel; nessun rapporto di successo acquisito |
| C — IPA unsigned confezionata e verificata | **non generata** | verrà prodotta solo dopo B e controlli Mach-O/plist/firma riusciti |
| D — Firma/installazione Windows | **non eseguita** | passo separato, credenziali inserite dall’utente nel programma locale |
| E — Test iPad reale e prestazioni | **non eseguiti** | nessun iPad o Apple Pencil collegato per questa consegna |
| F — Parità complessiva dimostrata | **non raggiunta** | [FEATURE_PARITY.md](FEATURE_PARITY.md) contiene lacune e confronti non svolti |

Non esiste un `Atelier-unsigned.ipa` valido finché la CI non lo costruisce e verifica. Un archivio di sorgenti non è un IPA. La mancanza di credenziali per firmare non impedisce B/C; l’attivazione di un repository/runner autorizzato è una dipendenza diversa.

## Accettazione del modulo pennelli

| ID | Procedura ripetibile | Risultato da registrare | Stato |
|---|---|---|---|
| BR-A01 | installazione pulita, rete disattivata, primo avvio | 18 set × 10 preset più basi separate; nessuna risorsa mancante | non eseguita su app |
| BR-A02 | selezionare almeno un preset per ogni categoria e dipingere lo stesso input | nome selezionato, canvas, differenza motivata del segno | non eseguita su app |
| BR-A03 | generare tavola dal renderer comune con input/colore/seed identici | PNG con preset annotati, parametri, versione motore e hash | `RendererEvidence.generate` e test nativo predisposti; esecuzione non certificata |
| BR-A04 | per ogni controllo modificare solo un parametro, stessa traccia e seed | differenza pertinente, immagine prima/dopo e metrica | non eseguita; vedi matrice parametri |
| BR-A05 | crea → duplica → rinomina → riordina → sposta → salva → termina → riapri → reset | JSON e asset prima/dopo identici salvo cambi richiesti | test di modello da eseguire; flusso UI non verificato |
| BR-A06 | dipingere campioni multicolore; sfumare; cancellare usando la stessa famiglia | sfumino trasporta colore e gomma riduce alpha; nessun tratto colore aggiunto dalla gomma | non eseguita su GPU/hardware |
| BR-A07 | esporta/importa singolo pennello, set e libreria originali; tentare file malformati | round trip, ordine, asset e parametri; rifiuti espliciti | export JSON Atelier di pennello/set/libreria collegato alla UI; test nativi predisposti, esito da acquisire; proprietari non supportati |
| BR-A08 | tratto → undo → redo → salva → riapri → export | stesso risultato del renderer a parità di input; documentare tolleranza float | non eseguita su Metal |
| BR-A09 | ripetere BR-A02/04/06 con iPad e Pencil identificati | log hardware con sensori effettivi e capacità disponibili | non eseguita; input sintetico separato |

Lo stato “catalogo numericamente valido” non soddisfa BR-A02/03/04. Due preset con JSON diverso possono restare troppo simili nel segno; la distinzione qualitativa richiede una tavola reale e il confronto visivo.

`AtelierTests/RendererTests.swift` contiene le seguenti prove predisposte, il cui esito è ancora da acquisire:

- `testDeterministicReplayAndSpacingAffectPixels`: replica input e varia spacing, grana, taper, pressione e colore, cercando differenze nei pixel.
- `testUndoRedoReopenPreservePixelsAndParameters`: confronta contenuto e output dopo undo/redo e riapertura.
- `testEraserChangesAlphaAndSmudgeMovesExistingPigment`: misura riduzione dell’alpha e trasporto di pigmento verso una zona prima trasparente.
- `testOpaqueStrokeHasNoTransparentTileSeam`: verifica continuità opaca in tre pixel adiacenti al confine; non misura continuità della texture.
- `testCatalogComparisonFromActualMetalRenderer`: genera tavola dal motore effettivo e controlla unicità degli hash per l’input sintetico scelto.
- `testInvalidDocumentCannotReplaceCurrentState`: protegge lo stato corrente da modifiche non valide.
- `testOverBudgetStrokeIsRejectedInsteadOfSilentlyTruncated`: richiede un errore esplicito per il superamento del limite di stamp, senza dichiarare un tratto troncato come rendering completo.
- `testDuplicatingDocumentPreservesOriginalFile`: verifica che la copia di un documento non alteri il file originale.

`BrushTests.swift` esercita persistenza, ripristino, validazione e JSON originali. L’esistenza dei test non costituisce un risultato di esecuzione. Una differenza di PNG prova un effetto, ma non da sola fedeltà qualitativa o equivalenza fisica con il riferimento.

La review e le correzioni sul percorso di salvataggio e allocazione sono in [STORAGE_AUDIT.md](STORAGE_AUDIT.md). Rimangono non eseguite le prove con disco fisicamente pieno, interruzione del processo e memoria esaurita su iPad.

## Scenari del renderer e dei documenti

Usare documenti sRGB di 1024 × 768 e 2048 × 2048 con livello trasparente. Conservare file input e output in una cartella di prove insieme al commit della build. Per le prove jitter fissare esplicitamente i seed e il tracciato; separare l’output atteso dal codice che lo produce.

1. Attraversare in tutte le direzioni i confini dei tile a 256/512/768 pixel; controllare grana, impronta ruotata e sfumino su entrambe le parti del bordo.
2. Disegnare input lenti/veloci e campioni con pressione crescente/decrescente; confrontare dimensione, opacità e spaziatura con la configurazione.
3. Cancellare su livello trasparente e su più livelli; verificare alpha premoltiplicato e assenza di aloni nell’export.
4. Combinare livelli visibili/nascosti, opacità e ogni blend implementato; salvare, riaprire e confrontare i pixel.
5. Interrompere app durante la scrittura; riaprire file principale e recovery. Verificare che almeno l’ultima versione confermata sia valida e che l’errore sia visibile.
6. Simulare volume pieno, file oltre limite, JSON corrotto, versione futura e allocazione GPU rifiutata. Nessuna prova è soddisfatta dal solo messaggio definito nel sorgente.
7. Inviare predicted touches e poi correggerle con campioni reali; il file salvato deve contenere soltanto campioni confermati. Verificare separatamente gli aggiornamenti di proprietà stimate.
8. Eseguire cento modifiche, undo/redo ai limiti, riavvio e caricamento. La cronologia in memoria e quella non conservata dopo riapertura devono essere distinguibili e documentate.

## Confronto di riferimento e prestazioni

Acquisire numero build dell’originale, iPadOS, modello iPad/Pencil e impostazioni complete. Produrre coppie di schermate a risoluzione nativa per galleria, canvas, librerie, Studio, colore, livelli, selezioni e ogni pannello implementato. Confrontare geometria, input, chiusura, focus, errori e accessibilità, oltre ai risultati grafici. Non usare schermate di versioni diverse come prova di identità.

Per prestazioni misurare separatamente ritardo input/primo pixel, frame time medio e percentile 95, picco memoria CPU/GPU e durata save/load/export. Eseguire almeno trenta tratti per famiglia su opera piccola e grande e dieci minuti di uso continuo; registrare temperatura e pressione memoria. Il progetto non contiene valori misurati su iPad. Le dimensioni e il budget attuali sono limiti implementativi, non benchmark.

Per i formati proprietari serve un corpus autorizzato di file reali con elementi osservabili: ordine livelli, gruppi, blend, maschere, ICC, testo, frame, parametri e asset brush. Documentare separatamente ciò che si apre, ciò che viene preservato, ciò che viene convertito e ciò che viene perso. Non dichiarare round trip se è stata verificata solo decodifica.

