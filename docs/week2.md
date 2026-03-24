# Week 2 — Services, Observabilitat & Automatització

## Objectiu i context

Durant la Week 2 hem passat d'un servidor amb processos gestionats "a mà" a un sistema **robust, observable i automatitzat**. El repte real no és fer que els serveis funcionin — és fer que continuïn funcionant sols, i que quan algo falli ho sapiguem immediatament.

---

## Arquitectura de serveis

### Component overview

```
┌─────────────────────────────────────────────┐
│              SYSTEMD                         │
│                                             │
│  nginx.service ──► Nginx (web server)       │
│  nginx.service.d/override.conf              │
│      Restart=on-failure                     │
│                                             │
│  p1-backup.timer ──► p1-backup.service      │
│      OnCalendar=daily        Type=oneshot   │
│      Persistent=true         ExecStart=     │
│                              backup.sh      │
└─────────────────────────────────────────────┘
         │                    │
         ▼                    ▼
    journald logs       /var/backups/P1/
    journalctl -u       backup_DATE.tar.gz[.gpg]
```

---

## Decicions de disseny

### Per qué systemd timers en lloc de cron?

- **Observabilitat**: En `cron` els logs van a syslog (separat); en `systemd timer` estan integrats a journald.
- **Missed executions**: En `cron` es perd la tasca si el sistema estava apagat; en `systemd timer` l'opció `Persistent=true` l'executa en arrencar.
- **Dependències**: `cron` no en té; `systemd timer` pot dependre d'altres unitats.
- **Control**: En `cron` s'utilitza `crontab -l`; en `systemd timer` s'usa `systemctl list-timers --all`.
- **Debugging**: En `cron` és difícil; en `systemd timer` es fa fàcilment amb `systemctl status p1-backup.service`.

**Decisió**: systemd timers. La persistència és clau: si el servidor estava apagat a mitjanit, el backup s'executa en la propera arrencada.

### Per qué Restart=on-failure i no Restart=always?

- `Restart=always`: reinicia fins i tot en exits normals (0). Pot causar loops infinits.
- `Restart=on-failure`: només reinicia quan el codi de sortida és != 0. ✓ Correcte per a Nginx.
- `RestartSec=5s`: espera 5 segons entre reinicis per evitar flapping.

### Per qué un fitxer override i no modificar la unit original?

```bash
mkdir -p /etc/systemd/system/nginx.service.d/
cat > /etc/systemd/system/nginx.service.d/override.conf << 'EOF'
[Service]
Restart=on-failure
RestartSec=5s
EOF
```

La unit original (`/usr/lib/systemd/system/nginx.service`) pertany al paquet `nginx`. Si es modifica directament, una actualització del paquet la sobreescriu. L'override al directori `.d/` persisteix i té prioritat.

### Per qué Type=oneshot per al backup?

El backup és un treball que s'inicia, executa, i acaba. `Type=oneshot` fa que systemd esperi que el procés surti before marcar el servei com "active/exited". Això permet:
- `systemctl is-active p1-backup.service` → retorna "active" mentre s'executa
- El codi de sortida del script determina si la unit ha tingut èxit o falla

---

## Gestió de logs (journald)

### Configuració de límits

Sense limits, journald pot ocupar tot el disc. Configurat a `/etc/systemd/journald.conf.d/limits.conf`:

```ini
[Journal]
SystemMaxUse=200M       # espai màxim total per a logs
SystemMaxFileSize=20M   # mida màxima per fitxer individual
MaxRetentionSec=30day   # logs de més de 30 dies s'eliminen
Compress=yes            # comprimir fitxers inactius
```

**Per qué 200 MB?** En un servidor de desenvolupament petit, 200 MB és suficient per a 30 dies de logs. En producció s'usaria més (1-2 GB) i s'enviaria a un sistema de log centralitzat (ELK, Loki).

### Consulta de logs

```bash
# Logs d'avui
journalctl -u nginx --since today

# Últims 100 missatges en temps real
journalctl -u p1-backup.service -n 100 -f

# Errors de les últimes 24h
journalctl -p err --since "24 hours ago"

# Logs del backup (últim run)
journalctl -u p1-backup.service --since "1 day ago"
```

---

## Backup automatitzat

### Estratègia de l'script `backup.sh`

```
Backup complet de /home ──► tar czf ──► GPG xifrat ──► fitxer .tar.gz.gpg
                                                         │
                                    ┌────────────────────┘
                                    │
                          /var/backups/P1/          (quan /mnt/storage no muntat)
                          /mnt/storage/backups/     (quan disc Week 5 muntat)
```

Rotació automàtica:
- Guarda els 7 últims backups diaris
- Guarda els 4 últims backups setmanals (diumenges)
- Elimina els fitxers antics automàticament

### Backup inicial sense xifrat (--no-encrypt)

