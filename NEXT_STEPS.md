# Stato persistente e prossime attività

Aggiornamento consegna: **29 ottobre 2026**. L’obiettivo originale resta l’app iPad completa richiesta, con baseline 5.4.14. Questo incremento non riduce il perimetro. La matrice conserva 245 funzioni inventariate e si amplia quando emergono stati o sottofunzioni ulteriori dal confronto diretto.

## Prima dell’accettazione dell’incremento

1. La consegna corrente proviene dal [run #6](https://github.com/Megami-Hylia/Atelier/actions/runs/40763569979), commit `5871e5dfe7a1da879806fd86e737598ec242bb3a`: build device e packaging riusciti, IPA reale scaricata e verificata su Windows, B/C raggiunti. SHA-256 `f2d751ebae647943589f4524cca8393da98c637dfabee11b2153c62b8825f4ae`, dimensione 703.220 byte. Anche i test del run sono riusciti: 15/15 sul simulatore x86_64, senza fallimenti o salti. Conservare report, log, `.xcresult`, manifest e tavola estratta. Gli artefatti precedenti non sono la consegna finale.
2. La tavola reale dei 192 preset è stata generata dal motore Metal e gli hash sono distinti per l’input sintetico fissato. Completare il confronto qualitativo e le prove pertinenti per i parametri non coperti dal test di spacing/grana/taper/pressione/colore. Risolvere le somiglianze ancora visibili fra molte varianti; il conteggio e l’unicità dei pixel non chiudono il requisito qualitativo.
3. I test di modello hanno verificato persistenza con ricreazione dello store, JSON round trip, ordine, ripristino, rifiuto dati invalidi, errore di scrittura simulato e conservazione recovery delle librerie. Restano da provare i flussi UI completi, il riavvio del processo, Files reale, volume pieno e crash recovery dei documenti. Riconciliare tutti i controlli implementati con [BRUSH_PARAMETERS.md](BRUSH_PARAMETERS.md), mantenendo separati test sintetici e sensori Pencil reali.
4. Per ogni futura revisione destinata alla consegna ripetere compilazione, download e verifica dell’IPA, poi aggiornare commit/hash/report. B/C del run #6 valgono per il commit indicato. Mantenere D/E non eseguiti finché mancano firma/installazione e prove su hardware; non confondere una build riuscita con la parità complessiva.

## Priorità bloccante: sistema pennelli completo

La [revisione visiva della tavola Metal](BRUSH_VISUAL_REVIEW.md), svolta il 29 ottobre, rileva ancora molti schemi di silhouette ripetuti fra le 18 famiglie. Correggere anzitutto il preset **Basics / Soft Air**, che nella tavola ha un segno angolare e dentellato, e migliorare il carattere di **Graphite Foundation**, che in questa prova appare come un corpo blu morbido anziché una grafite convincente. Distinguere oli, paints, gouache, pastello e carboncino con prove su pigmento preesistente e percorsi multipli. La base Classic / Soft Air Foundation ha invece un segno morbido: non confondere i due preset. I 192 hash distinti e i test riusciti non chiudono questi difetti qualitativi. Le correzioni sono attività future: la sorgente compilata `5871e5d` e l'IPA consegnata restano immutate.

Acquisire le quattro schermate citate e identificare i singoli pennelli Classic/base effettivamente presenti nel riferimento 5.4.14. I dodici equivalenti originali non coprono l’intera libreria storica. Mantenere distinto il catalogo moderno di 180 preset e il censimento storico. Non inventare corrispondenze proprietarie.

Completare tutti i sottoparametri ancora mancanti, le curve con nodi, le sorgenti importabili/editabili, filtri e blend completi, dinamiche secondario/pressione/inclinazione/roll, materiali e metadati. Portare il dual brush a due configurazioni indipendenti; migliorare wet mix e sfumino con campionamento progressivo, riportando comunque le differenze dal comportamento osservato. Completare la gestione Files/iCloud se richiesta dalla baseline, senza fare dipendere il primo avvio dalla rete.

Misurare la tavola dei preset con il medesimo tracciato e assicurare differenze riconoscibili per matite, inchiostri, calligrafia, marker, aerografo, pastelli, carboncino, secco, olio e acquerello. Validare su Pencil reale tutti i segnali disponibili; verificare fallback quando mancano hover, squeeze o roll.

## Motore, dati e interfaccia

Evolvere il dispatch per tile in un sistema con cache/budget e aggiornamenti incrementali, evitando il replay integrale sul thread UI. Verificare giunti e campionamento ai bordi. Introdurre gestione completa gruppi/maschere/blend e profili colore, crash recovery verificato, errori disco/memoria e undo coerente per tutte le operazioni. Misurare memoria e latenza su hardware identificato prima di aumentare limiti canvas/livelli.

Congelare il riferimento con build, iPadOS, iPad e Pencil. Confrontare schermate e gesture a parità di risoluzione. La UI attuale non può essere dichiarata identica senza queste prove. Completare accessibilità e tutte le preferenze, incluse quelle secondarie inventariate.

## Perimetro ancora da implementare, senza esclusioni

- Galleria professionale, pile e operazioni multiple; preset canvas completi, ritaglio, ricampionamento, statistiche e profili.
- Gruppi/livelli multipli, alpha lock, maschere, clipping, reference, merge/flatten e tutti i blend.
- Tutti i selettori colore, armonie, palette, storia, ColorDrop, riempimenti consecutivi, contagocce e gestione ICC/P3/CMYK.
- Selezioni automatiche/libere/poligonali/geometriche, combinazioni, feather e salvataggi; trasformazioni libere/uniformi/distorsione/warp, snapping e interpolazione.
- Guide, prospettiva, simmetria, assistenza e QuickShape; riferimento, display esterno e funzioni volto compatibili.
- Testo editabile, font, stili, spaziature, contorno e rasterizzazione.
- Ogni regolazione colore ed effetto, tutte le modalità Liquify, clone e applicazione livello/Pencil.
- Animazione completa, import video/export animato, pagine e PDF multipagina, time-lapse persistente/export.
- Pittura 3D OBJ/USDZ, UV/materiali/cuciture, livelli, luci, ambienti, export e AR.
- QuickMenu, personalizzazione gesture/tastiera, clipboard, drag and drop, Scribble, accessibilità, anteprime/widget e opzioni di sistema.
- Formati immagini, PSD con livelli, PDF, animazioni, video, modelli, palette e compatibilità reale con `.procreate`, `.brush`, `.brushset`, `.brushlibrary`, ABR.

Ogni punto va suddiviso in incrementi compilabili e prove pertinenti, aggiornando la matrice. Il lavoro termina soltanto quando tutte le voci richieste sono implementate e verificate, non quando finisce l’elenco dei sorgenti di questo incremento.

