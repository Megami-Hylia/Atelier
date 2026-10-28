# Architettura e limiti dell’incremento

Atelier è un progetto Swift con UI nativa SwiftUI/UIKit, vista MetalKit e shader Metal. Non ha un target web o Windows. Windows ospita i sorgenti e il controllo del processo; Xcode e gli SDK Apple devono compilare su macOS remoto. La configurazione di distribuzione e le verifiche del bundle sono documentate in [README_WINDOWS.md](README_WINDOWS.md).

## Documenti e stato

`DocumentContents` conserva versione formato, dimensioni, DPI, sfondo, profilo dichiarato, livelli e tratti. Ogni tratto include campioni Pencil, colore, modalità, dimensione/opacità, copia completa del pennello e seed. Modificare in seguito un preset della libreria non cambia i tratti già registrati. Il formato `.atelier` è JSON originale versionato, non una reinterpretazione del formato `.procreate`.

`PaintDocument` valida i dati prima del commit e verifica il budget di stamp prima di salvare il tratto. Il livello selezionato, se presente, deve appartenere al documento: un riferimento non valido viene rifiutato. Undo/redo usa snapshot di valori in memoria e conserva fino a cento operazioni di undo. Gli snapshot non sopravvivono alla riapertura; la cronologia dei tratti invece sì. Lo stato selezionato e le operazioni supportate vengono salvati dopo ogni cambiamento. Il limite file è 128 MiB, i livelli al massimo trentadue e le dimensioni fra 64 e 4096 pixel per asse, entro il budget delle quattro texture. Anche il caricamento rifiuta documenti che superano tali limiti prima di sostituire lo stato corrente.

Il salvataggio usa sostituzione atomica e conserva una copia `.recovery` dell’ultima versione presente. Non si dichiara recovery automatico né resistenza al crash senza una prova di interruzione e riapertura. Le operazioni disco sono sincrone: l’impatto di documenti grandi va misurato e corretto prima dell’accettazione delle prestazioni. Un errore di scrittura viene esposto senza presentare il salvataggio come riuscito. Il ritorno alla galleria ritenta il salvataggio e conserva il canvas aperto se fallisce, evitando di perdere subito la copia aggiornata in memoria.

## Deposito e compositing

`StrokePlanner` interpola campioni per distanza, applica filtri configurati, mappa pressione e inclinazione, produce stamp con orientamento, jitter deterministico, taper, colore e proprietà di grana. Il seed del tratto e quello del pennello determinano le variazioni. Il campione sintetico dimostrativo è dichiarato come tale e non viene presentato come acquisizione Pencil reale.

`MetalPainter` suddivide il lavoro in celle di 256 pixel e raggruppa gli stamp che le intersecano. Le coordinate di grana e pickup restano globali per evitare riavvii del pattern al confine. Questo è un dispatch per tile; non è ancora un cache system con tile residenti/scaricati su disco. Il renderer alloca quattro texture a dimensione canvas, RGBA16Float, imponendo 384 MiB come limite delle quattro texture. Un canvas 4096 × 4096 richiede circa 512 MiB solo per queste texture e viene rifiutato. Il cambio delle texture è transazionale: vengono pubblicate solo dopo tutte e quattro le allocazioni riuscite, così un’allocazione parziale non diventa uno stato riutilizzabile.

Il planner rifiuta i tratti che superano centomila stamp invece di presentarne un prefisso come risultato completo. Il raggruppamento per tile limita a 262.144 le copie di stamp per tratto, circa 32 MiB di payload, oltre alle copie nei buffer Metal. Questi limiti prevengono due crescite locali, ma non costituiscono un budget globale di processo: asset, snapshot undo, dati JSON, buffer temporanei e risorse trattenute dal command buffer richiedono ancora misure su hardware. Le prove di rifiuto e il rapporto della build devono restare distinti dai test di memoria reale.

Ogni rendering ripete i tratti conservati e attende il completamento GPU. Questa scelta permette il replay deterministico dell’incremento ma non soddisfa ancora l’obiettivo di un motore professionale a bassa latenza su opere grandi. Non sono stati misurati FPS, latenza Pencil, consumo energetico o picco di memoria su iPad.

Il colore viene convertito da sRGB a lineare prima del deposito; il compositing usa alpha premoltiplicato e texture float. L’export PNG converte di nuovo in sRGB. Non sono implementati profili ICC generici, Display P3 o CMYK. Le modalità livello supportate dal modello corrente sono un sottoinsieme e non devono essere dichiarate “tutti i blend mode”.

Lo sfumino campiona e miscela lo snapshot del livello all’inizio del tratto. Può spostare colore esistente ma non simula ancora il trascinamento progressivo di una riserva di pigmento da stamp a stamp. La gomma attenua l’alpha mediante l’impronta. I parametri wet mix sono un modello indipendente semplificato; non è una simulazione fisica del fluido. Il dual stamp applica una seconda impronta trasformata della stessa sorgente, non due pennelli indipendenti completi.

## Pennelli e interfaccia

Catalogo, asset originali, validazione e persistenza delle librerie sono separati dal documento. Lo Studio usa una bozza per conferma/annullamento. Gli errori delle librerie sono visibili nella UI; quando il salvataggio atomico fallisce lo store ripristina lo stato persistito. Le esportazioni JSON originali possono includere un pennello, un set o una libreria; questo non implementa i formati proprietari. Libreria, area prova e canvas si appoggiano al renderer comune; l’uguaglianza del percorso di rendering non certifica che le loro condizioni di pressione, dimensione e preview siano uguali.

L’interfaccia ricostruisce la disposizione richiesta con controlli nativi attivi nell’incremento supportato. Le schermate originali non sono disponibili: misure, font, spaziature, gesture complete e comportamento dei popover restano non verificati. Nessun comando di una funzione non implementata deve essere usato come prova della funzione.

## Confini di verifica

I test locali su Windows possono controllare catalogo, asset, configurazioni, progetto e packaging. Non compilano UIKit/Metal e non provano il comportamento GPU. La build macOS, il packaging IPA, la firma/installazione e i test hardware sono criteri distinti in [ACCEPTANCE.md](ACCEPTANCE.md). Tutto il perimetro mancante resta in [FEATURE_PARITY.md](FEATURE_PARITY.md), senza riduzioni implicite.

Le correzioni emerse dalla review di persistenza e budget sono registrate in [STORAGE_AUDIT.md](STORAGE_AUDIT.md); la review dei sorgenti non sostituisce l’esecuzione dei relativi test. Il canvas segnala una sola volta lo stesso errore di rendering, lasciando accessibili undo e galleria; una revisione del documento o un nuovo input permettono un nuovo tentativo. L’apertura di file `.atelier` da Files passa dallo stesso caricamento validato dell’importazione manuale e salva prima l’eventuale documento già aperto.

