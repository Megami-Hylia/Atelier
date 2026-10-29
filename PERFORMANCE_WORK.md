# Correzioni prestazioni in verifica

Nuovo percorso: una sola presentazione GPU in volo; input successivi accorpati al frame più recente; nessuna attesa GPU sincrona nel canvas. Export e test mantengono attesa esplicita per leggere pixel coerenti.

Cache limitata a16MiB per i piani dei tratti,64voci. Una quinta texture conserva il livello attivo confermato: durante il tratto vengono riprodotti soltanto i nuovi campioni del tratto corrente, non tutta la storia di quel livello. Invalidazione su modifica contenuti, ridimensionamento e errore GPU. Le predicted touches non entrano nella cache confermata. Budget delle cinque texture384MiB; dimensioni massime UI3172.

Test aggiunto per equivalenza cache/fresh-render e invalidazione. Non ancora dichiarato superato: la CI va verificata sul nuovo commit. Latenza/FPS su iPad non misurati. Restano costo del tratto corrente lungo, ricalcolo degli altri livelli e autosave sincrono. Parità completa non raggiunta.

Build: crash del servizio SwiftDriver ripetuto, senza diagnostica Swift. Disabilitato il percorso di moduli espliciti e mantenute compilazioni seriali per ottenere un errore utilizzabile o la build. Questo tentativo non costituisce una build riuscita.
