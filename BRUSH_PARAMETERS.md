# Matrice dei parametri pennello

Revisione 29 ottobre 2026, con esiti dei test del 28 ottobre. Baseline richiesta: Procreate 5.4.14, build non osservata. Il [manuale ufficiale corrente di Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings) è stato consultato per titoli e inventario; non sostituisce una verifica diretta della build richiesta.

I 14 titoli delle sezioni sono mantenuti nel pannello: Stroke Path, Stabilization, Taper, Shape, Grain, Rendering, Wet Mix, Color Dynamics, Dynamics, Apple Pencil, Properties, Materials, Preview, About this Brush. Le diciture con `Atelier` e `exponent` identificano esplicitamente opzioni o rappresentazioni indipendenti. In particolare la curva di pressione è un esponente, non l'editor multipunto dell'originale.

## Stato delle prove

**NV** = collegamento nel sorgente identificato, effetto isolato non verificato. **SYN** = differenza di pixel verificata con una singola chiave modificata nel test sintetico. **GRUPPO-SYN** = differenza verificata modificando insieme le chiavi o la sorgente indicata; non è una prova isolata della singola chiave. La parità con il riferimento, la risposta hardware e la verifica completa del dominio di tutti i 76 parametri restano non dimostrate, anche per le righe SYN.

