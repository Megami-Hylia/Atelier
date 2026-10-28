# Stato build e criteri distinti

Aggiornamento: 28 ottobre 2026. Build per dispositivo e IPA unsigned effettivamente prodotte nel run #4. Questo file non sostituisce i rapporti macchina conservati con l’artefatto.

| Criterio | Stato corrente |
|---|---|
| A. Sorgenti e progetto completati | **Parziale**: progetto e pipeline presenti; perimetro funzionale completo ancora in FEATURE_PARITY.md |
| B. Build nativa dispositivo riuscita | **Riuscita**: Release `iphoneos` arm64, commit `f10dfb4b05c82b17bbef5a9bbeb1fa4d4d80a558` |
| C. IPA unsigned confezionata/verificata | **Riuscita** nel run #4; download e verifica strutturale indipendente ripetuti su Windows |
| D. Firma/installazione Windows | **Non eseguita**; guida ufficiale documentata, hardware dell’utente non identificato |
| E. Test su iPad reale | **Non eseguiti** |
| F. Parità complessiva | **Non dimostrata**, funzioni mancanti e prove residue nella matrice |

Il repository [Megami-Hylia/Atelier](https://github.com/Megami-Hylia/Atelier) è **privato**. La pipeline usa macos-26-intel, Xcode 26.2 build 17C52 e SDK iOS 26.2; registra le versioni effettive e fallisce se non corrispondono. Il binario dispositivo resta arm64. Nessun Apple ID o certificato è richiesto per la build unsigned.

Il [run #1](https://github.com/Megami-Hylia/Atelier/actions/runs/40724922507), commit `bb333e3168fd5946dceb2b6ae0fb0b132718bce4`, è fallito prima di eseguire Xcode per indisponibilità/errore interno del runner arm64. Non ha prodotto l’IPA. Il [run #2](https://github.com/Megami-Hylia/Atelier/actions/runs/40759656717), commit `6f91aa7d261562729a9f2f2836ee77d527ed4c78`, ha confermato Xcode26.2/17C52 e SDK26.2 sul runner Intel; è fallito nel controllo preliminare perché Xcode omette dal JSON `CODE_SIGN_IDENTITY` quando vuoto. Lo script è stato corretto per riconoscere questa rappresentazione, mantenendo l’argomento esplicitamente vuoto e i controlli sulle firme effettive del bundle. Serve una nuova esecuzione.

Il [run #3](https://github.com/Megami-Hylia/Atelier/actions/runs/40759976004), commit `94ed4ee50b543b167d9c39a7c24571e8f5317cfd`, ha superato i controlli preliminari e raggiunto `CompileMetalFile`, fallendo perché il componente Metal Toolchain non era installato nell’immagine. È stato aggiunto un controllo con download ufficiale del componente, mantenendo Xcode e SDK fissati. Serve una nuova esecuzione per confermare la compilazione.

Il [run #4](https://github.com/Megami-Hylia/Atelier/actions/runs/40760299865), commit `f10dfb4b05c82b17bbef5a9bbeb1fa4d4d80a558`, ha compilato Swift e Metal, creato e caricato `Atelier-unsigned.ipa`. Versioni effettive: macOS26.6.1, Xcode26.2/17C52, SDK iOS26.2, Swift6.2.3 in modalità linguaggio5, Metal32023.864. Dimensione IPA **700285 byte**; SHA-256 **05628391edc69b247e88922c53a88135ee5225b69eddf57d9b9e0c9c496f3563**. La verifica Windows conferma Mach-O eseguibile arm64, piattaforma iOS device2, `UIDeviceFamily=[2]`, nessuna firma/provisioning, `default.metallib`, 192 preset e tutte le dodici risorse PNG. Non è una prova qualitativa dei pennelli.

L’esito complessivo del run #4 è **fallito** nel passaggio successivo di test simulatore: Xcode non ha riconosciuto l’UDID scelto, mostrando soltanto destinazioni generiche. Nessun XCTest è stato eseguito in quel run. Il progetto ora usa `ARCHS_STANDARD` per consentire la selezione dei simulatori Intel; la build device resta esplicitamente arm64. Lo script registra runtime/destinazioni e attende il boot del simulatore. La correzione richiede una nuova esecuzione.

Per ripetere: avviare `Build iPad unsigned` dal repository; i commit su main che modificano sorgenti/configurazione lo avviano anche automaticamente. Servono permesso Actions, quote disponibili e runner macOS. Al successo, conservare `BUILD_REPORT.json`, `ipa-verification.json`, `SHA256SUMS.txt`, `effective-build-settings.json`, log e risultati XCTest. La firma resta distinta.

Verifiche locali su Windows: i test Python del validatore IPA usano fixture sintetiche temporanee per verificare i rifiuti di simulatori arm64, firme, architetture errate e container non validi. Non sono una compilazione dell’app né producono l’artefatto di consegna. Le verifiche native restano affidate alla CI.
