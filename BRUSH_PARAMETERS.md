# Matrice dei parametri pennello

Revisione 30 ottobre 2026. Baseline richiesta: Procreate 5.4.14, build non osservata. Il [manuale ufficiale corrente di Brush Studio](https://help.procreate.com/procreate/handbook/brushes/brush-studio-settings) è stato consultato per titoli e inventario; non sostituisce una verifica diretta della build richiesta.

I 14 titoli delle sezioni sono mantenuti nel pannello: Stroke Path, Stabilization, Taper, Shape, Grain, Rendering, Wet Mix, Color Dynamics, Dynamics, Apple Pencil, Properties, Materials, Preview, About this Brush. Le diciture con `Atelier` e `exponent` identificano esplicitamente opzioni o rappresentazioni indipendenti. In particolare la curva di pressione è un esponente, non l'editor multipunto dell'originale.

## Stato delle prove

Il [run 41120843683](https://github.com/Megami-Hylia/Atelier/actions/runs/41120843683), sorgenti `5d563f0a54171f48f21923c4101313d1d44d256b`, ha superato **67 test, zero falliti/saltati** su iPad A16 simulato / iOS 26.2 / x86_64. Per tutti i 76 controlli sono verificati minimo, medio e massimo: finitezza, persistenza/riapertura e almeno due risultati di pixel distinti con le dipendenze attive. [Matrice JSON effettiva](docs/verification/BRUSH_SETTINGS_MATRIX.json). I parametri periodici o binari possono dare risultati equivalenti agli estremi; non si pretende che ogni variazione abbia un effetto in ogni contesto.

**SYN-3** = confronto sintetico dei tre valori, non verifica hardware né parità proprietaria. Il test abilita sorgenti e assegnazioni necessarie: ad esempio una grana non uniforme, una forma asimmetrica, pressione e pigmento preesistente. I quattro controlli Preview modificano soltanto la miniatura, secondo il loro scopo. Non è presente un controllo Durezza; i bordi dipendono dalla sorgente della forma.

`BrushParameter.all` è la fonte dei limiti UI, dei default e del motore dei nuovi tratti. Conteggio e modalità sono discreti; Preview Wet Mix è continuo. L’area prova e la miniatura usano `CanvasSurface`/`MetalPainter`; i tratti congelano il preset con cui sono creati. [Difetti e correzioni](docs/BRUSH_SETTINGS_FIX.md).

## Controlli collegati

I limiti sono normalizzati Atelier; non sono i valori interni proprietari. Le descrizioni seguenti riguardano la nuova implementazione.

| Sezione | Controllo | Chiave persistita | Intervallo; default | Effetto implementato | Collegamento | Prova |
|---|---|---|---|---|---|---|
| Stroke Path | Spacing | `spacing` | 0.01…2; 0.08 | Distanza fra le impronte in proporzione al diametro. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Stroke Path | Spacing Jitter | `spacingJitter` | 0…1; 0 | Variazione ripetibile della distanza fra impronte. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Stroke Path | Jitter Lateral | `jitterLateral` | 0…1; 0 | Spostamento perpendicolare al percorso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Stroke Path | Jitter Linear | `jitterLinear` | 0…1; 0 | Spostamento lungo il percorso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Stroke Path | Fall Off | `fallOff` | 0…1; 0 | Riduzione del deposito con la lunghezza del tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Stabilization | StreamLine Amount | `streamline` | 0…1; 0 | Filtraggio delle posizioni in ingresso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Stabilization | StreamLine Pressure | `pressureSmoothing` | 0…1; 0 | Filtraggio della pressione fra campioni. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Stabilization | Stabilization Amount | `stabilization` | 0…1; 0 | Media delle posizioni durante il tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Stabilization | Motion Filtering Amount | `motionFiltering` | 0…1; 0 | Ulteriore attenuazione delle deviazioni. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Stabilization | Motion Filtering Expression | `motionExpression` | 0…1; 0 | Recupero di una parte del movimento originale. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Taper | Start | `taperStart` | 0…1; 0 | Lunghezza relativa della punta iniziale. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Taper | End | `taperEnd` | 0…1; 0 | Lunghezza relativa della punta finale; aggiornata a fine tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Taper | Size | `taperSize` | 0…1; 1 | Riduzione del diametro alle estremità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Taper | Opacity | `taperOpacity` | 0…1; 0 | Riduzione dell'alpha alle estremità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Scatter | `scatter` | 0…1; 0 | Rotazione casuale deterministica delle impronte. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Rotation | `rotation` | -1…1; 0 | Orientamento relativo alla tangente. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Roundness | `roundness` | 0.05…1; 1 | Schiacciamento dell'impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Pressure Roundness | `pressureRoundness` | 0…1; 0 | Schiacciamento dipendente dalla pressione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Tilt Roundness | `tiltRoundness` | 0…1; 0 | Schiacciamento dipendente dall'inclinazione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Roundness Vertical Jitter | `roundnessJitterY` | 0…1; 0 | Variazione dell'altezza dell'impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Roundness Horizontal Jitter | `roundnessJitterX` | 0…1; 0 | Variazione della larghezza dell'impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Count | `stampCount` | 1…16; 1 | Numero di impronte per posizione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Count Jitter | `countJitter` | 0…1; 0 | Variazione del numero di impronte. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Randomized | `randomRotation` | 0…1; 0 | Rotazione iniziale pseudocasuale per tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Flip X | `flipX` | 0…1; 0 | Riflessione orizzontale della sorgente. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Shape | Flip Y | `flipY` | 0…1; 0 | Riflessione verticale della sorgente. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Grain | Scale | `grainScale` | 0.1…8; 1 | Scala spaziale della texture. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Grain | Depth | `grainDepth` | 0…1; 0 | Influenza della grana sul deposito. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Grain | Movement | `grainMovement` | 0…1; 0 | Scorrimento della texture rispetto al percorso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Grain | Rotation | `grainRotation` | -1…1; 0 | Rotazione delle coordinate di texture. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Grain | Contrast | `grainContrast` | 0…2; 1 | Contrasto della maschera di grana. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Grain | Brightness | `grainBrightness` | -1…1; 0 | Luminosità della maschera di grana. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Grain | Zoom | `grainZoom` | 0…1; 0 | Influenza del diametro sulla scala della texture. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Rendering | Flow | `flow` | 0…1; 1 | Quantità di pigmento per impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Rendering | Opacity | `opacity` | 0…1; 1 | Limite dell'opacità depositata. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Rendering | Accumulation · Atelier | `accumulation` | 0…1; 1 | Zero: una sola copertura; uno: accumulo progressivo fino al limite di opacità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Rendering | Alpha Threshold | `alphaThreshold` | 0…1; 0 | Elimina il deposito sotto la soglia; zero la disattiva. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Rendering | Blend Mode | `blendMode` | 0…2; 0 | 0 normale, 1 multiply, 2 screen. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Rendering | Dual Brush · Atelier | `dualEnabled` | 0…1; 0 | Miscela una seconda impronta della stessa sorgente. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Rendering | Dual Scale · Atelier | `dualScale` | 0.1…2; 1 | Scala della seconda impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Rendering | Dual Rotation · Atelier | `dualRotation` | -1…1; 0 | Rotazione della seconda impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Rendering | Dual Opacity · Atelier | `dualOpacity` | 0…1; 0.5 | Peso della seconda impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Wet Mix | Dilution | `wetDilution` | 0…1; 0 | Diluisce il pigmento nuovo. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Wet Mix | Charge | `wetCharge` | 0…1; 1 | Carica iniziale che si esaurisce lungo il percorso. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Wet Mix | Attack | `wetAttack` | 0…1; 1 | Intensità del deposito umido. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Wet Mix | Pull | `wetPull` | 0…1; 0 | Prelievo del colore già presente prima del tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Wet Mix | Grade | `wetGrade` | 0…1; 0 | Contrasto del colore prelevato; modello semplificato. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Color Dynamics | Hue | `hueJitter` | 0…1; 0 | Deviazione cromatica per impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Color Dynamics | Saturation | `saturationJitter` | 0…1; 0 | Deviazione della saturazione per impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Color Dynamics | Lightness / Darkness | `brightnessJitter` | 0…1; 0 | Deviazione del valore per impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Color Dynamics | Stroke Hue | `strokeHue` | 0…1; 0 | Deviazione cromatica costante lungo il tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Color Dynamics | Stamp Hue · Atelier | `stampHue` | 0…1; 0 | Ulteriore modulazione cromatica dell'impronta. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Dynamics | Speed Size | `speedSize` | -1…1; 0 | Diametro in funzione della velocità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Dynamics | Speed Opacity | `speedOpacity` | -1…1; 0 | Alpha in funzione della velocità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Dynamics | Speed Spacing | `speedSpacing` | 0…2; 0 | Distanza fra impronte in funzione della velocità. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Dynamics | Jitter Size | `sizeJitter` | 0…1; 0 | Variazione pseudocasuale del diametro. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Dynamics | Jitter Opacity | `opacityJitter` | 0…1; 0 | Variazione pseudocasuale dell'alpha. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Pressure Size | `pressureSize` | 0…1; 0.6 | Risposta del diametro alla pressione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Pressure Opacity | `pressureOpacity` | 0…1; 0 | Risposta dell'alpha alla pressione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Pressure Flow | `pressureFlow` | 0…1; 0 | Risposta del flusso alla pressione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Pressure Bleed | `pressureBleed` | 0…1; 0 | Influenza della pressione sul prelievo del pigmento. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Pressure Graph · exponent | `pressureCurve` | 0.2…3; 1 | Curva di potenza; non è un grafico multipunto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Tilt Size | `tiltSize` | 0…1; 0 | Allargamento del segno con Pencil inclinata. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Tilt Opacity | `tiltOpacity` | 0…1; 0 | Variazione dell'alpha con Pencil inclinata. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Tilt Gradation | `tiltGradation` | 0…1; 0 | Gradazione del deposito in inclinazione. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Azimuth | `azimuth` | 0…1; 0 | Peso dell'azimut nell'orientamento della forma. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Apple Pencil | Barrel Roll | `barrelRoll` | 0…1; 0 | Peso della rotazione rilevata da Apple Pencil Pro. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Properties | Minimum Size | `minSize` | 0…1; 0 | Diametro minimo relativo. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Properties | Maximum Size | `maxSize` | 0…1; 1 | Diametro massimo relativo. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Properties | Minimum Opacity | `minOpacity` | 0…1; 0 | Limite minimo dell'opacità modulata; zero pigmento resta trasparente. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Properties | Maximum Opacity | `maxOpacity` | 0…1; 1 | Alpha massimo del tratto. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Properties | Smudge Pull | `smudge` | 0…1; 0.5 | Forza dello spostamento del colore con sfumino. | `Engine/StrokePlanner.swift → Engine/Paint.metal` | SYN-3: minimo / medio / massimo |
| Preview | Size | `previewSize` | 0.1…1; 0.5 | Diametro del tratto nella miniatura. | `UI/CanvasSurface.swift · BrushPreview` | SYN-3: minimo / medio / massimo |
| Preview | Pressure Scale | `previewPressure` | 0…1; 1 | Ampiezza della pressione sintetica nella miniatura. | `UI/CanvasSurface.swift · BrushPreview` | SYN-3: minimo / medio / massimo |
| Preview | Wet Mix | `previewWetMix` | 0…1; 1 | Influenza del wet mix nella miniatura. | `UI/CanvasSurface.swift · BrushPreview` | SYN-3: minimo / medio / massimo |
| Preview | Length · Atelier | `previewLength` | 0.2…1; 1 | Estensione del percorso di anteprima. | `UI/CanvasSurface.swift · BrushPreview` | SYN-3: minimo / medio / massimo |

## Differenze delle formule presenti

Stabilizzazione: filtri esponenziali e media indipendenti, non gli algoritmi originali. Taper: due lunghezze e pesi condivisi fra input; la coda viene ricalcolata a fine tratto. Rotazione: peso della tangente, azimut e roll. Grana: PNG ripetuta e trasformata nello shader, moltiplicata nel deposito; non una texture decorativa sopra il risultato. Accumulation interpola fra singola copertura e deposito progressivo, non la selezione dei sei rendering mode originali. Alpha Threshold scarta il deposito sotto la soglia. Il controllo Rendering offre normale, multiply e screen; i componenti combinati conservano le proprie modalità aggiuntive.

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