Il [run nativo 40763569979](https://github.com/Megami-Hylia/Atelier/actions/runs/40763569979), sorgenti `5871e5dfe7a1da879806fd86e737598ec242bb3a`, ha superato 15 test su iOS Simulator 26.2 x86_64, senza fallimenti o salti. Il test `testDeterministicReplayAndSpacingAffectPixels` modifica spacing e hue jitter separatamente; modifica invece grana insieme a depth, taper iniziale insieme alla dimensione del taper, e pressure size insieme alla curva. Non estendere l'esito a tutti i sottoparametri della categoria. La [tavola reale](docs/verification/BRUSH_COMPARISON.png) e la [revisione qualitativa](BRUSH_VISUAL_REVIEW.md) sono disponibili; non costituiscono prove Pencil né confronto con l'app originale.

Ogni controllo elencato scrive la propria chiave nel preset e ha un collegamento al planner o all'anteprima. Il controllo statico delle chiavi non dimostra da solo un effetto pertinente in tutti i contesti. Quattro parametri modificano solo l'anteprima, secondo il loro scopo. La maggioranza dei controlli rimane NV.

`BrushParameter.all` è la fonte dei limiti UI e di validazione. Tutti i 76 valori sono persistiti nel dizionario JSON. I preset includono inoltre forma, grana, seed e sorgenti PNG opzionali. Forme e grane sono originali. I controlli binari sono switch; conteggio e modalità sono discreti. L'area prova usa il medesimo `CanvasSurface` del documento. La bozza viene scartata con Annulla e confermata con Salva; la duplicazione in Studio resta una bozza finché non si salva. Le vecchie pennellate dell'area prova conservano i parametri con cui sono state create.

## Controlli collegati

I limiti sono normalizzati Atelier; non sono i valori interni proprietari. Le descrizioni seguenti riguardano la nuova implementazione.

| Sezione | Controllo | Chiave persistita | Intervallo; default | Effetto implementato | Collegamento | Prova |
|---|---|---|---|---|---|---|
| Stroke Path | Spacing | `spacing` | 0.01…2; 0.08 | Distanza fra le impronte in proporzione al diametro. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN: spacing isolato |
| Stroke Path | Spacing Jitter | `spacingJitter` | 0…1; 0 | Variazione ripetibile della distanza fra impronte. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Stroke Path | Jitter Lateral | `jitterLateral` | 0…1; 0 | Spostamento perpendicolare al percorso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Stroke Path | Jitter Linear | `jitterLinear` | 0…1; 0 | Spostamento lungo il percorso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Stroke Path | Fall Off | `fallOff` | 0…1; 0 | Riduzione del deposito con la lunghezza del tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Stabilization | StreamLine Amount | `streamline` | 0…1; 0 | Filtraggio delle posizioni in ingresso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Stabilization | StreamLine Pressure | `pressureSmoothing` | 0…1; 0 | Filtraggio della pressione fra campioni. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Stabilization | Stabilization Amount | `stabilization` | 0…1; 0 | Media delle posizioni durante il tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Stabilization | Motion Filtering Amount | `motionFiltering` | 0…1; 0 | Ulteriore attenuazione delle deviazioni. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Stabilization | Motion Filtering Expression | `motionExpression` | 0…1; 0 | Recupero di una parte del movimento originale. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Taper | Start | `taperStart` | 0…1; 0 | Lunghezza relativa della punta iniziale. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | GRUPPO-SYN: start + size |
| Taper | End | `taperEnd` | 0…1; 0 | Lunghezza relativa della punta finale; aggiornata a fine tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Taper | Size | `taperSize` | 0…1; 1 | Riduzione del diametro alle estremità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | GRUPPO-SYN: start + size |
| Taper | Opacity | `taperOpacity` | 0…1; 0 | Riduzione dell'alpha alle estremità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Scatter | `scatter` | 0…1; 0 | Rotazione casuale deterministica delle impronte. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Rotation | `rotation` | -1…1; 0 | Orientamento relativo alla tangente. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Roundness | `roundness` | 0.05…1; 1 | Schiacciamento dell'impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Pressure Roundness | `pressureRoundness` | 0…1; 0 | Schiacciamento dipendente dalla pressione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Tilt Roundness | `tiltRoundness` | 0…1; 0 | Schiacciamento dipendente dall'inclinazione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Roundness Vertical Jitter | `roundnessJitterY` | 0…1; 0 | Variazione dell'altezza dell'impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Roundness Horizontal Jitter | `roundnessJitterX` | 0…1; 0 | Variazione della larghezza dell'impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Count | `stampCount` | 1…16; 1 | Numero di impronte per posizione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Count Jitter | `countJitter` | 0…1; 0 | Variazione del numero di impronte. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Randomized | `randomRotation` | 0…1; 0 | Rotazione iniziale pseudocasuale per tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Flip X | `flipX` | 0…1; 0 | Riflessione orizzontale della sorgente. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Shape | Flip Y | `flipY` | 0…1; 0 | Riflessione verticale della sorgente. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Grain | Scale | `grainScale` | 0.1…8; 1 | Scala spaziale della texture. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Grain | Depth | `grainDepth` | 0…1; 0 | Influenza della grana sul deposito. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | GRUPPO-SYN: sorgente grana + depth |
| Grain | Movement | `grainMovement` | 0…1; 0 | Scorrimento della texture rispetto al percorso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Grain | Rotation | `grainRotation` | -1…1; 0 | Rotazione delle coordinate di texture. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Grain | Contrast | `grainContrast` | 0…2; 1 | Contrasto della maschera di grana. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Grain | Brightness | `grainBrightness` | -1…1; 0 | Luminosità della maschera di grana. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Grain | Zoom | `grainZoom` | 0…1; 0 | Influenza del diametro sulla scala della texture. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Rendering | Flow | `flow` | 0…1; 1 | Quantità di pigmento per impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Rendering | Opacity | `opacity` | 0…1; 1 | Limite dell'opacità depositata. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Rendering | Accumulation · Atelier | `accumulation` | 0…1; 1 | Accumulo progressivo nelle sovrapposizioni. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Rendering | Alpha Threshold | `alphaThreshold` | 0…1; 0 | Soglia binaria dell'alpha; zero la disattiva. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Rendering | Blend Mode | `blendMode` | 0…2; 0 | 0 normale, 1 multiply, 2 screen. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Rendering | Dual Brush · Atelier | `dualEnabled` | 0…1; 0 | Miscela una seconda impronta della stessa sorgente. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Rendering | Dual Scale · Atelier | `dualScale` | 0.1…2; 1 | Scala della seconda impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Rendering | Dual Rotation · Atelier | `dualRotation` | -1…1; 0 | Rotazione della seconda impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Rendering | Dual Opacity · Atelier | `dualOpacity` | 0…1; 0.5 | Peso della seconda impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Wet Mix | Dilution | `wetDilution` | 0…1; 0 | Diluisce il pigmento nuovo. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Wet Mix | Charge | `wetCharge` | 0…1; 1 | Carica iniziale che si esaurisce lungo il percorso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Wet Mix | Attack | `wetAttack` | 0…1; 1 | Intensità del deposito umido. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Wet Mix | Pull | `wetPull` | 0…1; 0 | Prelievo del colore già presente prima del tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Wet Mix | Grade | `wetGrade` | 0…1; 0 | Contrasto del colore prelevato; modello semplificato. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Color Dynamics | Hue | `hueJitter` | 0…1; 0 | Deviazione cromatica per impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN: hue jitter isolato |
| Color Dynamics | Saturation | `saturationJitter` | 0…1; 0 | Deviazione della saturazione per impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Color Dynamics | Lightness / Darkness | `brightnessJitter` | 0…1; 0 | Deviazione del valore per impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Color Dynamics | Stroke Hue | `strokeHue` | 0…1; 0 | Deviazione cromatica costante lungo il tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Color Dynamics | Stamp Hue · Atelier | `stampHue` | 0…1; 0 | Ulteriore modulazione cromatica dell'impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Dynamics | Speed Size | `speedSize` | -1…1; 0 | Diametro in funzione della velocità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Dynamics | Speed Opacity | `speedOpacity` | -1…1; 0 | Alpha in funzione della velocità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Dynamics | Speed Spacing | `speedSpacing` | 0…2; 0 | Distanza fra impronte in funzione della velocità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Dynamics | Jitter Size | `sizeJitter` | 0…1; 0 | Variazione pseudocasuale del diametro. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Dynamics | Jitter Opacity | `opacityJitter` | 0…1; 0 | Variazione pseudocasuale dell'alpha. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Apple Pencil | Pressure Size | `pressureSize` | 0…1; 0.6 | Risposta del diametro alla pressione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | GRUPPO-SYN: size + curva |
| Apple Pencil | Pressure Opacity | `pressureOpacity` | 0…1; 0 | Risposta dell'alpha alla pressione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Apple Pencil | Pressure Flow | `pressureFlow` | 0…1; 0 | Risposta del flusso alla pressione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Apple Pencil | Pressure Bleed | `pressureBleed` | 0…1; 0 | Influenza della pressione sul prelievo del pigmento. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Apple Pencil | Pressure Graph · exponent | `pressureCurve` | 0.2…3; 1 | Curva di potenza; non è un grafico multipunto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | GRUPPO-SYN: size + curva |
| Apple Pencil | Tilt Size | `tiltSize` | 0…1; 0 | Allargamento del segno con Pencil inclinata. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Apple Pencil | Tilt Opacity | `tiltOpacity` | 0…1; 0 | Variazione dell'alpha con Pencil inclinata. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Apple Pencil | Tilt Gradation | `tiltGradation` | 0…1; 0 | Gradazione del deposito in inclinazione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Apple Pencil | Azimuth | `azimuth` | 0…1; 0 | Peso dell'azimut nell'orientamento della forma. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Apple Pencil | Barrel Roll | `barrelRoll` | 0…1; 0 | Peso della rotazione rilevata da Apple Pencil Pro. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Properties | Minimum Size | `minSize` | 0…1; 0 | Diametro minimo relativo. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Properties | Maximum Size | `maxSize` | 0…1; 1 | Diametro massimo relativo. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Properties | Minimum Opacity | `minOpacity` | 0…1; 0 | Alpha minimo del tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Properties | Maximum Opacity | `maxOpacity` | 0…1; 1 | Alpha massimo del tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Properties | Smudge Pull | `smudge` | 0…1; 0.5 | Forza dello spostamento del colore con sfumino. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | NV |
| Preview | Size | `previewSize` | 0.1…1; 0.5 | Diametro del tratto nella miniatura. | `UI/CanvasSurface.swift · BrushPreview` | NV |
| Preview | Pressure Scale | `previewPressure` | 0…1; 1 | Ampiezza della pressione sintetica nella miniatura. | `UI/CanvasSurface.swift · BrushPreview` | NV |
| Preview | Wet Mix | `previewWetMix` | 0…1; 1 | Influenza del wet mix nella miniatura. | `UI/CanvasSurface.swift · BrushPreview` | NV |
| Preview | Length · Atelier | `previewLength` | 0.2…1; 1 | Estensione del percorso di anteprima. | `UI/CanvasSurface.swift · BrushPreview` | NV |

## Differenze delle formule presenti

Stabilizzazione: filtri esponenziali e media indipendenti, non gli algoritmi originali. Taper: due lunghezze e pesi condivisi fra input; la coda viene ricalcolata a fine tratto. Rotazione: peso della tangente, azimut e roll. Grana: PNG ripetuta e trasformata nello shader, moltiplicata nel deposito; non una texture decorativa sopra il risultato. Accumulation è un peso di deposito Atelier, non la selezione dei sei rendering mode originali. Alpha threshold produce alpha binario se attivo. Blending limitato a normale, multiply e screen.

Wet mix: carica e diluizione regolano l'alpha lungo il percorso; pigmento e sfumino campionano il livello immutabile di prima del tratto. Non c'è simulazione di fluido, diffusione nel tempo o impasto. Grade modifica il peso di prelievo secondo luminanza, non la stessa formulazione dell'originale. Dual ripete la stessa sorgente a scala/rotazione/alpha diversi; non ha un secondo preset indipendente. Barre e grafici Pencil avanzati restano nell'inventario mancante.

## Sottofunzioni ancora mancanti o parziali

Queste voci conservano l'intero perimetro richiesto. Non ci sono slider inattivi a rappresentarle: una sezione senza motore applicabile spiega il limite. L'inventario richiede ancora riscontro diretto sulla build 5.4.14 e non viene dichiarato esaustivo di tutte le azioni contestuali nascoste.

| Ambito | Funzioni residue | Stato | Prova necessaria |
|---|---|---|---|
| Stroke Path | Modulazioni indipendenti del jitter tramite pressione, tilt e roll; editor numerico contestuale | da implementare | Test separato per ogni modulazione |
| Stabilization | Riproduzione quantitativa dei filtri originali e impostazioni globali condivise | parziale | Percorsi tremolanti e misurazione della risposta |
| Taper | Set separati pressione/dito; collegamento punte, pressione e forma della punta, animazione/classic | parziale | Tratti Pencil e dito; coda live e finale |
| Shape | Modalità di input dedicate; origine relativa al tratto; grafico bidimensionale completo; selettori dei filtri | parziale | Stamp isolati ruotati con input hardware |
| Grain | Due modalità esplicite; profondità minima/casuale; offset casuale; blend indipendente; filtri; dipendenza dalla camera 3D | parziale | Campiture, scala e giunti; camera 3D |
| Editor sorgenti | Libreria ricercabile di sorgenti, Photos/clipboard, inversione gestuale; generatore di ripetizione con bordi, maschere, specchio e blending multiscala | parziale: import da Files entro512² | Round trip immagini e test dei bordi |
| Rendering | Sei modalità glaze/blending originali, effetti di bordo umido/bruciato e relativo blend, luminanza, compatibilità dual classic | parziale | Sovrapposizione di stroke e differenze ai bordi |
| Wet Mix | Blur, variazione casuale di blur e umidità; modulazioni separate di attack | parziale | Pigmento preesistente e parametri indipendenti |
| Color Dynamics | Lightness e darkness separate; secondo colore; variazioni complete per tratto, pressione, inclinazione e roll | parziale | Tavole cromatiche con input controllato |
| Dynamics | Curve/normalizzazione della velocità identiche e riscontro dei segni ± | parziale | Velocità misurate mantenendo lo stesso percorso |
| Apple Pencil | Grafico multipunto globale per pennello; curve e tempi di risposta per singolo parametro; soglia tilt, bleed e compressione; size/opacity/bleed da roll; outline e riempimento hover per pennello | parziale | Pencil fisica compatibile e impostazioni di sistema |
| Properties | Anteprima stamp e orientamento allo schermo; semantiche esatte dei limiti dimensionali | parziale | Rotazione canvas/dispositivo e scala pennello |
| Materials | Canali metallic/roughness, sorgenti, import/editor e pittura su mesh | da implementare | Mesh UV, materiali e dispositivo AR |
| Preview | Minimo pressione, singolo stamp e angolo tilt dedicato | parziale | Miniatura vs percorso renderer equivalente |
| About this Brush | Ritratto, firma disegnata, data creazione, reset point personali completi | parziale: autore/note e originali Atelier persistiti | Modifica, export/import e ripristino dopo riavvio |

## Dati e affidabilità

`BrushStore.validate` controlla versione, limiti, identificatori, riferimenti, nomi, valori finiti e intervalli. Gli asset importati devono essere PNG singoli entro512×512; il pannello converte i formati immagine consentiti tramite thumbnail senza decomprimere un'immagine enorme a risoluzione piena. L'archivio non può superare32MB in ingresso. Un file danneggiato viene conservato in una copia di recupero; se la copia non riesce, la scrittura resta bloccata. Il salvataggio JSON usa scrittura atomica e, in caso di errore, ripristina lo stato persistito precedente in memoria e mostra il problema. Nessuna di queste precauzioni costituisce una prova eseguita di power-loss o disco pieno su iPad.

I sette test di `AtelierTests/BrushTests.swift` sono stati eseguiti con successo nel run indicato: configurazione dopo salvataggio e ricreazione dello store, round trip, preservazione dei byte immagine e seed, rifiuto dati invalidi senza mutazioni, ordine/librerie, ripristino dei personali, catalogo 192, rollback della memoria su destinazione di scrittura invalida e conservazione del file danneggiato. Non sono prove di riavvio UI completo, disco pieno reale o Apple Pencil.
