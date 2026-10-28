# Review di persistenza e budget

Review dei sorgenti eseguita il **28 ottobre 2026**. I problemi sotto sono stati individuati tramite percorsi di codice concreti. Lo stato “corretto nei sorgenti” non indica compilazione o prova hardware riuscita; i risultati nativi saranno registrati dalla CI.

| Caso | Problema osservato | Correzione presente / stato |
|---|---|---|
| Duplicazione opera | la modifica di nome/UUID attivava autosave sul file originale prima della copia | la copia scollega `storageURL` prima della modifica; test di conservazione del file originale predisposto |
| Errori pennelli | gli errori dello store erano conservati ma non visibili nella libreria/Studio | banner/testo di errore collegati alla UI; rollback allo stato persistito se la scrittura fallisce |
| Allocazione GPU parziale | un fallimento dopo una o più texture lasciava un array parziale riutilizzato dal render successivo | quattro texture create in una variabile locale e assegnate insieme; cache valida solo con quattro elementi |
| Copie stamp nei tile | il budget delle texture non limitava la moltiplicazione degli stamp nei contenitori per tile | rifiuto esplicito prima di oltrepassare 262.144 copie per tratto; circa 32 MiB di payload stamp |
| Tratto oltre limite | il limite del planner poteva restituire soltanto la parte iniziale del tratto | il planner ora segnala superamento dei centomila stamp; test di rifiuto predisposto |
| Livello selezionato non valido | file accettato con selezione inesistente: il modello e la preview sceglievano livelli diversi | la validazione rifiuta riferimenti a livelli assenti |
| Uscita dopo errore disco | il ritorno alla galleria poteva eliminare la sola copia aggiornata in memoria | salvataggio finale prima dell’uscita; in caso di errore il canvas resta aperto |

Il formato conserva l’input confermato e la configurazione del pennello dentro ogni tratto. Le predicted touches restano esterne ai campioni persistenti. Il caricamento valida prima di sostituire lo stato corrente; undo/redo conserva snapshot in memoria, non una cronologia persistente dopo riavvio.

Limiti residui verificabili:

- Il recovery è una copia atomica precedente, non un flusso automatico di recupero già collaudato.
- Il limite di 384 MiB copre le quattro texture, non tutto il processo. I buffer per più tratti, i dati del documento, gli asset e gli snapshot vanno misurati insieme su iPad.
- L’esportazione raster richiede ulteriori buffer CPU. Il replay ripete tutti i tratti e attende la GPU sul percorso UI; non sono misurate prestazioni professionali.
- L’assenza di corruzione dopo crash, volume pieno o out-of-memory richiede prove di guasto reale. Non è dedotta dalla sola presenza di `Data.write(..., .atomic)`.
- Un test con input sintetico non certifica pressione, inclinazione, hover, stime e gesture su Pencil fisica.

Il perimetro ancora incompleto rimane in [FEATURE_PARITY.md](FEATURE_PARITY.md) e [NEXT_STEPS.md](NEXT_STEPS.md). Il rapporto non dichiara né il motore né la replica complessiva completati.
