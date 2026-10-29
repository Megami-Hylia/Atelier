# Selezione e trasformazione: incremento

Implementati nei sorgenti: selezione rettangolare/ellittica dei tratti del livello attivo, aggiunta, seleziona tutto, inversione dell’insieme dei tratti, riquadro, spostamento, scala uniforme con pulsanti/maniglie, rotazione90°, riflessioni e undo delle operazioni.

La selezione corrente riguarda tratti interi se almeno un campione ricade nella forma: NON ritaglia i pixel sul contorno, non limita ancora pittura/gomma, non passa alla clipboard come maschera. Le maniglie scalano uniformemente. Distorsione prospettica, warp, selezione automatica per colore, libera/poligonale, feather, snapping, interpolazione raster e salvataggio delle selezioni restano da implementare. Non sono sostituiti da pulsanti inattivi. Pertanto la richiesta «tutte le funzioni» non è ancora completata. Build e test della revisione devono essere verificati prima di dichiararla disponibile nell’IPA.
