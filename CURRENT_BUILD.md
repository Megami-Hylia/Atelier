# Build corrente

**Le correzioni del lag nei sorgenti non sono ancora compilate: la IPA sottostante rimane la build precedente.** Vedere PERFORMANCE_STATUS.md.


IPA compilata da `93606114aace0e7f6f2af9a2c446e9349a68c680`.
Workflow: https://github.com/Megami-Hylia/Atelier/actions/runs/40872119383
SHA256: `b094b1fd756fd725bfea35232c1fcc5bcd13a90c185f00f2600045c4adae4957`.

Compilazione iPad arm64 e verifica strutturale superate. La libreria pennelli riprende il riferimento fotografico e aggiunge preferiti, punti di ripristino personali, azioni swipe e cache delle anteprime. Catalogo: 192 preset originali Atelier, non l’intera libreria Procreate. Dettagli e limiti in BRUSH_LIBRARY_STATUS.md.

Run della revisione compilata: 22 test dichiarati superati, zero falliti/saltati. Sono 21 prove funzionali e una cattura che si è rivelata vuota: non costituisce prova grafica. Il test di cattura è stato corretto, ma il nuovo runner non è disponibile per un blocco esterno del servizio CI. Il codice app è invariato rispetto alla IPA compilata. Nessuna prova su iPad fisico o misura di latenza. Il report DELIVERY_REPORT.json contiene il commit e lo stato preciso delle prove.
