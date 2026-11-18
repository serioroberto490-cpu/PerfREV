# perfREV

Calcolatore Lua per REAPER: **tempo, delay, riverbero e stanza**.
Firma locale nel footer di ogni scheda: **RS ecosystem**.

## Stato

<!-- perfREV:version:start -->
Versione corrente: **0.1.0**, build **1**.
Pacchetto corrente: `dist/perfREV-0.1.0-build1.zip`.
<!-- perfREV:version:end -->

Non elabora o ascolta audio e non modifica progetto,
tempo, tracce, routing, plugin o automazioni. I test automatici verificano
calcoli e interazioni con un host simulato; il collaudo grafico in REAPER resta necessario.

Richiede REAPER 6.0+ (Lua 5.3 e `gfx` integrati). Non richiede ReaImGui, SWS,
Python, Whisper o connessione Internet per funzionare.
SWS oppure js_ReaScriptAPI, se gia' presenti, abilitano la copia diretta.
Senza estensioni viene mostrato un campo da selezionare e copiare con Ctrl+C / Cmd+C.

## Installazione con ReaPack (consigliata, senza ZIP)

ReaPack scarica e installa automaticamente lo script e le sue librerie:
**non serve scaricare uno ZIP, clonare la repository o installare Python**.

1. Se non e' gia' presente, installare [ReaPack](https://reapack.com/):
   Options > Show REAPER resource path, copiare l'estensione adatta al proprio
   sistema nella cartella `UserPlugins` e riavviare REAPER.
2. Aprire **Extensions > ReaPack > Import repositories** e incollare:

   ```text
   https://raw.githubusercontent.com/serioroberto490-cpu/PerfREV/main/index.xml
   ```

3. Aprire **Extensions > ReaPack > Browse packages**, cercare **perfREV**,
   selezionare il pacchetto > tasto destro > **Install**, quindi **Apply**.
4. Aprire **Actions > Show action list**, sezione **Main**, cercare **perfREV**
   ed eseguire **perfREV - Tempo, delay, riverbero e stanza**.

Per gli aggiornamenti: **Extensions > ReaPack > Synchronize packages**.
La connessione Internet serve per installare/aggiornare, non per usare perfREV.
ReaPack installa solo `perfREV.lua`, `lib/perfrev_core.lua` e
`lib/perfrev_version.lua`: non scarica test, strumenti o materiale audio/video.

**Disponibilita':** l'URL funzionera' dopo che il proprietario avra' reso pubblica
la repository e pubblicato `index.xml` insieme ai tre file Lua.
Un errore 404 prima di questi passaggi non indica un problema dello script.

### Aggiungere un tasto nella toolbar

1. Dopo l'installazione, clic destro sulla toolbar > **Customize toolbar**.
2. **Add** > cercare **perfREV** nella lista azioni e aggiungerlo.
3. Scegliere un nome/icona e salvare. Il pulsante apre il calcolatore.
   In alternativa, assegnare una scorciatoia dalla lista azioni.

## Installazione manuale (alternativa)

1. Copiare **`perfREV.lua` e la cartella `lib` insieme**, ad esempio in
   `REAPER/Scripts/perfREV/` (Options > Show REAPER resource path).
2. Actions > Show action list > sezione Main > New action > Load ReaScript.
3. Scegliere `perfREV.lua` ed eseguire l'azione.
4. Per un pulsante: clic destro sulla toolbar > Customize toolbar > Add,
   selezionare l'azione e assegnare nome/icona. Si puo' anche assegnare una scorciatoia.

La finestra puo' essere ridimensionata. Rotella o frecce scorrono il contenuto.
`T` esegue un TAP; `Esc` chiude. Il footer resta separato dall'area scorrevole.
Non e' un'app mobile: non e' prevista navigazione telefonica.
La scheda **Informazioni** mostra discretamente versione e numero di build,
letti direttamente dai metadati distribuiti.

## Versionamento e build

L'unica fonte ufficiale e' **`lib/perfrev_version.lua`**, caricata direttamente
dall'app. La versione usa `MAJOR.MINOR.PATCH`; il numero di build e' un intero
positivo crescente, anche quando cambia la versione.
L'header ReaScript `@version` e il blocco versione di questo README sono
**generati**: non aggiornarli manualmente.

Comandi da eseguire nella cartella del progetto:

```text
python tools/project_version.py --check
python tools/package.py
```

Il secondo crea (o rigenera) il pacchetto della build corrente. Per **ogni nuova
build da distribuire**, incrementare il contatore e creare il nuovo pacchetto:

```text
python tools/package.py --new-build
```

Per cambiare anche la versione (esempio):

```text
python tools/project_version.py --set-version 0.1.1
python tools/package.py
```

`--set-version` incrementa gia' la build: non usare anche `--new-build` per la
stessa distribuzione. `--bump-build` incrementa solo la build; `--sync` rigenera
header e blocco README senza incrementi, utile dopo modifiche manuali ai metadati.
Gli strumenti non creano tag Git, release, commit o push.

I pacchetti distribuibili restano in `dist/`, esclusa da Git insieme a cache
e build rigenerabili tramite `.gitignore`. I pacchetti precedenti sono conservati.
Le vecchie versioni gia' distribuite non vanno sovrascritte con contenuti diversi.
Anche `materiale/` e' esclusa da Git: audio e video di riferimento rimangono
locali, non servono all'app e non vengono pubblicati.
Codice Lua, test, strumenti di manutenzione, documentazione e `index.xml`
restano invece nel repository.

## Funzioni

### Delay / tempo

- BPM progetto al cursore oppure al playback durante la riproduzione.
- Lettura continua del tempo e del metro locali, compresi i cambi di tempo.
- BPM manuali 20–400; metro manuale con denominatore 1/2/4/8/16/32.
- TAP: media degli ultimi otto intervalli, variabilita' percentuale,
  reset dopo oltre 3 s e protezione contro tocchi accidentali sotto 100 ms.
  Il primo tocco inizia la misura, il secondo produce un BPM.
  I risultati sono limitati a 20–400 BPM. Il TAP non cambia il tempo del progetto.
- Note da 1/64 a intera, normali/puntate/terzinate; una, due e quattro battute.
- Click su una cella: selezione del delay e copia del valore numerico in ms.
- Stima del decadimento di un delay con feedback **ideale lineare**.
- Report tabellare in console, senza cancellarne il contenuto precedente.

BPM e TAP sono sempre riferiti al **quarto**. Anche in 6/8:
una battuta contiene sei ottavi. Non si usa il BPM "divided", che dipende dal
denominatore. In presenza di accelerando/rallentando le durate indicate sono
locali: non integrano i futuri cambi di tempo.

### Riverbero

- Decay in multipli del quarto, anche personalizzati.
- Pre-delay libero 0–500 ms oppure selezionato da 1/16, 1/32 o 1/64.
- Selezionare un pre-delay musicale ne memorizza il valore corrente in ms:
  non resta agganciato ai BPM successivi.
- Copia separata di decay e pre-delay; report in console.
- Somma pre-delay + RT60 **nominale**, non promessa di una fine della coda.
- Breve <1 s, medio 1–2 s, lungo >2 s: semplici etichette creative.

**RT60** e' il tempo per un calo di 60 dB, non una fine netta.
Il parametro "decay" dei diversi plugin puo' avere definizioni differenti.
Non sottraiamo automaticamente il pre-delay dal decay.

### Stanza

- Parallelepipedo rettangolare: larghezza X, lunghezza Y e altezza Z in metri.
- Sorgente e ascoltatore trascinabili in pianta; altezze e coordinate numeriche.
- Ascoltatore orientato verso Y=0, il fronte in alto nella pianta.
- Temperatura -20…50 C e velocita' del suono corrispondente.
- Sei prime riflessioni: sinistra, destra, fronte, retro, pavimento, soffitto.
- Percorsi tramite sorgenti immagine e punti di riflessione disegnati.
- Arrivi assoluti e ritardi relativi al diretto, livelli relativi, azimut ed elevazione.
- Sei coefficienti di assorbimento energetico indipendenti 0…1.
- RT60 Sabine ed Eyring con assorbimento medio pesato per area.
- Prime tre frequenze modali assiali per ogni dimensione, solo come riferimento.
- Report completo delle coordinate, ipotesi e risultati in console.

Le preferenze della stanza sono locali allo script, **non per progetto**.
La sorgente e l'ascoltatore devono restare all'interno e distare almeno 5 cm.
Le modifiche alle dimensioni mantengono le posizioni normalizzate, quando possibile.
Un coefficiente 0 e' perfettamente riflettente, 1 totalmente assorbente:
agli estremi le stime statistiche del RT60 vanno interpretate con particolare cautela.

#### Limiti del modello

Sorgente puntiforme omnidirezionale, riflessioni speculari di **primo ordine**,
nessuna diffusione, diffrazione, ostacolo, direttivita', trasmissione attraverso
pareti, HRTF o simulazione binaurale. L'assorbimento non dipende da frequenza
o angolo. Non e' un software di progettazione acustica, un riverbero audio o un
generatore di risposte all'impulso.

I livelli delle riflessioni sono rispetto al diretto e comprendono solo distanza
e assorbimento. Non comprendono la fase o l'interferenza tra percorsi.
Il livello del diretto rispetto a 1 m e' una relazione di campo libero:
**non e' una raccomandazione automatica di gain**.

Gli azimut non corrispondono al pan di un plugin; non ricostruiscono fronte/retro
su due diffusori. L'elevazione e' positiva verso l'alto; entrambi gli angoli
sono espressi in gradi. Le frequenze modali sono teoriche, non predicono intensita',
picchi/nulli o correzioni EQ e non sono integrate nelle sei riflessioni.
Sabine/Eyring assumono campo diffuso e non sostituiscono misurazioni.
Le riflessioni geometriche non sono sincronizzate ai BPM.

Per un multitap con dry non ritardato usare i **delta dal diretto**, non gli arrivi
assoluti. Non sommare due volte il tempo di propagazione.

### Guida al mix

Dieci schede sintetiche: profondita', pre-delay, EQ prima/dopo il riverbero,
de-essing, ducking, delay musicali, compatibilita' mono, automazioni, ipotesi fisiche.
Nessun preset viene presentato come soluzione universale.

## Formule

- Nota ms = `60000 / BPM * 4 / denominatore`.
- Puntata: `x1.5`; terzina: `x2/3`.
- Battuta ms = durata della nota al denominatore × numeratore.
- RT60 delay ideale s = `delay_s * ln(0.001) / ln(feedback)`, con `0 < feedback < 1`.
- Velocita' approssimata, aria secca: `c = 331.3 * sqrt((273.15 + T) / 273.15)`.
- Diretto s = `d / c`.
- Riflessione delta s = `(d_riflesso - d_diretto) / c`.
- Ampiezza riflessa / diretta = `sqrt(1-alpha) * d_diretto / d_riflesso`.
- Livello relativo dB = `20 * log10(rapporto_ampiezze)`.
- `K = 24 * ln(10) / c` (circa 0.161 a 20 C).
- Sabine: `RT60 = K * V / somma(S_i * alpha_i)`.
- Eyring: `RT60 = K * V / (-S * ln(1-alpha_media))`.
- Modo assiale: `f_n = n * c / (2 * dimensione)`.

## ReaPack: preparazione e pubblicazione

Questa sezione e' per chi mantiene il progetto; agli utenti bastano le
istruzioni di installazione sopra. Non e' necessario pubblicare ZIP o creare
una release GitHub per distribuire tramite ReaPack.

Repository: <https://github.com/serioroberto490-cpu/PerfREV>.

1. Rendere pubblica la repository dalle impostazioni GitHub.
   Prima del commit controllare i file con `git status`: `materiale/`, `dist/`
   e le cache devono restare esclusi. Non sono necessari per ReaPack.
2. L'`index.xml` iniziale e' gia' predisposto per i sorgenti sul ramo `main`.
   Per rigenerarlo:

   ```text
   python tools/build_index.py --base-url https://raw.githubusercontent.com/serioroberto490-cpu/PerfREV/main
   ```

3. Pubblicare sul ramo `main` almeno `index.xml`, `perfREV.lua`,
   `lib/perfrev_core.lua` e `lib/perfrev_version.lua`.
   Commit e push restano operazioni manuali del proprietario.
4. Verificare che l'URL di `index.xml` sia accessibile senza login e provare
   l'installazione con ReaPack.

Per distribuzioni riproducibili, dopo aver pubblicato i sorgenti, generare
l'indice sostituendo `main` nel **base URL dei sorgenti** con l'hash del commit
che contiene quella versione. Poi pubblicare l'indice aggiornato sul ramo `main`.
L'URL che gli utenti importano resta sempre quello stabile di `index.xml`.
I riferimenti al ramo `main` sono utili per l'avvio, ma non congelano i vecchi
file: per versioni storiche e downgrade usare riferimenti immutabili.

Il generatore legge versione/build dai metadati e non usa la rete. Python serve solo a chi pubblica,
non agli utenti dello script. L'indice include il main e le due librerie con il
percorso relativo conservato. Per aggiornare: usare gli strumenti di versionamento e mantenere
nell'indice anche le vecchie versioni se si vuole permettere il downgrade.
ReaPack identifica gli aggiornamenti tramite la versione del pacchetto:
per un nuovo aggiornamento ReaPack incrementare anche MAJOR.MINOR.PATCH,
non soltanto la build. Il changelog dell'indice riporta il numero di build.

Per creare l'archivio di installazione manuale, senza includere audio/video:

```text
python tools/package.py
```

Il nome del pacchetto include automaticamente versione e build correnti (vedi sopra).

## Test

Da questa cartella, con Lua 5.3+:

```text
lua tests/test_core.lua
lua tests/test_ui.lua
```

I test UI usano uno stub delle API: non sostituiscono il test visivo nell'app.
Per il generatore:

```text
python -m unittest discover -s tests -p "test_*.py"
```

## Fonti

- [Sengpiel: tempo e distanza](https://www.sengpielaudio.com/calculator-soundpath.htm)
- [Sengpiel: Sabine / RT60](https://www.sengpielaudio.com/calculator-RT60.htm)
- [Sengpiel: comb filtering](https://www.sengpielaudio.com/calculator-combfilter.htm)
- [REW: room simulator](https://www.roomeqwizard.com/help/help_en-GB/html/modalsim.html)
- [iZotope: riverbero e parametri](https://www.izotope.com/community/blog/what-is-reverb)
- [iZotope: EQ, ducking e timing](https://www.izotope.com/community/blog/essential-tips-for-mixing-reverb)
- [REAPER ReaScript API](https://www.reaper.fm/sdk/reascript/reascripthelp.html)

Le fonti sono riferimenti leggibili nel README o stampabili in console:
la firma non e' un link e l'app non effettua richieste online.
