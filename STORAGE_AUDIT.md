# Review di persistenza e budget

Review dei sorgenti del **28 ottobre 2026**, esiti aggiornati il **29 ottobre** dopo il download della diagnostica. Il run #6 ha compilato l’app e superato quindici test sul simulatore; [NATIVE_TEST_RESULTS.md](docs/NATIVE_TEST_RESULTS.md) distingue i casi realmente eseguiti. Le correzioni prive di una prova pertinente rimangono verificate solo tramite lettura del codice, senza attribuirvi prove hardware.

| Caso | Problema osservato | Correzione presente / stato |
|---|---|---|
| Duplicazione opera | la modifica di nome/UUID attivava autosave sul file originale prima della copia | copia scollegata da `storageURL`; test di conservazione del file originale passato nel simulatore |
| Errori pennelli | gli errori dello store erano conservati ma non visibili nella libreria/Studio | banner/testo collegati alla UI; test di rollback dopo errore di scrittura simulato passato; visibilità UI non automatizzata |
| Allocazione GPU parziale | un fallimento dopo una o più texture lasciava un array parziale riutilizzato dal render successivo | quattro texture create in una variabile locale e assegnate insieme; cache valida solo con quattro elementi |
| Copie stamp nei tile | il budget delle texture non limitava la moltiplicazione degli stamp nei contenitori per tile | rifiuto esplicito prima di oltrepassare 262.144 copie per tratto; circa 32 MiB di payload stamp |
| Tratto oltre limite | il limite del planner poteva restituire soltanto la parte iniziale del tratto | il planner segnala l’errore e il commit conserva lo stato precedente; test passato nel simulatore |
| Livello selezionato non valido | file accettato con selezione inesistente: il modello e la preview sceglievano livelli diversi | validazione e test di rifiuto passati nel simulatore |
| Uscita dopo errore disco | il ritorno alla galleria poteva eliminare la sola copia aggiornata in memoria | salvataggio finale prima dell’uscita; in caso di errore il canvas resta aperto |

Il formato conserva l’input confermato e la configurazione del pennello dentro ogni tratto. Le predicted touches restano esterne ai campioni persistenti. Il caricamento valida prima di sostituire lo stato corrente; undo/redo conserva snapshot in memoria, non una cronologia persistente dopo riavvio.

Limiti residui verificabili:

- Il recovery dei documenti di pittura è una copia atomica precedente, non un flusso automatico collaudato dopo crash. Un test separato ha verificato la conservazione del file corrotto delle librerie pennelli, senza estendere il risultato ai documenti.
- Il limite di 384 MiB copre le quattro texture, non tutto il processo. I buffer per più tratti, i dati del documento, gli asset e gli snapshot vanno misurati insieme su iPad.
- L’esportazione raster richiede ulteriori buffer CPU. Il replay ripete tutti i tratti e attende la GPU sul percorso UI; non sono misurate prestazioni professionali.
- L’assenza di corruzione dopo crash, volume pieno o out-of-memory richiede prove di guasto reale. Non è dedotta dalla sola presenza di `Data.write(..., .atomic)`.
- Un test con input sintetico non certifica pressione, inclinazione, hover, stime e gesture su Pencil fisica.

Il perimetro ancora incompleto rimane in [FEATURE_PARITY.md](FEATURE_PARITY.md) e [NEXT_STEPS.md](NEXT_STEPS.md). Il rapporto non dichiara né il motore né la replica complessiva completati.
