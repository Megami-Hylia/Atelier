# Accettazione e prove

Rapporto consegna aggiornato il **29 ottobre 2026**; sorgenti, build e test CI del **28 ottobre**. La parità complessiva non è dimostrata. Il run #6 ha completato build device, packaging e 15 test sul simulatore; le prove hardware e il confronto con l’originale restano distinti.

| Criterio | Stato | Evidenza / passaggio necessario |
|---|---|---|
| A — Sorgenti e progetto completati | **incompleto** | sorgenti dell’incremento e progetto presenti; molte voci della matrice assenti o parziali |
| B — Build nativa device riuscita | **riuscita** | Release `iphoneos` arm64 nel [run #6](https://github.com/Megami-Hylia/Atelier/actions/runs/40763569979), commit `5871e5dfe7a1da879806fd86e737598ec242bb3a`; Swift e Metal compilati con Xcode 26.2/17C52, SDK 26.2 |
| C — IPA unsigned confezionata e verificata | **riuscita per il commit indicato** | `Atelier-unsigned.ipa` scaricata e ricontrollata su Windows: Mach-O device arm64, family `[2]`, shader/risorse presenti, nessuna firma/provisioning |
| D — Firma/installazione Windows | **non eseguita** | passo separato, credenziali inserite dall’utente nel programma locale |
| E — Test iPad reale e prestazioni | **non eseguiti** | nessun iPad o Apple Pencil collegato per questa consegna |
| F — Parità complessiva dimostrata | **non raggiunta** | [FEATURE_PARITY.md](FEATURE_PARITY.md) contiene lacune e confronti non svolti |

La consegna corrente è l’IPA verificata del run #6: **703.220 byte**, SHA-256 `f2d751ebae647943589f4524cca8393da98c637dfabee11b2153c62b8825f4ae`. Il `BUILD_REPORT.json` effettivo dichiara `BUILT_AND_STRUCTURALLY_VERIFIED`; i validatori rafforzati in CI e sul file scaricato in Windows confermano anche il catalogo incluso: due librerie, 18 set nuovi da dieci preset, 12 basi separate e tutte le dodici texture PNG originali. L’artefatto sostituisce le IPA dei tentativi precedenti.

Il run #6 si è concluso con successo. La diagnostica scaricata contiene `test-summary.json` con risultato **Passed: 15 test superati, zero fallimenti, zero test saltati**; `test.log` conferma otto XCTest del renderer, sette test Swift Testing dei pennelli e `TEST SUCCEEDED`. Sono test nativi di modello/rendering su **iOS Simulator 26.2 build 23C54, modello simulato iPad (A16), architettura x86_64**, con input sintetico. Non sono prove di gesture UI complete o di Apple Pencil fisica. La cronologia dei tentativi precedenti resta in [BUILD_STATUS.md](BUILD_STATUS.md).

[NATIVE_TEST_RESULTS.md](docs/NATIVE_TEST_RESULTS.md) elenca i quindici casi effettivamente eseguiti, gli allegati estratti e i limiti. La tavola grafica usa il motore Metal effettivo e contiene 192 preset con 192 hash diversi; questo non dimostra che ogni variante sia percettivamente abbastanza distinta o corrisponda a un pennello proprietario.

La build unsigned non ha richiesto segreti Apple. B/C non dimostrano D/E/F né il primo avvio offline dell’app; provano compilazione device, packaging e struttura dell’artefatto descritto.

## Accettazione del modulo pennelli

| ID | Procedura ripetibile | Risultato da registrare | Stato |
|---|---|---|---|
| BR-A01 | installazione pulita, rete disattivata, primo avvio | 18 set × 10 preset più basi separate; nessuna risorsa mancante | inclusione di catalogo/asset verificata nell’IPA run #6; primo avvio offline su app non eseguito |
| BR-A02 | selezionare almeno un preset per ogni categoria e dipingere lo stesso input | nome selezionato, canvas, differenza motivata del segno | non eseguita su app |
| BR-A03 | generare tavola dal renderer comune con input/colore/seed identici | PNG con preset annotati, parametri, versione motore e hash | eseguita su Metal nel simulatore: tavola di 192 preset e 192 hash distinti estratti da `.xcresult`; distinzione qualitativa e confronto originale ancora parziali |
| BR-A04 | per ogni controllo modificare solo un parametro, stessa traccia e seed | differenza pertinente, immagine prima/dopo e metrica | test sintetico passato per variazioni di spacing, grana, taper, pressione e hue jitter; ogni altro controllo richiede prova pertinente, non si estende il risultato a tutti i parametri |
| BR-A05 | crea → duplica → rinomina → riordina → sposta → salva → termina → riapri → reset | JSON e asset prima/dopo identici salvo cambi richiesti | test di modello passati per i casi documentati, con store ricreato da file; riavvio del processo e intero flusso UI non verificati |
| BR-A06 | dipingere campioni multicolore; sfumare; cancellare usando la stessa famiglia | sfumino trasporta colore e gomma riduce alpha; nessun tratto colore aggiunto dalla gomma | test Metal sintetico passato: alpha ridotto dalla gomma e pigmento trasportato in area trasparente; tutte le famiglie, misture complete e hardware non verificati |
| BR-A07 | esporta/importa singolo pennello, set e libreria originali; tentare file malformati | round trip, ordine, asset e parametri; rifiuti espliciti | JSON pennello round trip, libreria vuota e rifiuto dati invalidi passati nei test; copertura end-to-end di set/librerie e Files incompleta; proprietari non supportati |
| BR-A08 | tratto → undo → redo → salva → riapri → export | stesso risultato del renderer a parità di input; documentare tolleranza float | test sintetico passato con contenuti e PNG identici dopo undo/redo e ricreazione documento da file; crash/process restart e hardware non verificati |
| BR-A09 | ripetere BR-A02/04/06 con iPad e Pencil identificati | log hardware con sensori effettivi e capacità disponibili | non eseguita; input sintetico separato |

Lo stato “catalogo numericamente valido” non soddisfa BR-A02/03/04. La tavola reale ora esiste: l’esame mostra differenze fra famiglie ma anche molte varianti simili. Né configurazioni né hash diversi sostituiscono il giudizio qualitativo o il confronto con l’originale.

Nel run #6 sono passate tutte le otto prove di `AtelierTests/RendererTests.swift`:

- `testDeterministicReplayAndSpacingAffectPixels`: replica input e varia spacing, grana, taper, pressione e colore, cercando differenze nei pixel.
- `testUndoRedoReopenPreservePixelsAndParameters`: confronta contenuto e output dopo undo/redo e riapertura.
- `testEraserChangesAlphaAndSmudgeMovesExistingPigment`: misura riduzione dell’alpha e trasporto di pigmento verso una zona prima trasparente.
- `testOpaqueStrokeHasNoTransparentTileSeam`: verifica continuità opaca in tre pixel adiacenti al confine; non misura continuità della texture.
- `testCatalogComparisonFromActualMetalRenderer`: genera tavola dal motore effettivo e controlla unicità degli hash per l’input sintetico scelto.
- `testInvalidDocumentCannotReplaceCurrentState`: protegge lo stato corrente da modifiche non valide.
- `testOverBudgetStrokeIsRejectedInsteadOfSilentlyTruncated`: richiede un errore esplicito per il superamento del limite di stamp, senza dichiarare un tratto troncato come rendering completo.
- `testDuplicatingDocumentPreservesOriginalFile`: verifica che la copia di un documento non alteri il file originale.

Sono passate anche le sette prove di `BrushTests.swift`: persistenza/JSON round trip, rifiuto riferimenti e parametri invalidi, conservazione dei pennelli personali dopo ripristino, catalogo incluso, operazioni set/libreria, rollback dopo errore di scrittura simulato e conservazione dell’archivio corrotto in recovery. Il rapporto citato descrive esattamente i casi; una differenza di PNG prova un effetto ma non da sola fedeltà qualitativa o equivalenza con il riferimento.

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