Durant el `setup_all.sh` l'script de backup s'executa amb `--no-encrypt` com a *smoke test*. Raó: `/etc/backup.passphrase` (Week 5) no existeix encara. L'objectiu és verificar que el mecanisme funciona (tar, paths, permisos). Els backups nocturns via timer ja van xifrats un cop Week 5 és completa.

### ExecStart dinàmic al servei systemd

El `p1-backup.service` podria tenir `ExecStart` hardcoded a `/opt/P1/...`. Com el repo pot estar en qualsevol ruta (shared folder VirtualBox, `/home/gsx/...`), `week2_setup.sh` pateja `ExecStart` usant `sed` just després de copiar el fitxer a `/etc/systemd/system/`:

```bash
# Obtenir ruta real del repo (dinàmic)
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
# Patchejar ExecStart
sed -i "s|ExecStart=.*|ExecStart=$PROJECT_ROOT/scripts/Week_5_backup/backup.sh|" \
    /etc/systemd/system/p1-backup.service
```

### Fallback robust del directori de Backup

**Motiu**: En els tests de Week 2 cridem a generar backup. No obstant, a causa de que el disc principal de seguretat `/mnt/storage` no es formatarà ni muntarà en virtualbox fins a la instal·lació de la Week 5, el script moria i feia malbé els automatismes encadenats de test.
**Solució**: El procés de `backup.sh` ha estat dotat de funcionalitat Fallback avaluant `mount | grep` al disc. Si comprova que la ruta òptima externa no és assequible, salva les còpies dins l'arbre principal directament a `/var/backups/P1/`.

---

## Scripts d'observabilitat

- **`show-nginx-logs.sh`**: Executa `journalctl -u nginx` filtrat mostrant els últims N missatges.
- **`show-backup-logs.sh`**: Mostra els logs del backup, l'estat del timer i els fitxers al disc.
- **`status-week2.sh`**: Dashboard complet amb serveis, timers, errors i l'ús de logs.

---

## Respostes a les preguntes de l'enunciat

### Qué hauria de passar si Nginx cau a les 3 AM?

Amb `Restart=on-failure` configurat, systemd detecta la caiguda (exit code != 0) i reinicia el servei en 5 segons. El downtime és pràcticament zero.

L'event queda registrat a journald:
```bash
journalctl -u nginx --since "03:00" --until "03:30"
# Mostra: el servei ha caigut, s'ha reiniciat, i ara és actiu
```

En un entorn productiu, s'afegiria monitorització externa (Prometheus + Alertmanager, UptimeRobot) per notificar un oncall.

### Com es comprova que el servei es reinicia automàticament?

No cal esperar que fallen "de veritat". Es simula:

```bash
# Simular crash
sudo kill -9 $(pidof nginx)

# Esperar 6 segons i comprovar
sleep 6
systemctl is-active nginx        # ha de dir "active"
journalctl -u nginx --since "1 min ago"  # ha de mostrar el reinici
```

### Si els backups fallen silenciosament, com ho sabríem?

Senyals d'alerta disponibles:
```bash
# 1. L'estat del servei
systemctl status p1-backup.service    # "failed" si l'últim run ha fallat

# 2. Logs del run anterior
journalctl -u p1-backup.service --since "yesterday"

# 3. Data de modificació del fitxer de backup
ls -lt /var/backups/P1/              # l'últim fitxer ha de ser d'ahir

# 4. El timer
systemctl list-timers p1-backup.timer  # "Last trigger" + "Passed"
```

En producció: script de monitorització que comprova que el fitxer de backup de la nit anterior existeix i té mida esperada. Si no, envia un email/alert.

### Com s'explica una fallada del servei a l'equip usant logs?

```bash
journalctl -u nginx --since "2026-03-20" --until "2026-03-21"
```

Comunicació tipus:
> "A les 03:47, journald registra exit code 137 (SIGKILL per OOM). El sistema ha reiniciat Nginx automàticament a les 03:47:05. Causa probable: ús de memòria excessiu. Acció: revisar configuració worker_processes."

Informació clau del log: hora exacta, codi d'error, missatge del procés, accions del sistema (reinici).

---

## Troubleshooting ràpid

```bash
# Servei no arrenca
systemctl status nginx -l
journalctl -u nginx -n 50

# Timer no s'activa
systemctl list-timers --all
systemctl status p1-backup.timer

# Backup no troba fitxers
ls -la /var/backups/P1/
journalctl -u p1-backup.service --since "today"

# Logs ocupen massa disc
journalctl --disk-usage
journalctl --vacuum-size=100M    # alliberar fins a 100 MB
```

---

## Reflexió

La lliçó més important d'aquesta setmana: **un servei que funciona no és suficient — ha de funcionar de forma observable i recuperable**. Quan algo falla a les 3 AM, la informació als logs és tot el que tens. Dissenyar els logs i el monitoring *a priori* (no quan algo ja ha fallat) és el que separa un sysadmin professional d'un novell.
