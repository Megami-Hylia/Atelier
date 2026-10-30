# Correzioni dei parametri pennello — 30 ottobre 2026

Il percorso rimane nativo: `BrushStudioView` modifica una copia del preset; `CanvasSurface` ne congela uno snapshot per ogni gesto; `PlannedBrushSettings` risolve i parametri una volta per cursore; `StrokePlanner` produce le impronte; `paintTile` applica forma, grana, pigmento e compositing Metal. La miniatura utilizza lo stesso `MetalPainter` e lo stesso planner della tela.

## Difetti corretti

- Default UI/motore diversi per pressione-dimensione, taper-dimensione, zoom della grana, scala dual, smudge e attack umido. I nuovi tratti usano i default e gli intervalli di `BrushParameter.all`, anche quando la chiave manca nel preset. I dati non finiti ricadono sul default.
- Opacità e flusso erano entrambi moltiplicatori per impronta: ripassando nello stesso gesto si superava l’opacità impostata. La copertura Metal è condivisa anche dai componenti del pennello combinato. Il pigmento continua a variare quando la copertura raggiunge il limite. Il flusso deposita pigmento; l’opacità limita la copertura del gesto, anche sopra colore opaco. Un nuovo gesto può accumulare altro colore.
- Accumulation zero ora mantiene una sola copertura anziché imporre un minimo arbitrario di accumulo. Valori intermedi interpolano verso l’accumulo progressivo.
- Minimum Opacity poteva riattivare un flusso o un’opacità zero. Ora regola il limite di opacità modulata, senza creare pigmento se la sorgente è disattivata. Maximum Size/Opacity zero non lasciano un segno residuo; Smudge Pull zero non sposta colore; Charge zero non introduce nuovo pigmento.
- Azimuth aggiungeva impropriamente una rotazione derivata dalla direzione del tratto. Ora pesa soltanto l’azimut Pencil; barrel roll rimane separato. Attack umido regola l’intensità del wet mix senza introdurre una risposta alla pressione non assegnata, anche nei pennelli umidi.
- La stabilizzazione globale mascherava i valori locali più bassi. Per i nuovi tratti si combinano progressivamente, senza nascondere i controlli del pennello salvo saturazione al massimo globale.
- Grade umido applicava un peso basato sulla luminanza invece del contrasto dichiarato. Nei nuovi tratti regola il contrasto del pigmento prelevato. Randomized usa la stessa soglia dello switch UI; Count usa passi interi anche nel motore.
- I cursori minimo/massimo potevano produrre una coppia invalida poi rifiutata dal salvataggio. Ora modificare un estremo mantiene coerente l’altro. Gli switch leggono lo stesso default mostrato nel valore numerico.
- La miniatura non usava la traiettoria cubica della tela e la cache non includeva la stabilizzazione globale. Entrambi sono allineati. Preview Wet Mix non è più uno switch con default incoerente: modula continuamente il wet mix della miniatura, secondo il suo intervallo 0–1. I controlli Preview sono condivisi dall’intero pennello anche quando si modifica il componente secondario; il wet mix della miniatura modula entrambi i componenti.

Le formule di dimensione, spaziatura in diametri, forma, rotazione, dispersione, grana e dinamiche rimangono nel planner condiviso. Un controllo dipendente richiede la sua sorgente: ad esempio grana non uniforme/depth per vedere contrasto e scala, una forma non circolare per vedere una rotazione, pigmento già presente per il prelievo umido. Non esiste un cursore Durezza nel catalogo corrente: la morbidezza deriva dalla sorgente della forma, inclusa `soft`.

## Compatibilità e costo

`brushSettingsVersion: 1` è memorizzato soltanto nei nuovi tratti. I tratti già archiviati continuano a utilizzare le formule precedenti, inclusi i vecchi default. Preset e relativi valori restano JSON compatibili; annulla/ripristina conserva lo snapshot completo del gesto.

Il nuovo deposito usa due superfici RG16Float (8 byte/pixel complessivi), incluse nel limite raster condiviso di 384 MiB. Una conserva la copertura consolidata, l’altra serve replay e coda provvisoria. Le previsioni non entrano nella copertura persistente; i livelli storici non la sovrascrivono. La copertura e il colore iniziale vengono letti una volta per pixel del gruppo di impronte; la copertura viene poi scritta una sola volta. La memoria non cresce con i punti o con la durata del gesto. Sulle tele molto grandi il budget può impedire superfici aggiuntive: non si aumenta il limite di memoria dell’iPad.

## Verifica

`BrushSettingsTests` verifica ciascun parametro a minimo, medio e massimo: finitezza del planner, persistenza/riapertura e differenze nei pixel con dipendenze attive. I parametri ciclici o binari possono avere due risultati distinti su tre valori, come previsto. Un allegato JSON dei test registra i risultati per chiave.

I test aggiuntivi verificano spessore, pressione assegnata, separazione opacità/flusso, accumulo tra gesti, zeri, snapshot, miniatura, previsioni, replay, livelli, gomma e sfumino. Esecuzione nativa e risultati definitivi sono registrati in CURRENT_BUILD.md quando disponibili. Non sono misurazioni di latenza, FPS o Pencil su iPad 9 fisico.
