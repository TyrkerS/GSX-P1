# Week 3 — Gestió de Processos i Control de Recursos

## Objectiu

Identificar i controlar processos que consumeixen recursos excessius, entendre el cicle de vida dels processos i garantir que el servidor es mantingui estable sota càrrega.

---

## Scripts implementats

| Script | Funció |
|--------|--------|
| `diagnose.sh` | Diagnosi del sistema: snapshot, top CPU/MEM, arbre de processos, mètriques per PID |
| `workload.sh` | Generador de càrrega CPU amb gestió de senyals |
| `process_control_demo.sh` | Demostració completa: SIGSTOP/SIGCONT, renice, SIGUSR1/SIGUSR2, SIGTERM/SIGKILL |
| `resource_limit_demo.sh` | Verificació de límits de recursos via cgroups (servei `p1-workload.service`) |

---

## Gestió de senyals

### Per què SIGTERM i no SIGKILL?

| | SIGTERM (15) | SIGKILL (9) |
|--|--------------|-------------|
| El procés pot ignorar-lo | Sí | No |
| Permet neteja (flush, close) | Sí | No |
| Garantia de mort | No | Sí |

**Estratègia correcta**: primer SIGTERM (dona temps al procés per acabar net), esperar un interval, i si segueix actiu, enviar SIGKILL.

### Senyals implementades a `workload.sh`

```
SIGTERM  → Shutdown graceful: registra iteracions completades i surt
SIGUSR1  → Status report: imprimeix PID, temps actiu, iteracions
SIGUSR2  → Toggle pause/resume: atura o reprèn la càrrega de CPU
```

**Demostració:**
```bash
./workload.sh &
PID=$!

kill -SIGUSR1 $PID    # Status report
kill -SIGUSR2 $PID    # Pause
kill -SIGUSR2 $PID    # Resume
kill -SIGTERM $PID    # Graceful stop
```

### Diferència entre SIGSTOP i SIGTERM

- **SIGSTOP**: El kernel atura el procés immediatament. El procés no ho sap i no pot ignorar-ho.
- **SIGTERM**: El procés rep el senyal i decideix com respondre (pot netejar recursos, guardar estat, o ignorar-lo).

---

## Límits de recursos amb cgroups

El fitxer `p1-workload.service` configura límits via systemd (que usa cgroups internament):

```ini
CPUQuota=30%      # màxim 30% d'un nucli
MemoryMax=64M     # màxim 64 MB de RAM
MemorySwapMax=0   # no pot usar swap
```

**Com verificar que els límits s'apliquen:**
```bash
sudo systemctl start p1-workload.service
systemd-cgtop -b -n 1            # veure ús per cgroup
systemctl show p1-workload.service -p CPUQuota -p MemoryMax
```

Si el procés supera `MemoryMax`, el kernel l'elimina (OOM kill). Apareixerà als logs:
```bash
journalctl -u p1-workload.service | grep -i "killed"
```

---

## Script de diagnosi (`diagnose.sh`)

```bash
./diagnose.sh snapshot      # Snapshot ràpid del sistema
./diagnose.sh top 15        # Top 15 per CPU i MEM
./diagnose.sh tree          # Arbre de processos (pstree)
./diagnose.sh pid <PID>     # Mètriques detallades d'un PID
```

El subcomandament `pid` llegeix directament de `/proc/<PID>/status` i `/proc/<PID>/io` per obtenir:
- Estat del procés (State, Threads, VmRSS, VmSize)
- Activitat d'I/O (bytes llegits/escrits)
- Context switches (voluntaris i involuntaris)

---

## Guia de troubleshooting: "El servidor va lent"

```
1. Comprovar càrrega general:
   uptime                          # load average
   ./diagnose.sh snapshot

2. Identificar el culpable:
   ./diagnose.sh top 10            # top CPU i MEM
   htop                            # interactiu

3. Inspeccionar el procés:
   ./diagnose.sh pid <PID>         # mètriques detallades
   cat /proc/<PID>/status          # directament al kernel

4. Decidir acció:
   - Alta CPU: renice +10 -p <PID>     # reduir prioritat
   - Alta MEM: kill -SIGTERM <PID>     # primer graceful
   - No respon: kill -SIGKILL <PID>    # força

5. Verificar efecte:
   ./diagnose.sh top 5             # comprovar millora
```

---

## Respostes a les preguntes de l'enunciat

**Si el teu servei rep un senyal, com ha de respondre? Ha de guardar estat?**

Depèn del senyal:
- **SIGTERM**: Ha de netejar recursos (tancar fitxers oberts, completar l'operació en curs si és breu) i sortir. `workload.sh` registra el nombre d'iteracions completades.
- **SIGHUP**: Convencionalment és "reload config" — el servei rellegeix el fitxer de configuració sense reiniciar.
- **SIGUSR1/SIGUSR2**: Definits per l'aplicació — usem SIGUSR1 per status report i SIGUSR2 per pause/resume.

**Si el job d'un developer usa 90% de CPU, és un problema?**

Depèn del context. Es considera problemàtic si:
- Afecta altres serveis (Nginx triga, backups fallen)
- Porta més de 5-10 minuts sense baixar
- No correspon a una tasca legítima esperada

Solució: `renice +15 -p <PID>` redueix la prioritat sense matar el procés. Si persisteix, parlar amb el developer i aplicar límits de cgroup via PAM o systemd si és un servei.

**Com verificar que un límit de recursos realment funciona?**

```bash
# 1. Iniciar el servei amb límits
sudo systemctl start p1-workload.service

# 2. Verificar CPUQuota aplicat
systemd-cgtop -b -n 3 | grep p1-workload

# 3. Si CPUQuota=30%, el procés mai superarà ~30% en la mesura de cgtop

# 4. Per MemoryMax: forçar consum > límit i observar OOM kill als logs
journalctl -u p1-workload.service -f
```
