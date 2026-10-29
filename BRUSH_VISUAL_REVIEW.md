# Revisione visiva dei pennelli — 29 ottobre 2026

**Esito: renderer operativo e differenze osservabili; qualità completa della dotazione e parità con Procreate non dimostrate.** La tavola rende verificabile il risultato attuale, compresi i difetti residui. Il numero 192 e gli hash diversi non chiudono il requisito qualitativo dei pennelli.

## Evidenza esaminata

- [Tavola Metal dei 192 preset](docs/verification/BRUSH_COMPARISON.png), 1600×6144 pixel, esaminata visivamente in questa revisione. SHA-256: `dc1134d1f697d462596aa45551b0fd5cae3370a48f59243ff78ff87b81aee72b`.
- [Manifest dei render](docs/verification/BRUSH_RENDER_MANIFEST.json): 192 configurazioni renderizzate e 192 hash PNG distinti.
- [Risultati nativi](docs/verification/TEST_SUMMARY.json): 15 test superati, 0 falliti, 0 saltati; esecuzione del 28 ottobre 2026, 20:40:17–20:45:44 UTC. Sono 8 test renderer e 7 test del modello pennelli.
- [Report di build](docs/verification/BUILD_REPORT.json): sorgenti `5871e5dfe7a1da879806fd86e737598ec242bb3a`, [esecuzione CI 40763569979](https://github.com/Megami-Hylia/Atelier/actions/runs/40763569979).

La tavola deriva da `MetalPainter`, non da un renderer Python. Ogni cella usa lo stesso percorso sintetico di 100 campioni, dimensione 32, opacità 1, seed del tratto 42, colore sRGB `(0.16,0.35,0.65)`, su sfondo bianco. Il percorso comprende variazioni sintetiche di pressione, inclinazione, azimut e roll. La composizione finale dispone i render in quattro colonne; ogni cella ha un'immagine 400×96 e un'etichetta.

**Ambiente: iOS Simulator 26.2, modello simulato iPad (A16), architettura x86_64, su runner macOS.** Il campo `hardware: iPad` del manifest viene da `UIDevice.model` nel simulatore: non è evidenza di un iPad fisico. Nessuna Apple Pencil reale è stata usata. La build arm64 per dispositivo e la sua IPA sono artefatti separati dalle prove del simulatore.

Non sono disponibili render corrispondenti dell'app originale 5.4.14, i suoi parametri proprietari o le quattro immagini citate nella richiesta. Questa è una revisione del prodotto realizzato, non una prova di identità con il riferimento.

## Differenze visibili e limiti

| Osservazione sulla tavola | Cosa dimostra | Problema o limite residuo |
|---|---|---|
| Technical Line è una linea sottile regolare; Detail Liner è un nastro più spesso con punte; Crisp Point è una linea dura con contorno a piccoli scalini | La correzione dei tre profili non dipende soltanto da curve bloccate dal limite dimensionale | Occorrono tratti a più scale e pressioni; non è dimostrata l'equivalenza con pennini originali |
| Flat Basic appare sottile e morbido; Wide Layout è una catena molto chiara di impronte inclinate; Crisp Block è un nastro largo pieno con estremità rettangolari | I tre piatti ora producono risultati visivamente distinguibili nel percorso comune | Wide Layout è molto pallido in questo scenario; deve essere valutato per campiture, tratti brevi e rotazione Pencil |
| Binary Grain ha un deposito puntinato duro; Crisp Scatter mostra impronte angolari piene | La soglia alpha e la forma geometrica hanno un effetto visibile, coerente con i nomi corretti | Non esistono aggancio a griglia pixel né dithering cromatico; non vanno dichiarati |
| Varianti granulari, morbide, rigide, a setole e sparse sono distinguibili nella stessa famiglia | Shape, grain e dinamiche non sono soltanto nomi o controlli decorativi | Molte differenze corrispondono agli stessi dieci schemi ripetuti fra famiglie |
| I punti fini di molti set sono linee blu sottili molto simili; le varianti morbide sono onde sfumate simili; i contour sono spesso lo stesso nastro tondo pieno | Esiste una libreria comune coerente di forme e parametri | La differenziazione qualitativa di 180 pennelli individuali è ancora insufficiente;192 hash diversi non risolvono questa somiglianza |
| Dense Ink, Loaded Bristle, Studio Round e diverse varianti rake/comb presentano tessiture a pettine e silhouette affini; molti oli, paints e gouache condividono la struttura del segno | Il renderer supporta texture direzionali e deposito | La tavola non mostra una distinzione convincente fra materiali; mancano prove di miscelazione su pigmento preesistente e configurazioni specifiche per materiale |
| Graphite Foundation e Graphite Core mostrano un corpo blu morbido e relativamente pieno; Pastel Foundation e Charcoal Foundation mostrano tessiture granulari affini | Le basi richieste producono segni presenti e ripetibili | In questa prova la grafite non ha ancora un carattere convincente di mina/carta; pastello e carboncino richiedono più differenziazione della texture e del deposito |
| Basics / Soft Air appare angolare e dentellato; Classic / Soft Air Foundation è invece morbido e sfumato | La base funzionale di aerografo esiste nella raccolta separata | Il nome del preset Basics / Soft Air non descrive bene il segno mostrato: correggere il profilo o il nome nella prossima revisione, con nuova build e nuova tavola |
| Side Pastel, Charcoal Side e Ribbon Trace hanno numerose punte lineari molto evidenti; molte altre varianti azimutali hanno bordi a pettine | Il cambio di orientamento delle impronte è reale | La ripetizione dello stamp è molto riconoscibile e può apparire artificiale; da giudicare a scala reale e con rotazione più lenta/veloce |
| Le varianti colore possono mostrare anelli o fasce sature ripetute, ad esempio Tinted Ink e Color Round | La dinamica cromatica modifica realmente il colore | Alcuni nomi suggeriscono una tinta più moderata; verificare intensità, resa nelle sovrapposizioni e controllo artistico |
| Numerosi acquerelli sono molto chiari; Detail Water è una linea decisamente più carica rispetto a Water Wash/Wet Edge | Diluizione e opacità configurate incidono sulla resa | Il set non è ancora omogeneo come famiglia di materiale; la prova su bianco non dimostra diffusione, bordi bagnati o wet pickup. Non sono simulati fluidi nel tempo |

Queste sono osservazioni qualitative a una sola scala e con un solo percorso. Non costituiscono una graduatoria di tutti i preset né una misura percettiva di ogni coppia. Non sono stati inventati punteggi di somiglianza o confronti con il prodotto originale.

## Prove superate e loro portata

I test nativi hanno confrontato i pixel dello stesso documento dopo variazioni di spacing, combinazione grana/depth, taper iniziale/dimensione, pressione/curva e hue jitter. Hanno verificato replay deterministico, conservazione dei pixel dopo undo/redo e riapertura, cancellazione dell'alpha, trasporto di pigmento esistente con sfumino e assenza di una cucitura trasparente nel caso di prova a cavallo del tile 256. Questi risultati sono più forti della sola lettura dei sorgenti.

I sette test pennelli hanno verificato persistenza e round trip JSON dei parametri, seed e sorgenti PNG, rifiuto degli archivi invalidi senza modificare lo stato, operazioni di ordine e libreria, ripristino senza cancellare i pennelli personali, rollback quando la destinazione di scrittura è invalida e conservazione del file danneggiato. Non sono prove UI manuali, test di interruzione di alimentazione o simulazioni reali di disco pieno.

Restano non verificati separatamente la maggioranza dei 76 controlli, le loro interazioni estreme, l'intero spazio di forme/grane, la risposta su Pencil reale e la fedeltà alla baseline. Un cambiamento di pixel non dimostra da solo che un parametro abbia la stessa risposta del riferimento.

## Prossimi incrementi necessari, senza ridurre il perimetro

1. **Distinguere i materiali e i singoli preset.** Sostituire la predominanza dei dieci schemi comuni con profili motivati per ciascuna famiglia. Confrontare grafite verticale/inclinata, tratto tecnico, marker, pastello, carboncino, olio e acquerello a più scale; valutare texture originali più specifiche, accumulo e miscelazione. Correggere il caso Soft Air e le varianti eccessivamente pallide o cariche. La nuova revisione deve produrre una nuova IPA e nuove prove, conservando questa consegna come riferimento ripetibile.
2. **Ampliare la batteria del renderer.** Aggiungere stamp isolati, linee orizzontali/verticali/diagonali, curve strette, punti, pressione a gradini, tilt/azimut/roll isolati, velocità diverse e attraversamenti dei tile. Per il wet mix usare pigmento di almeno due colori già presente. Verificare ogni controllo della matrice con casi pertinenti, inclusi i valori estremi; non promuovere tutti i 76 controlli sulla base dei cinque gruppi di effetti già provati.
3. **Completare Brush Studio e dotazione storica.** Implementare le sottocategorie residue di `BRUSH_PARAMETERS.md`, secondo le evidenze della baseline; completare l'inventario Classic da materiale realmente osservabile e i confronti qualitativi separati. La quantità 180+12 rimane un controllo numerico, non un sostituto della copertura storica.
4. **Chiudere le prove UI, hardware e di file.** Verificare flussi biblioteca/Studio dopo riavvio reale, input Pencil compatibile e preferenze di sistema, memoria e frame time su iPad, salvataggi interrotti e formati con file di prova reali. Firma/installazione da Windows è un passaggio separato, ancora da eseguire sul dispositivo.
5. **Conservare l'intera matrice generale.** Livelli avanzati, maschere, colore e profili, selezioni, trasformazioni, assistenze, testo, regolazioni, animazione, pagine, time-lapse, pittura 3D, formati e funzioni secondarie rimangono nel perimetro di `FEATURE_PARITY.md`. La build riuscita non chiude queste voci e non autorizza a rimuoverle.

La consegna del 29 ottobre contiene un'IPA unsigned realmente compilata e verificata strutturalmente. Il sistema completo richiesto dall'utente rimane **incompleto** finché permangono le lacune funzionali, qualitative e di verifica sopra indicate.
