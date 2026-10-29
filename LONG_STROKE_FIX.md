# Correzione avviso durante i tratti lunghi

La segnalazione su iPad 9ª generazione, iPadOS 26.4, mostra il superamento del budget del tratto. Il video è stato esaminato tramite fotogrammi; non è stata ricavata una misura di latenza Pencil-to-pixel.

Correzioni: eliminato il limite cumulativo di 100.000 impronte dal cursore dei nuovi tratti; il controllo resta sul singolo blocco. Replay finale, validazione prima del salvataggio e riapertura elaborano blocchi di otto campioni, senza costruire tutti i tile del tratto insieme. Restano limiti per blocchi patologici e documenti oltre il budget: non vengono rimossi i controlli di memoria né tagliati i punti del tratto.

Per ridurre il costo dei pennelli densi, 67 parametri vengono risolti una volta nel cursore e il colore HSV di base viene calcolato una volta. Il codice legacy per i vecchi tratti resta distinto.

Regressioni aggiunte: tratto che supera 100.000 impronte conservato dopo commit/salvataggio/riapertura; replay Metal che supera il vecchio limite e verifica presenza effettiva di pigmento. La suite precedente aveva superato 34 test, ma non includeva questi casi.

Build del fix: 3264045, run 40956975542. IPA arm64 compilata e verificata strutturalmente. Test nativi del nuovo run ancora in corso. Nessuna misurazione su iPad fisico; la fluidità dell’iPad 9 richiede verifica sul dispositivo. Il replay dei tratti con taper finale e documenti con molti livelli possono ancora essere costosi.

## Esito finale dei test

Run 40959704053, sorgenti b6bfc13: 36 test superati, zero falliti o saltati, simulatore iPad A16/iOS 26.2/x86_64. Passati entrambi i nuovi test oltre il vecchio limite. Le cartelle Atelier e AtelierTests hanno gli stessi hash Git della build IPA 3264045; la differenza successiva riguarda documentazione e attesa di avvio del simulatore. La IPA Atelier-tratti-lunghi-3264045.ipa rimane quindi il file di prova per questa correzione. Non è una misura di latenza su iPad 9/iPadOS 26.4.
