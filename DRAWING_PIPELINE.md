# Acquisizione e rendering dei tratti

Un gesto continua a creare un solo `PaintStroke`, salvato e annullabile come unità. Le impronte `GPUStamp` restano un dettaglio temporaneo del motore Metal: servono a forma, grana, pressione, gomma e pennelli combinati; non sono oggetti separati nel documento.

## Problema e soluzione

L'acquisizione conservava quasi tutti i tocchi coalescenti. Il planner li collegava con segmenti e il filtro dipendeva dalla densità degli eventi. Molti campioni vicini, previsioni e stime ancora instabili aggiungevano lavoro senza dettaglio visibile. Anche i livelli non selezionati venivano riprodotti durante i frame successivi.

- `StrokeInputSampler` conserva campioni distanti circa 0,25–0,35 punti sullo schermo, adattando la soglia alla velocità e allo zoom. Conserva anche variazioni significative di pressione, inclinazione e orientamento, oltre all'estremo finale. Una penna ferma con attributi invariati non fa crescere l'array.
- `StrokeTrajectory` usa un filtro dipendente da tempo e velocità, seguito da cubiche con un campione di anticipo. La coda viene mostrata provvisoriamente nello stesso frame: il lookahead non richiede di aspettare prima di visualizzare il movimento. Gli angoli intenzionali interrompono la tangente; le curve sono approssimate con errore subpixel, senza oltrepassare gli estremi locali.
- Il controllo in **Azioni → Pref. → Stabilizzazione tratto** va da 0 a 100%. Si combina con la stabilizzazione del preset senza applicare due filtri consecutivi. I movimenti rapidi hanno una risposta più diretta.
- Il planner incrementale conserva distanza, filtro e stato casuale. Le impronte sono distribuite lungo la curva; pressione, inclinazione e angoli variano per interpolazione. I pennelli combinati usano il tempo relativo del gesto per mantenere l'ordine tra componenti anche con filtri diversi.
- `PencilCanvas` richiede rendering al ritmo del display, con un solo frame GPU in volo. Il display link si ferma quando non ci sono modifiche. Il planner consolida al massimo 32 nuovi campioni per frame; previsioni e stime provvisorie rimangono separate dall'inchiostro definitivo.
- Al rilascio, una semplificazione conservativa rimuove punti ridondanti preservando angoli, attributi e indici con correzioni Pencil pendenti. Il risultato viene confrontato con la traiettoria filtrata di ogni componente. Per pennelli sensibili a velocità/pickup o sfumino si conserva la sequenza già campionata.
- I raster dei livelli storici hanno una cache limitata a quattro livelli e 32 MiB, condividendo il budget di lavoro di 384 MiB con le superfici del tratto attivo. Le regolazioni si applicano dopo il raster conservato. Revisioni, modifiche ai livelli e cambio documento invalidano correttamente la cache.

## Compatibilità e verifica

I nuovi tratti hanno `curveVersion: 1`, scala di acquisizione e stabilizzazione salvate. I campi sono opzionali: i documenti precedenti continuano a usare il planner originale. Identità del tratto, livelli, gomma, annulla/ripristina e formato JSON restano gli stessi.

I test coprono densità alle diverse scale, duplicati, angoli, dettagli piccoli, pressione/inclinazione, tocchi singoli, tratti brevi/rapidi, previsioni, pacchetti di dimensioni diverse, pennelli combinati e cache con 200 tratti storici. Stato della compilazione e risultati nativi: `CURRENT_BUILD.md`.

Le verifiche automatiche non misurano la latenza su un iPad fisico. Il costo GPU dipende ancora da dimensioni della tela e del pennello, densità e filtri; non viene dichiarato un FPS garantito su iPad 9.
