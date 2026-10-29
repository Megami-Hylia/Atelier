# Libreria pennelli: aggiornamento dal riferimento fotografico

Il widget usa due colonne, superfici scure, selezione blu e anteprime bianche renderizzate da Metal. La ricerca è accessibile dalla lente; il selettore delle librerie conserva l’accesso a tutti i 192 preset Atelier. Il catalogo contiene 180 preset originali in 18 set e 12 basi, non la libreria completa Procreate. Nessun nuovo preset viene contato solo cambiando nome.

Interazioni implementate: selezione con un tocco, secondo tocco per il laboratorio, menu con pressione prolungata, swipe sinistro per Esporta/Duplica/Elimina, preferiti persistenti, recenti, ricerca, creazione e gestione di set/librerie/pennelli, riordino dal menu +, importazione/esportazione JSON Atelier e punti di ripristino personali. I punti di ripristino conservano la configurazione completa e le sorgenti e sopravvivono allo spostamento del pennello e al riavvio.

Le anteprime riusano un renderer e una cache limitata a 96 immagini/12 MiB; una modifica del pennello cambia la chiave di cache. La generazione iniziale è ancora sincrona sul main actor. Non è una misura o una garanzia di latenza sull’iPad.

Corretto il profilo Soft Air in Basics: forma morbida rotonda anziché scalpello. Per le installazioni con catalogo già salvato, il profilo aggiornato è disponibile tramite Ripristina originale (pressione prolungata) o Ripristina preset dal menu +, per preservare modifiche personali.

Limiti: importazione .brush/.brushset/.abr assente, Classic completa assente, dual brush con due preset indipendenti assente, wet mix fisico e parità degli algoritmi non dimostrati. I 76 controlli del laboratorio sono una implementazione indipendente e parziale. Le foto non contengono i dati delle forme e delle grane originali né l’elenco completo dei pennelli personali visibili.

Prove: test aggiunti per preferiti, compatibilità dei vecchi archivi e ripristino personale/importazione; acquisizione nativa del widget aggiunta per revisione grafica. Run 40872119383, sorgenti 9360611: 22 test riportati superati (21 funzionali e una cattura vuota). Preferiti e ripristino sono passati nel simulatore. La cattura vuota è stata scartata; il test corretto non è stato eseguito a causa di indisponibilità esterna del runner. Nessun confronto grafico nativo valido o test hardware è dichiarato.
