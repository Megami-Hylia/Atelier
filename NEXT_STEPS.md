# Stato persistente e prossime attività

L’obiettivo originale resta l’app iPad completa richiesta, con baseline 5.4.14. Questo incremento non riduce il perimetro. La matrice conserva 245 funzioni inventariate e si amplia quando emergono stati o sottofunzioni ulteriori dal confronto diretto.

## Prima dell’accettazione dell’incremento

1. Il repository GitHub privato autorizzato [Megami-Hylia/Atelier](https://github.com/Megami-Hylia/Atelier) è stato creato e la CI avviata. Acquisire l’esito del workflow macOS da Windows seguendo [README_WINDOWS.md](README_WINDOWS.md); correggere ogni errore Swift/Metal/Xcode prima di produrre l’IPA. Non servono Apple ID o certificati per questa build.
2. Eseguire i test di modello e il rendering comparativo reale su Metal. Generare la tavola preset e le prove per parametro; registrare commit e hash. Risolvere somiglianze e parametri inefficaci invece di contare soltanto i nomi.
3. Verificare librerie/set/pennelli con salvataggio, riavvio, import/export, errori di dati e disco. Riconciliare tutti i controlli implementati con [BRUSH_PARAMETERS.md](BRUSH_PARAMETERS.md).
4. Verificare il bundle device e il packaging unsigned; scaricare `Atelier-unsigned.ipa` e rapporto CI. Aggiornare separatamente B/C in [ACCEPTANCE.md](ACCEPTANCE.md), mantenendo D/E non eseguiti finché manca hardware/installazione.

## Priorità bloccante: sistema pennelli completo

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

