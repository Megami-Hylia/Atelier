# Riferimento e limiti dell’evidenza

Data di ricerca: **28 ottobre 2026**. La baseline richiesta resta **Procreate 5.4.14**. Il sito pubblico corrente può cambiare e non espone una revisione congelata per questa build: ogni differenza va ricontrollata contro l’app originale prima di essere dichiarata parità.

| Elemento | Evidenza disponibile | Stato |
|---|---|---|
| Versione di riferimento | 5.4.14 indicata dalla specifica utente | richiesta, non osservata |
| Numero build Procreate | non fornito | da acquisire dal riferimento |
| iPadOS | non fornito | da acquisire |
| Modello iPad | non fornito | da acquisire |
| Apple Pencil | non fornita generazione/modello | da acquisire |
| Progetto precedente | cartella iniziale priva di sorgenti e repository Git | nessun progetto da analizzare |
| Quattro schermate citate | non presenti tra i file disponibili a questo incarico | non esaminate |
| Registrazioni/runtime originale | non disponibili | nessun confronto diretto eseguito |
| File di prova proprietari | assenti | nessuna compatibilità certificata |
| Video indicato | [YouTube](https://www.youtube.com/watch?v=HW7M_jlWNcg) | recupero fallito; nessuna scena o timestamp usato |
| Specifica testuale | allegato “Testo incollato.txt” | letta integralmente |

Il manuale descrive il comportamento pubblico. Non fornisce il codice del renderer o i parametri interni dei pennelli proprietari. Il motore Atelier, i preset e le texture sono implementazioni indipendenti; i nomi delle categorie servono al confronto funzionale. Non sono stati ricavati algoritmi proprietari mediante reverse engineering perché non sono disponibili binari o runtime da interrogare.

Le 104 pagine collegate dall’indice del manuale sono state recuperate via HTTP per inventariare capitoli e sottocapitoli. [MANUAL_INDEX.md](docs/MANUAL_INDEX.md) riporta URL e stato; [manual_sources.json](docs/manual_sources.json) contiene titolo, estratto dei titoli e SHA-256 della risposta HTML. Questo prova la consultazione documentale, non l’osservazione dei gesti né la corrispondenza con la build richiesta. Non si conservano i testi integrali degli articoli nel progetto.

Fonti principali:

- [Manuale ufficiale e indice](https://help.procreate.com/procreate/handbook/introduction): struttura pubblica degli ambiti e dei capitoli; tutti rimangono nel perimetro.
- [Librerie pennelli](https://help.procreate.com/procreate/handbook/brushes/brush-library): organizzazione di raccolte/set, ricerca, recenti e raccolta storica. La Classic Library comprende diciotto categorie, inclusi Organic e Water: dodici basi funzionali di Atelier sono una copertura iniziale distinta, non l’inventario completo dei pennelli storici.
- [Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings): quattordici sezioni; il dettaglio di controlli collegati e mancanti è in [BRUSH_PARAMETERS.md](BRUSH_PARAMETERS.md). La presenza del controllo non prova equivalenza numerica o visiva.
- [Novità 5.4](https://help.procreate.com/articles/Ls9oMu-procreate-5-4-update-at-a-glance): documenta la nuova dotazione di 180 pennelli e le aggiunte allo Studio richieste dalla specifica. Non fornisce un archivio dei parametri originali.
- [Tipi di file](https://help.procreate.com/procreate/handbook/gallery/gallery-file-types): inventario dei formati; l’elenco di supporto del riferimento non viene attribuito ad Atelier.
- [Preferenze](https://help.procreate.com/procreate/handbook/actions/actions-preferences), [accessibilità](https://help.procreate.com/procreate/handbook/interface-gestures/accessibility) e [gesti](https://help.procreate.com/procreate/handbook/interface-gestures/gestures): opzioni secondarie da conservare nella matrice e verificare singolarmente.

Per ottenere una baseline comparabile servono catture e registrazioni della versione richiesta, nelle stesse condizioni di dispositivo/orientamento, e un corpus autorizzato di opere, pennelli e palette. I dati da acquisire sono riportati qui per consentire il confronto successivo; lo sviluppo locale e la build unsigned non richiedono credenziali Apple.

