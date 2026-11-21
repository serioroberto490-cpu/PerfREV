# Release e distribuzione perfREV

## Stato reale

I sorgenti in sviluppo sono **0.2.0, build 2**. Non e' stato creato un nuovo
pacchetto 0.2.0, ne' un installer, tag Git, commit, push o GitHub Release.
I pacchetti storici 0.1.0 eventualmente presenti in `dist/` restano immutati.
Il test visivo su REAPER e sui VST reali e' distinto dai test automatici.

## Prima della distribuzione

1. Verificare `lib/perfrev_version.lua`, README, UI e note della release.
2. Eseguire i test Lua e Python documentati nel README.
3. Provare visivamente tutte le schede, ridimensionamento, scorrimento, TAP,
   annullamento dialoghi e specchietto generico/RVerb dentro REAPER.
4. Controllare `git status` e differenze: niente dati locali, credenziali,
   cache, `materiale/` o `dist/` tracciati.

## ReaPack (nessuno ZIP necessario)

Il proprietario pubblica manualmente i sorgenti e l'indice. Per la nuova
versione l'indice include anche `lib/perfrev_reverb.lua` e `lib/perfrev_theme.lua`.
`index.xml` mantiene la 0.1.0 con i sorgenti fissati al commit che la contiene.
La 0.2.0 punta inizialmente a `main`: dopo il commit autorizzato dei sorgenti,
rigenerarla con l'hash reale del commit, non un hash inventato:

```text
python tools/build_index.py --base-url https://raw.githubusercontent.com/serioroberto490-cpu/PerfREV/HASH_REALE
```

L'indice resta sul ramo `main`; le versioni storiche vengono preservate.
Il comando non fa Git e non pubblica. Un successivo push dell'indice e'
manuale e non autorizza tag, GitHub Release o allegati.

## Archivio ZIP opzionale — solo su richiesta

La distribuzione principale e' ReaPack; non serve un installer Windows.
Se viene esplicitamente richiesta una build ZIP:

```text
python tools/package.py
python tools/prepare_release.py dist/releases/v0.2.0/perfREV-0.2.0-build2.zip
```

Il primo comando crea il pacchetto della versione/build corrente senza
sovrascrivere contenuti diversi. Il secondo **non costruisce**: legge un
pacchetto esistente, ne verifica metadati/integrita' e prepara:

- `dist/releases/vX.Y.Z/perfREV-X.Y.Z-buildN.zip`
- `perfREV-X.Y.Z-buildN.zip.sha256`, digest reale e nome file;
- `release.json`: versione/build, elenco artifact con nome, dimensione e SHA-256,
  `source_commit: null` (lo strumento non afferma provenienza non verificata).

L'archivio e' ignorato da Git. I conflitti sono controllati prima delle copie:
una release diversa non viene sovrascritta. Per nuove build distribuite
incrementare sempre il contatore; non spostare o rinominare ZIP storici.
Il manifest per versione ammette una build archiviata: se gia' presente e
diversa, creare una nuova versione prima della preparazione.

Una GitHub Release e l'upload di ZIP/checksum/manifest richiedono
autorizzazione separata. Nessuna pubblicazione viene eseguita dagli strumenti.
