# Stato build e criteri distinti

Aggiornamento iniziale: 28 ottobre 2026. Questo file non sostituisce un `BUILD_REPORT.json` generato da una build effettivamente riuscita.

| Criterio | Stato corrente |
|---|---|
| A. Sorgenti e progetto completati | **Parziale**: progetto e pipeline presenti; perimetro funzionale completo ancora in FEATURE_PARITY.md |
| B. Build nativa dispositivo riuscita | **Non ancora eseguita** in questo aggiornamento |
| C. IPA unsigned confezionata/verificata | **Non ancora prodotta** in questo aggiornamento; nessun checksum inventato |
| D. Firma/installazione Windows | **Non eseguita**; guida ufficiale documentata, hardware dell’utente non identificato |
| E. Test su iPad reale | **Non eseguiti** |
| F. Parità complessiva | **Non dimostrata**, funzioni mancanti e prove residue nella matrice |

Il repository [Megami-Hylia/Atelier](https://github.com/Megami-Hylia/Atelier) è stato creato **privato**. La pipeline usa macos-26, Xcode 26.2 build 17C52 e SDK iOS 26.2; registra le versioni effettive e fallisce se non corrispondono. Nessun Apple ID o certificato è richiesto per la build unsigned.

Attivazione: pubblicare i sorgenti nel repository autorizzato e avviare `Build iPad unsigned`; i commit su main che modificano sorgenti/configurazione lo avviano anche automaticamente. Servono permesso Actions, quote disponibili e runner macOS. Al successo, conservare `BUILD_REPORT.json`, `ipa-verification.json`, `SHA256SUMS.txt`, `effective-build-settings.json`, log e risultati XCTest. La firma resta distinta.

Verifiche locali su Windows: i test Python del validatore IPA usano fixture sintetiche temporanee per verificare i rifiuti di simulatori arm64, firme, architetture errate e container non validi. Non sono una compilazione dell’app né producono l’artefatto di consegna. Le verifiche native restano affidate alla CI.
