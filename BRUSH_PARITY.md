# Parità del modulo pennelli — stato incompleto

Riferimento richiesto: Procreate 5.4.14. L'app originale, il suo numero build, l'hardware e le quattro immagini citate non sono disponibili in questa cartella. Il manuale corrente è evidenza documentale, non una misurazione sulla build 5.4.14. I parametri proprietari e gli algoritmi interni non sono stati osservati.

La [documentazione dell'aggiornamento 5.4](https://help.procreate.com/articles/Ls9oMu-procreate-5-4-update-at-a-glance) conferma 18 set da 10 e nuove regolazioni. Atelier contiene 180 configurazioni originali nei set richiesti e altre 12 basi funzionali, separate nella raccolta `Classic · basi funzionali`. Il generatore verifica configurazioni distinte; questo dato non dimostra una qualità equivalente né completa la dotazione storica.

Aggiornamento del **29 ottobre 2026**: il [run nativo del 28 ottobre](https://github.com/Megami-Hylia/Atelier/actions/runs/40763569979), sorgenti `5871e5dfe7a1da879806fd86e737598ec242bb3a`, ha superato 15 test sul simulatore iPad (A16), iOS 26.2, x86_64. La [tavola Metal dei 192 preset](docs/verification/BRUSH_COMPARISON.png) è stata generata ed esaminata: esistono differenze reali, ma anche somiglianze e difetti qualitativi ancora bloccanti, descritti in [BRUSH_VISUAL_REVIEW.md](BRUSH_VISUAL_REVIEW.md). Nessun test è stato eseguito su iPad fisico o Pencil reale.

| Area | Implementazione Atelier | Prova disponibile | Stato e differenza |
|---|---|---|---|
| Primo avvio offline | JSON e 12 maschere PNG inclusi nel bundle | `generate_catalog.py`, controllo conteggi e unicità eseguito su Windows | Strutturale verificata; avvio su iPad non verificato |
| Libreria a due colonne | Set a sinistra, nomi e anteprime a destra; selezione, ricerca, recenti | `BrushLibraryView.swift` | Codice presente; confronto visivo non eseguito |
| Gestione set e pennelli | Crea, duplica, rinomina, elimina, sposta, riordina con Edit | Test del modello superati, inclusi ordine e gestione libreria | Esecuzione UI e riavvio del processo su iPad non verificati |
| Più librerie | Creazione, selezione, rinomina, eliminazione con conservazione dei pennelli | Archivio versionato JSON | Niente sincronizzazione iCloud né collocazione in Files identica al riferimento |
| Import/export | JSON Atelier con schema 1, parametri, seed, sorgenti immagine e metadati | Test di round trip e rifiuto dati invalidi superati nel simulatore | Formato indipendente; formati proprietari non supportati |
| Ripristino | Originali Atelier recuperabili senza eliminare i pennelli personali | Test di ripristino e conservazione dei personali superato | Non ripristina preset Procreate; reset point personali ancora mancanti |
| Brush Studio | 14 sezioni, 76 controlli collegati, area prova, annulla e salva | Matrice `BRUSH_PARAMETERS.md` | Sottofunzioni mancanti esplicite nella matrice; parità non raggiunta |
| Anteprima | Stesso `MetalPainter`/`StrokePlanner` e configurazione del canvas | Tavola reale dei 192 render e manifest; 192 hash distinti | Percorso sintetico; qualità completa e confronto originale non dimostrati |
| Pittura, sfumino, gomma | Stesso stamp; compositing, prelievo del colore e cancellazione alpha | Test Metal di cancellazione alpha e trasporto del pigmento superato | Semantica indipendente e wet mixing approssimato; hardware non verificato |
| Dual brush | Seconda impronta della stessa sorgente | Quattro controlli Atelier | Non equivale a due pennelli distinti con editor separati |
| Apple Pencil | Parametri pressione/inclinazione/azimut/roll passati al planner | Codice di input UIKit | Nessuna prova Pencil reale svolta |

## Copertura delle basi richieste, separata dai 180 preset

La fonte di queste corrispondenze è la specifica dell'utente, con organizzazione confrontata con il [manuale delle librerie](https://help.procreate.com/procreate/handbook/brushes/brush-library). Non sono corrispondenze a singoli preset proprietari. I segni sono visibili nella tavola e sono stati esaminati; il confronto qualitativo con il riferimento e le prove hardware rimangono **non verificati**. La revisione visiva segnala, fra gli altri, il carattere ancora poco convincente della grafite e la somiglianza fra materiali.

| Funzione richiesta | Preset originale Atelier | Segno atteso dalla configurazione | Differenza residua |
|---|---|---|---|
| Grafite | Graphite Foundation | Deposito poco carico con grana carta e alpha da pressione | Mancano prove comparative |
| Matita inclinata | Tilt Shader Foundation | Allargamento e schiacciamento con inclinazione e azimut | Calibrazione Pencil non svolta |
| Penna inchiostro | Ink Foundation | Impronta circolare fitta, diametro da pressione, punta finale | Curva indipendente |
| Pennino calligrafico | Calligraphy Foundation | Impronta schiacciata orientata da azimut/roll | Nessuna corrispondenza a un nib proprietario |
| Marker piatto | Flat Marker Foundation | Deposito traslucido rettangolare | Saturazione/accumulo indipendenti |
| Aerografo | Soft Air Foundation | Impronta morbida a basso flusso | Modello analitico indipendente |
| Pennello duro | Hard Round Foundation | Campitura circolare compatta | Nessun filtro proprietario |
| Pastello | Pastel Foundation | Grana ruvida e impronta frammentata | Texture matematica originale |
| Carboncino | Charcoal Foundation | Maschera granulosa e segno largo inclinando | Texture matematica originale |
| Pennello secco | Dry Bristle Foundation | Setole separate e grana tela pronunciata | Nessuna simulazione fisica delle setole |
| Olio | Oil Foundation | Setole cariche con prelievo del colore preesistente | Nessun impasto volumetrico; wet mix semplificato |
| Acquerello | Watercolor Foundation | Deposito diluito, maschera wash e pigmento che si esaurisce | Nessuna diffusione fisica nel tempo |

L'inventario dei singoli pennelli Classic originali non è stato osservato: resta da completare e confrontare. Queste 12 basi non sono presentate come tutta la libreria Classic.

## Revisione qualitativa delle configurazioni

Un controllo dei parametri ha individuato profili troppo simili prima del confronto visivo: alcune differenze di curva erano annullate dal limite del diametro, mentre la scala della grana non aveva effetto quando la grana era assente. I profili seguenti sono stati corretti mantenendo gli identificatori. La tabella descrive differenze effettivamente configurate, **non un'osservazione delle immagini risultanti**.

| ID stabile | Nome attuale | Differenziazione configurata |
|---|---|---|
| `atelier-basics-07` | Flat Basic | Forma piatta con rapporto 0,65, spessore sensibile alla pressione e deposito progressivo |
| `atelier-design-07` | Wide Layout | Forma piatta stretta con rapporto 0,28, orientamento da azimut/roll, allargamento da tilt e passo più ampio |
| `atelier-digital-07` | Crisp Block | Rettangolo pieno con rapporto 1, dimensione costante e soglia alpha 0,45 |
| `atelier-pens-03` | Technical Line | Punta rotonda fine costante, nessuna rastremazione; diametro minimo e massimo 0,13 |
| `atelier-comics-03` | Detail Liner | Pressione sul diametro con peso 1, massimo 0,65, punta finale lunga e variazione di alpha/flusso |
| `atelier-digital-03` | Crisp Point | Piccole impronte rettangolari dure, dimensione 0,20 costante, passo 0,45 e alpha binario |
| `atelier-digital-01` | Crisp Round | Punta rotonda con soglia alpha 0,50; nome corretto per non promettere un motore pixel a griglia |
| `atelier-digital-05` | Binary Grain | Grana frammentata e alpha binario; nessuna promessa di dithering cromatico |
| `atelier-digital-09` | Crisp Scatter | Spruzzi di rettangoli duri con alpha binario, dimensione costante e posizionamento casuale ripetibile |
| `atelier-watercolors-09` | Water Mist | Rinomina coerente con gli spruzzi effettivamente configurati; nessuna diffusione bloom simulata |

Il generatore controlla ora anche queste proprietà progettuali, oltre a conteggio e unicità delle configurazioni. I nomi dei preset Digital non promettono una griglia pixel, che non è implementata. La tavola Metal è ora disponibile e conferma differenze fra i profili corretti; la [revisione delle famiglie](BRUSH_VISUAL_REVIEW.md) rileva ancora molti schemi comuni. L'unicità degli hash non costituisce una verifica qualitativa completa dei 192 pennelli. Le prove Pencil restano da eseguire.

## Formati ed asset

`Atelier/Resources/BrushCatalog.json` conserva 192 configurazioni e seed UInt64. `scripts/generate_catalog.py` genera le configurazioni e sei forme/sei grane PNG matematiche originali. Il renderer carica queste maschere; le sorgenti importate vengono normalizzate in PNG entro 512×512. L'archivio dei pennelli conserva i byte delle sorgenti senza riferimenti a file esterni. JSON esportato/importato con limite 32 MB; immagini importate entro 8 MB. L'importazione crea nuovi identificatori per non sovrascrivere pennelli esistenti.

`.brush`, `.brushset`, `.brushlibrary`, ABR e `.procreate`: **non implementati e non verificati con file reali**. Nessuna estensione viene reinterpretata come JSON né dichiarata compatibile. Le palette e gli altri documenti appartengono alla matrice generale.

## Prove di accettazione da chiudere

1. Avvio senza rete su iPad: risorse presenti, prova applicativa ancora da eseguire.
2. Scelta nelle 18 categorie e variazione del segno sul canvas: controlli collegati, prova interattiva ancora da eseguire.
3. Tavola dei preset dallo stesso percorso nel renderer Metal: **generata** dal test nativo, 192 render e hash distinti. Revisione visiva svolta; differenziazione qualitativa completa e parità ancora mancanti.
4. Effetti dei parametri: test pixel superati per spacing e hue jitter isolati, più combinazioni grana/depth, taper iniziale/dimensione e pressione/curva. Non sono prove isolate di tutti i valori: vedi `BRUSH_PARAMETERS.md`. La maggioranza dei controlli e tutte le equivalenze restano non verificate.
5. Persistenza e CRUD: sette test del modello superati, inclusi ordine, ripristino, rollback su destinazione invalida e conservazione recovery; flussi UI e riavvio reale su iPad ancora mancanti.
6. Semantica dei tre strumenti: test sintetico Metal superato per pittura, cancellazione alpha e trasporto di colore con sfumino. Miscelazione realistica e comportamento hardware non dimostrati.
7. Round trip del formato JSON indipendente: **test superato** nel simulatore. Files reale e formati proprietari rimangono mancanti/non verificati.
8. Undo/redo e riapertura: **test di identità dei pixel e configurazioni superato** nel simulatore. Non dimostra recupero dopo arresto, disco pieno o affidabilità su hardware.
9. Apple Pencil reale: **non eseguito**. Input sintetico, compilazione e test simulatore non dimostrano comportamento hardware.

Il report di build e la matrice generale sono l'autorità per gli esiti di esecuzione eventualmente ottenuti dopo questa revisione. Il modulo non è dichiarato completo.
