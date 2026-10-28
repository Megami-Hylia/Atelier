# Stato build e criteri distinti

Aggiornamento: 28 ottobre 2026, nuova esecuzione in corso. Questo file non sostituisce un `BUILD_REPORT.json` generato da una build effettivamente riuscita.

| Criterio | Stato corrente |
|---|---|
| A. Sorgenti e progetto completati | **Parziale**: progetto e pipeline presenti; perimetro funzionale completo ancora in FEATURE_PARITY.md |
| B. Build nativa dispositivo riuscita | **Non ancora riuscita**: run #2 ha raggiunto Xcode ma il controllo preliminare è fallito prima della compilazione |
| C. IPA unsigned confezionata/verificata | **Non ancora prodotta** in questo aggiornamento; checksum disponibile soltanto dopo il packaging reale |
| D. Firma/installazione Windows | **Non eseguita**; guida ufficiale documentata, hardware dell’utente non identificato |
| E. Test su iPad reale | **Non eseguiti** |
| F. Parità complessiva | **Non dimostrata**, funzioni mancanti e prove residue nella matrice |

Il repository [Megami-Hylia/Atelier](https://github.com/Megami-Hylia/Atelier) è **privato**. La pipeline usa macos-26-intel, Xcode 26.2 build 17C52 e SDK iOS 26.2; registra le versioni effettive e fallisce se non corrispondono. Il binario dispositivo resta arm64. Nessun Apple ID o certificato è richiesto per la build unsigned.

Il [run #1](https://github.com/Megami-Hylia/Atelier/actions/runs/40724922507), commit `bb333e3168fd5946dceb2b6ae0fb0b132718bce4`, è fallito prima di eseguire Xcode per indisponibilità/errore interno del runner arm64. Non ha prodotto l’IPA. Il [run #2](https://github.com/Megami-Hylia/Atelier/actions/runs/40759656717), commit `6f91aa7d261562729a9f2f2836ee77d527ed4c78`, ha confermato Xcode26.2/17C52 e SDK26.2 sul runner Intel; è fallito nel controllo preliminare perché Xcode omette dal JSON `CODE_SIGN_IDENTITY` quando vuoto. Lo script è stato corretto per riconoscere questa rappresentazione, mantenendo l’argomento esplicitamente vuoto e i controlli sulle firme effettive del bundle. Serve una nuova esecuzione.

Per ripetere: avviare `Build iPad unsigned` dal repository; i commit su main che modificano sorgenti/configurazione lo avviano anche automaticamente. Servono permesso Actions, quote disponibili e runner macOS. Al successo, conservare `BUILD_REPORT.json`, `ipa-verification.json`, `SHA256SUMS.txt`, `effective-build-settings.json`, log e risultati XCTest. La firma resta distinta.

Verifiche locali su Windows: i test Python del validatore IPA usano fixture sintetiche temporanee per verificare i rifiuti di simulatori arm64, firme, architetture errate e container non validi. Non sono una compilazione dell’app né producono l’artefatto di consegna. Le verifiche native restano affidate alla CI.
