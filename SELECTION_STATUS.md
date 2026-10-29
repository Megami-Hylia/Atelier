# Trasforma: stato della ricostruzione

Barra scura con Forma libera, Uniforme, Distorci, Altera; riquadro tratteggiato con otto maniglie e rotazione verde. Apertura con tutti i tratti del livello selezionati. Selezione rettangolare/ellittica, aggiunta, inversione, spostamento, scala uniforme/libera, rotazione, riflessioni, adattamento e ripristino dei tratti selezionati allo stato di apertura. Aggancio al centro della tela e rotazione a passi di 45 gradi.

Le modifiche vengono applicate al termine del trascinamento. La deformazione Distorci sposta i campioni con pesi bilineari, Altera usa pesi locali quadratici: sono implementazioni sui percorsi, non trasformazioni prospettiche e warp pixel del riferimento. Non sono presenti selezione pixel, interpolazione raster, snapping ad altri oggetti o una griglia warp. Le impronte del pennello non vengono deformate come bitmap; il risultato può differire dal riferimento.

Compilazione e verifica grafica di questa revisione da confermare. Nessuna equivalenza completa dichiarata.

## Strumento Selezione separato

Aggiunta barra con Automatico, Mano libera, Rettangolo ed Ellisse. Aggiunta/rimozione, inversione, copia e incolla dei soli tratti scelti, salvataggio locale di una selezione per livello, ricolorazione dei tratti e passaggio a Trasforma sono collegati. Automatico sceglie il colore del tratto vicino al tocco e confronta i colori sorgente con tolleranza; non è una flood selection dei pixel contigui. Il contorno evidenzia i percorsi selezionati, non una maschera raster. Riempimento colore ricolora i tratti interi e non riempie un’area vuota. Sfumatura non è implementata e non viene presentata come funzionante. Modifiche in attesa di compilazione/test nativi.
