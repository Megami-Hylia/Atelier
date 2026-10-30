# Sistema di disegno: stato corrente

Aggiornamento parametri: [CURRENT_BUILD.md](CURRENT_BUILD.md) riporta 67 test superati. Il deposito include copertura per gesto in due superfici RG16Float, senza crescita con la durata del tratto e dentro il budget condiviso. [Dettagli e limiti](docs/BRUSH_SETTINGS_FIX.md).

L'acquisizione conservava quasi tutti i tocchi coalescenti, inclusi punti senza nuovo dettaglio visibile. Il collegamento era lineare e il filtraggio dipendeva dalla densità degli eventi. I livelli non selezionati potevano essere riprodotti di nuovo durante il disegno.

Il nuovo percorso mantiene un `PaintStroke` per gesto. Il campionamento adattivo lavora in punti schermo, le cubiche conservano angoli e variazioni della penna, la stabilizzazione è regolabile. I nuovi campioni entrano nel cursore incrementale una sola volta; previsioni e stime pendenti restano provvisorie. Il rendering segue i frame e si ferma quando non serve. La semplificazione finale verifica forma e attributi di ogni componente in streaming. La cache storica è limitata a quattro livelli/32 MiB entro il budget raster condiviso di 384 MiB.

Documentazione del percorso: [DRAWING_PIPELINE.md](DRAWING_PIPELINE.md). Baseline del percorso precedente: Build e test: [CURRENT_BUILD.md](CURRENT_BUILD.md), [run 40973187554](https://github.com/Megami-Hylia/Atelier/actions/runs/40973187554), sorgenti `2dbccf6d0ffacdf3e38539280a6dbdfe15669523`.

Sono passati 58 test nativi, inclusi 22 nuovi casi, più sei test del validatore IPA. La prova da 8192 campioni verifica lavoro lineare del cursore; quella con 200 tratti verifica che lo storico conservato non rientri nella pianificazione a ogni frame. I confronti Metal verificano previsioni scartate, correzioni tardive, gomma/sfumino e replay. Questi sono controlli sintetici, non benchmark di Apple Pencil o iPad 9.

Restano limiti espliciti: il budget di 32 campioni per frame non equivale a un limite di tempo GPU. Distanze molto grandi, impronte grandi/dense e regolazioni costose possono richiedere più lavoro. Il pen-up valida e riproduce il tratto definitivo. Per tele che non consentono la sesta superficie entro il budget rimane il replay tradizionale. Latenza, FPS e consumo di memoria dell'intero processo su iPad fisico non sono stati misurati.
