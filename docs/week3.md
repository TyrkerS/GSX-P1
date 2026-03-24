# Week 3 — Gestió de Processos & Control de Recursos

## Objectiu i context

A mesura que GreenDevCorp creix, múltiples processos competeixen pels mateixos recursos: CPU, memòria, I/O de disc. Un procés descontrolat pot fer caure tot el servidor. L'objectiu d'aquesta setmana és disposar d'eines per **diagnosticar, controlar i limitar** processos de forma segura.

---

## Arquitectura implementada

```
┌──────────────────────────────────────────────────────┐
│ EINES DE DIAGNOSI                                     │
│  diagnose.sh snapshot   → load, CPU/MEM top, I/O     │
│  diagnose.sh top N      → N processos per CPU i MEM  │
│  diagnose.sh tree       → arbre de processos (pstree)│
│  diagnose.sh pid <PID>  → mètriques de /proc/<PID>  │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ GENERADOR DE CÀRREGA                                  │
│  workload.sh            → bucle de CPU amb senyals   │
│    SIGUSR1 → status report                           │
│    SIGUSR2 → pause/resume                            │
│    SIGTERM → graceful shutdown                       │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│ LIMITS DE RECURSOS (cgroups via systemd)              │
│  p1-workload.service                                 │
│    CPUQuota=30%     ← màxim 30% d'un nucli           │
│    MemoryMax=64M    ← màxim 64 MB RAM                │
│    MemorySwapMax=0  ← sense swap                     │
└──────────────────────────────────────────────────────┘
```

---

## Senyals — conceptes fonamentals

### Llista de senyals rellevants

- **SIGTERM (15)**: (Ignorable) Aturada graceful, demana al procés que surti permetent-li netejar.
- **SIGKILL (9)**: (No ignorable) Aturada forçada on el kernel mata el procés immediatament.
- **SIGHUP (1)**: (Ignorable) Sovint usat per recarregar configuració (p.ex. nginx, sshd).
- **SIGINT (2)**: (Ignorable) Equival a Ctrl+C al terminal per interrupció interactiva.
- **SIGSTOP (19)**: (No ignorable) Atura o congela el procés pel kernel.
- **SIGCONT (18)**: (Ignorable) Continua l'execució d'un procés prèviament aturat.
- **SIGUSR1 (10)**: (Ignorable) Senyal definit per l'aplicació (aqui usat per `status`).
- **SIGUSR2 (12)**: (Ignorable) Senyal definit per l'aplicació (aqui usat per `pause/resume`).

### SIGTERM vs SIGKILL — quan usar cadascun?

**Estratègia correcta**: SIGTERM primer, SIGKILL com a últim recurs.

```bash
# Estratègia recomanada
kill -SIGTERM $PID       # Dona temps al procés per netejar
sleep 10                 # Esperar que surti
if kill -0 $PID 2>/dev/null; then
    kill -SIGKILL $PID   # Procés no ha sortit → forçar
fi
```

**Per qué no SIGKILL directament?**
- El procés no pot fer `flush` de buffers → possibles dades corrupts
- No pot tancar connexions de xarxa netes → clients veuen error abrupte
- No pot registrar l'aturada als logs → dificulta diagnosi posterior

**Quan usar SIGKILL directament?**
- Procés completament penjat (no respon a SIGTERM)
- Procés maliciós que cal aturar immediatament
- Zomies (ja morts però no recollits pel pare — però SIGKILL no funciona en zombies)

### Implementació de senyals a `workload.sh`

```bash
# Trap: registrar handlers per a cada senyal
trap 'handle_sigterm' SIGTERM
trap 'handle_sigusr1' SIGUSR1
trap 'handle_sigusr2' SIGUSR2

handle_sigterm() {
    RUNNING=false         # bandera de sortida
    log "SIGTERM received — shutting down gracefully"
}

handle_sigusr1() {
    # Status report sense interrompre l'execució
    log "STATUS: PID=$$  iterations=$COUNT  uptime=${UPTIME}s  paused=$PAUSED"
}

handle_sigusr2() {
    # Toggle pause/resume
    if $PAUSED; then PAUSED=false; else PAUSED=true; fi
}
```

**Si el servei rep un senyal, ha de guardar estat?**
Depèn del valor de les dades:
- `workload.sh` registra el nombre d'iteracions completades (informatiu per auditar)
- Un servidor web real hauria de completar la petició en curs i tancar connexions netes
- Una base de dades hauria de fer `flush` del WAL i tancar fitxers de dades

---

## Límits de recursos amb cgroups

### Per qué cgroups i no `ulimit`?

- **Àmbit**: `ulimit` s'aplica per shell o sessió; `cgroups` s'aplica per unitat de control o servei.
- **Persistència**: els canvis d'`ulimit` es perden quan la sessió es tanca; amb `cgroups` persisteixen al fitxer `.service`.
- **Granularitat**: `ulimit` controla a nivell de procés; `cgroups` a nivell d'arbre sencer de processos (fills inclosos).
- **Memòria compartida**: `ulimit` no la controla efectivament; `cgroups` sí.
- **Control de CPU precis**: `ulimit` ho fa de forma molt limitada; `cgroups` permet percentatges exactes amb `CPUQuota`.

### Configuració al `p1-workload.service`

```ini
[Service]
CPUQuota=30%       # màxim 30% d'un nucli (fins a 300% en server multicore)
MemoryMax=64M      # si supera 64 MB → OOM kill (process dies)
MemorySwapMax=0    # no pot usar swap (comportament predictible)
```

**Per qué 30% CPU?** En un servidor amb un sol nucli, permet que el workload s'executi sense bloquejar SSH, nginx, ni backups.

