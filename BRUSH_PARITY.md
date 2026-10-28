# Parità del modulo pennelli — stato incompleto

Riferimento richiesto: Procreate 5.4.14. L'app originale, il suo numero build, l'hardware e le quattro immagini citate non sono disponibili in questa cartella. Il manuale corrente è evidenza documentale, non una misurazione sulla build 5.4.14. I parametri proprietari e gli algoritmi interni non sono stati osservati.

La [documentazione dell'aggiornamento 5.4](https://help.procreate.com/articles/Ls9oMu-procreate-5-4-update-at-a-glance) conferma 18 set da 10 e nuove regolazioni. Atelier contiene 180 configurazioni originali nei set richiesti e altre 12 basi funzionali, separate nella raccolta `Classic · basi funzionali`. Il generatore verifica configurazioni distinte; questo dato non dimostra una qualità equivalente né completa la dotazione storica.

| Area | Implementazione Atelier | Prova disponibile | Stato e differenza |
|---|---|---|---|
| Primo avvio offline | JSON e 12 maschere PNG inclusi nel bundle | `generate_catalog.py`, controllo conteggi e unicità eseguito su Windows | Strutturale verificata; avvio su iPad non verificato |
| Libreria a due colonne | Set a sinistra, nomi e anteprime a destra; selezione, ricerca, recenti | `BrushLibraryView.swift` | Codice presente; confronto visivo non eseguito |
| Gestione set e pennelli | Crea, duplica, rinomina, elimina, sposta, riordina con Edit | `BrushModels.swift`; test Swift predisposti | Esecuzione UI e riavvio su iPad non verificati |
| Più librerie | Creazione, selezione, rinomina, eliminazione con conservazione dei pennelli | Archivio versionato JSON | Niente sincronizzazione iCloud né collocazione in Files identica al riferimento |
| Import/export | JSON Atelier con schema 1, parametri, seed, sorgenti immagine e metadati | Validazione riferimenti/range/dimensioni e test di round trip predisposti | Formato indipendente; formati proprietari non supportati |
| Ripristino | Originali Atelier recuperabili senza eliminare i pennelli personali | `restoreFactoryPresets` e test predisposto | Non ripristina preset Procreate; reset point personali ancora mancanti |
| Brush Studio | 14 sezioni, 76 controlli collegati, area prova, annulla e salva | Matrice `BRUSH_PARAMETERS.md` | Sottofunzioni mancanti esplicite nella matrice; parità non raggiunta |
| Anteprima | Stesso `MetalPainter`/`StrokePlanner` e configurazione del canvas | `BrushPreview` | Percorso sintetico; fotografia comparativa originale non disponibile |
| Pittura, sfumino, gomma | Stesso stamp; compositing, prelievo del colore e cancellazione alpha | Sorgenti Metal | Semantica indipendente e wet mixing approssimato; hardware non verificato |
| Dual brush | Seconda impronta della stessa sorgente | Quattro controlli Atelier | Non equivale a due pennelli distinti con editor separati |
| Apple Pencil | Parametri pressione/inclinazione/azimut/roll passati al planner | Codice di input UIKit | Nessuna prova Pencil reale svolta |

## Copertura delle basi richieste, separata dai 180 preset

La fonte di queste corrispondenze è la specifica dell'utente, con organizzazione confrontata con il [manuale delle librerie](https://help.procreate.com/procreate/handbook/brushes/brush-library). Non sono corrispondenze a singoli preset proprietari. Per tutte le righe il comportamento è configurato nel nuovo motore; il confronto qualitativo e hardware è **non verificato**.

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

## Formati ed asset

`Atelier/Resources/BrushCatalog.json` conserva 192 configurazioni e seed UInt64. `scripts/generate_catalog.py` genera le configurazioni e sei forme/sei grane PNG matematiche originali. Il renderer carica queste maschere; le sorgenti importate vengono normalizzate in PNG entro 512×512. L'archivio dei pennelli conserva i byte delle sorgenti senza riferimenti a file esterni. JSON esportato/importato con limite 32 MB; immagini importate entro 8 MB. L'importazione crea nuovi identificatori per non sovrascrivere pennelli esistenti.

`.brush`, `.brushset`, `.brushlibrary`, ABR e `.procreate`: **non implementati e non verificati con file reali**. Nessuna estensione viene reinterpretata come JSON né dichiarata compatibile. Le palette e gli altri documenti appartengono alla matrice generale.

## Prove di accettazione da chiudere

1. Avvio senza rete su iPad: risorse presenti, prova applicativa ancora da eseguire.
2. Scelta nelle 18 categorie e variazione del segno sul canvas: controlli collegati, prova interattiva ancora da eseguire.
3. Tavola dei preset dallo stesso percorso nel renderer Metal: richiesta; verificare l'artefatto generato dalla suite nativa. Nessuna tavola Python sostituisce questo test.
4. Effetti di tutti i parametri: mapping dei sorgenti documentato; ogni riga mantiene stato visivo non verificato finché non esiste una prova pertinente.
5. Persistenza completa e CRUD: test Swift scritti con archivio temporaneo, da eseguire nel runner nativo; prova su iPad ancora mancante.
6. Semantica dei tre strumenti: implementata nei sorgenti, da verificare con colori sovrapposti e alpha.
7. Round trip del formato JSON indipendente: test predisposto. I formati proprietari rimangono mancanti.
8. Undo/redo e riapertura: affidabilità dipende anche dal modello documento; prova renderer e riapertura da chiudere nella matrice generale.
9. Apple Pencil reale: **non eseguito**. Input sintetico, compilazione e test simulatore non dimostrano comportamento hardware.

Il report di build e la matrice generale sono l'autorità per gli esiti di esecuzione eventualmente ottenuti dopo questa revisione. Il modulo non è dichiarato completo.
