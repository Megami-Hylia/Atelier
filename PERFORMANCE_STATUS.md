# Rallentamento progressivo durante il disegno

## Cause individuate nel codice

Il tratto attivo veniva ripianificato e ridisegnato dall’inizio a ogni frame. Il costo di planner, assegnazione ai tile e shader cresceva con tutti i punti già raccolti. Copie dell’array dei campioni venivano fatte durante append e previsione. Sorgenti forma/grana importate erano decodificate di nuovo e il salvataggio serializzava il documento sul main actor.

## Correzioni nei sorgenti

- Cursore di pianificazione incrementale a stato costante: conserva filtro, distanza e generatore casuale senza conservare l’array crescente.
- Superficie Metal persistente per il tratto attivo. Si aggiungono le nuove impronte, usando sempre lo sfondo precedente al tratto per il pickup di gomma/sfumino/impasto.
- Al massimo 32 nuovi campioni consolidati per frame; i frame successivi drenano gli arretrati senza eliminare punti. Solo la coda con stime Pencil ancora in attesa (al massimo 32 campioni) è riprodotta provvisoriamente; senza stime pendenti tutti i campioni nuovi vengono consolidati subito. Previsioni e coda provvisoria non entrano nella superficie permanente.
- Correzioni a campioni già consolidati invalidano il cursore per correttezza; la ricostruzione viene comunque suddivisa in frame.
- Append dei campioni in posizione, senza copiare l’intero tratto per aggiungere le previsioni.
- Il livello selezionato usa la revisione del documento durante il disegno e, quando viene aggiunto un tratto, riusa lo storico già renderizzato.
- Dispatch GPU limitato al rettangolo interessato dalle impronte in ciascun tile, anziché sempre 256×256 pixel.
- Cache delle sorgenti importate e incluse: fino a 64 texture / 32 MiB.
- Autosave su coda seriale separata, accorpato dopo 350 ms; il salvataggio esplicito attende le scritture precedenti e non può essere sovrascritto da un autosave obsoleto.

I nuovi tratti sono marcati `distanceDynamicsVersion: 1`: taper iniziale, attenuazione e carica dipendono da una distanza stabile rispetto alla dimensione del pennello. Questo permette di non modificare retroattivamente l’inizio del tratto mentre la linea si allunga. Gli archivi precedenti, senza questo campo, mantengono integralmente il vecchio planner; il corpo della funzione legacy è stato confrontato automaticamente con quello di 42bdbbb.

## Verifica e limiti

Il controllo sintattico dei 24 file Swift e il confronto del planner legacy sono passati. Sono presenti otto nuovi test nativi per confronto batch/incrementale dei 192 preset, tratti lunghi, burst di input, correzioni Pencil, gomma/sfumino, previsioni, append dello storico e ordinamento dei salvataggi. Non sono stati eseguiti: GitHub non ha avviato il runner per un problema di pagamento o limite di spesa dell’account (run 40884039887, zero step).

Non sono disponibili nuova compilazione, IPA con queste correzioni, tempi GPU o misure su iPad. I precedenti test 22/22 non attestano queste modifiche. L’IPA presente nella cartella resta quella di 9360611 e non contiene il nuovo motore.

La superficie aggiuntiva viene usata solo entro il budget di lavoro di 384 MiB. Per documenti molto grandi (quando sei superfici RGBA16 superano il budget) resta il replay tradizionale. I livelli non selezionati e le regolazioni possono ancora comportare replay e filtri completi. Il numero di campioni per frame non garantisce un tempo GPU fisso: dimensioni, distanza tra punti, conteggio, densità e impasto del pennello incidono ancora sul costo. Nessuna promessa di FPS o eliminazione totale del lag senza prova sull’hardware.