**Per qué MemorySwapMax=0?** El swap és lent (disc vs RAM). Millor matar el procés immediatament que deixar que degrades el rendiment global del servidor.

### Verificació que els límits s'apliquen

```bash
# 1. Iniciar el servei
sudo systemctl start p1-workload.service

# 2. Observar ús real (millor eina disponible)
systemd-cgtop -b -n 3 | grep p1-workload

# 3. Verificar configuració activa
systemctl show p1-workload.service -p CPUQuota -p MemoryMax

# 4. OOM kill es veu als logs
journalctl -u p1-workload.service | grep -i "killed"
```

**Com crear una prova que fallaria sense el límit?**
```bash
# Sense límit: un bucle de yes pot arribar al 100% CPU
yes > /dev/null &
top -bn1 | grep yes    # es veurà ~100% CPU

# Amb límit (via servei):
sudo systemctl start p1-workload.service
systemd-cgtop -b -n 3  # es veurà ≤30% CPU
```

---

## Script de diagnosi `diagnose.sh`

### Ùs

```bash
./scripts/Week_3/diagnose.sh snapshot        # Snapshot ràpid
./scripts/Week_3/diagnose.sh top 15          # Top 15 per CPU i MEM
./scripts/Week_3/diagnose.sh tree            # Arbre de processos
./scripts/Week_3/diagnose.sh pid <PID>       # Mètriques d'un procés
```

### Informació disponible a `/proc`

```bash
cat /proc/<PID>/status         # Estat, memòria (VmRSS, VmSize, Threads)
cat /proc/<PID>/io             # Activitat I/O (bytes llegits/escrits)
cat /proc/<PID>/schedstat      # Estadístiques del planificador
ls -la /proc/<PID>/fd/         # Fitxers oberts (count = nofile count)
```

---

## Guia de troubleshooting: "El servidor va lent"

```
PASSO 1 — Mesurar la càrrega global
  uptime                    → load average (1, 5, 15 min)
  ./diagnose.sh snapshot    → snapshot complet

  Si load avg > núm CPUs: el sistema està saturat

PASSO 2 — Identificar el culpable
  ./diagnose.sh top 10      → top CPU i MEM
  htop                      → interactiu, ES pot matar
  iotop                     → si el problema és I/O de disc

PASSO 3 — Inspeccionar el procés
  ./diagnose.sh pid <PID>   → mètriques detallades
  cat /proc/<PID>/status    → directament al kernel
  ls /proc/<PID>/fd | wc -l → fitxers oberts

PASSO 4 — Decidir acció
  Alta CPU (no crític):  renice +10 -p <PID>     # reduir prioritat
  Alta CPU (crític):     kill -SIGTERM <PID>      # graceful stop
  Alta MEM:              kill -SIGTERM <PID>      # graceful stop
  Process penjat:        kill -SIGKILL <PID>      # forçar

PASSO 5 — Verificar millora
  uptime                    → load average ha de baixar
  ./diagnose.sh top 5       → comprovar que ja no és al top
```

---

## Demostració de control de processos

```bash
# 1. Iniciar workload en segon pla
./scripts/Week_3/workload.sh &
PID=$!

# 2. Status report (no interromp l'execució)
kill -SIGUSR1 $PID

# 3. Pausa (CPU cau a ~0%)
kill -SIGUSR2 $PID     # pause
top -bn1 | grep workload   # CPU ~0%
kill -SIGUSR2 $PID     # resume
top -bn1 | grep workload   # CPU torna

# 4. Canviar prioritat (no cal ser root per pujar niceness)
renice +15 -p $PID

# 5. Aturada graceful
kill -SIGTERM $PID
# Wait... workload imprimeix "Completed N iterations"
```

---

## Respostes a les preguntes de l'enunciat

**Com és diferent matar amb SIGTERM vs SIGKILL? Quan usar cadascun?**

SIGTERM és una petició educada: el procés decideix com respondre (pot netejar recursos, guardar estat, o ignorar-lo). SIGKILL és una ordre directa al kernel: el procés no pot ignorar-la ni reaccionar. Usar SIGTERM sempre primer, SIGKILL com a absolut últim recurs.

**Si el servei rep un senyal, com ha de respondre? Ha de guardar estat?**

SIGTERM: netejar recursos i sortir ordenadament. SIGHUP: recarregar configuració (convenció Unix). SIGUSR1/SIGUSR2: definit per l'aplicació. `workload.sh` registra les iteracions completades al rebre SIGTERM. Un servidor de base de dades hauria de fer `fsync()` del WAL.

**Com verificar que un límit de recursos realment funciona?**

Executar `systemd-cgtop -b -n 3 | grep p1-workload` mentre el servei corre. El percentatge de CPU no hauria de superar el configurat a CPUQuota. Per memòria: forçar consum per sobre del límit i observar OOM kill a `journalctl -u p1-workload.service`.

**Si el job d'un developer usa 90% CPU, és un problema?**

Depèn del context:
- Si és un job legítim (compilació, entrenament ML) i els altres serveis no es veuen afectats → no urgent
- Si afecta Nginx, backups, o SSH response time → cal actuar: `renice +10 -p <PID>`
- Si porta més de 30 minuts sense progrés visible → possible loop infinit → parlar amb el developer

**Criteris de decisió**: afecta serveis crítics? Durada esperada? Procés legítim?

---

## Reflexió

La comprensió del sistema de senyals Unix ens ha donat una eina conceptual poderosa: el procés és una entitat que pot rebre missatges (senyals) i respondre de forma intel·ligent. Dissenyar processos signal-aware és la diferència entre un sistema que "mor" quan el serverquit i un que es "tanca ordenadament".
