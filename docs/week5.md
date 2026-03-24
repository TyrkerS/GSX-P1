# Week 5 — Storage, Backup & Recovery

## Objectiu i context

La responsabilitat #1 d'un sysadmin: que les dades no es perdin. Però la majoria d'equips que perden dades tenien backups — simplement no els havien mai provat. L'objectiu d'aquesta setmana és implementar un sistema de backup que es pugui verificar i del qual es pugui recuperar realment.

---

## Arquitectura de storage

### Mapa de dispositius

```
/dev/sda                   ← Disc principal (20 GB, VirtualBox)
├── /dev/sda1 → /          ← Sistema operatiu + dades de sistema
├── /dev/sda2              ← (Extended partition)
└── /dev/sda5 → [SWAP]     ← Swap

/dev/sdb                   ← Disc dedicat a backups (10 GB, VirtualBox)
└── /dev/sdb1 → /mnt/storage  ← Muntat persistentment via fstab (UUID)
```

### Per qué fiscalitzar un segon disc en lloc de `/var/backups`?

Un segon disc físic separat:
- **Fallada de disc independent**: si `/dev/sda` falla (disc danyat), el backup a `/dev/sdb` sobreviu
- **Quota d'espai independent**: el backup no pot omplir el disc del sistema (causant crashes)
- **Escalabilitat**: es pot substituir per un disc més gran sense tocar el sistema

Amb la configuració actual, los backups d'`/var/backups/P1/` serveixen de fallback quan `/dev/sdb` no és disponible. Quan `/mnt/storage` és muntat, els backups van allà.

### Muntatge persistent amb UUID

```bash
# Obtenir UUID del disc
UUID=$(blkid --cache-file /dev/null -s UUID -o value /dev/sdb1)

# Entrada fstab (actualitzada i netejada per setup_storage.sh)
echo "UUID=$UUID /mnt/storage ext4 defaults 0 2" >> /etc/fstab
```

**Per qué UUID en lloc de `/dev/sdb1` a `fstab`?**

Els noms de dispositiu (`/dev/sdb`) **no són estables**. Si s'afegeix un USB o un altre disc, el kernel pot reasignar els noms. Un UUID és inherent al sistema de fitxers (creat en format) i sempre identifica el mateix disc, independentment de l'ordre de detecció.

**Problema trobat**: `blkid` manté una caché a `/run/blkid/blkid.tab`. En un run anterior fallat, la caché estava corrupta i `blkid /dev/sdb1` retornava UUID buit. Solució: `blkid --cache-file /dev/null` (bypass complet de caché) + `blockdev --rereadpt` + `udevadm settle --timeout=15`.

---

## Estratègia de backup

### Disseny: full backup diari + rotació (7+4)

```
Cada nit (00:00 via systemd timer):
  1. tar del directori /home → gzip → GPG AES-256
  2. Nom de fitxer: backup_YYYY-MM-DD_HH-MM-SS.tar.gz.gpg
  3. Guardar a DEST (lmnt/storage/backups/ o fallback /var/backups/P1/)
  4. Rotació: mantenir 7 còpies diàries + 4 còpies setmanals (diumenge)
```

**Per qué full backup i no incremental?**

- **Mida backup**: Gran en Full backup, Petit en Incremental
- **Temps de backup**: Llarg en Full backup, Curt en Incremental
- **Temps de restore**: **Ràpid** (1 fitxer) en Full backup, **Lent** (base + N increments) en Incremental
- **Complexitat**: Baixa en Full backup, Alta en Incremental
- **Risc de pèrdua**: En Full backup cada backup és complet; en Incremental si un increment es corromp, es perd tot a partir d'allà

**Decisió**: full backup diari. Per a `/home` (dades developers), el temps de backup és manejable (minuts). En cas de disaster recovery, volem el procés de restauració el més simple possible (un fitxer, una comanda).

### Principi 3-2-1

- **Còpia 1**: Ubicació `/home` (dades originals), Mitjà Disc principal `/dev/sda`
- **Còpia 2**: Ubicació `/mnt/storage/backups/`, Mitjà Disc secundari `/dev/sdb`
- **Còpia 3**: Ubicació **Pendent**, Mitjà Un tercer lloc (NFS extern, cloud)

**Estat actual**: tenim 2 còpies en 2 medis físics del same server. La 3a còpia (offsite) és la pendent — en un entorn real seria S3, NFS a un altre servidor, o cinta. **Limitació reconeguda**: un incendi o robo del servidor perd les 2 còpies.

### Xifratge AES-256 amb GPG

```bash
tar --preserve-permissions --same-owner -czf - /home \
  | gpg --batch --yes \
        --symmetric \
        --cipher-algo AES256 \
        --passphrase-file /etc/backup.passphrase \
        -o "$BACKUP_FILE"
```

La passphrase es guarda a `/etc/backup.passphrase` (chmod 600, owned root). **Crítica**: si es perd la passphrase, les backups xifrades no es poden restaurar. Custodiar la passphrase en un gestor de contrasenyes fora del servidor.

### Backup de bases de dades (problema real)

**Problema**: una base de dades en ús (MySQL, PostgreSQL) no es pot copiar directament amb `tar`. Els fitxers poden estar en un estat inconsistent (write parcial en curs).

**Solucions**:
- `mysqldump` / `pg_dump` → export consistent en SQL (base de dades petita)
- `FLUSH TABLES WITH READ LOCK` → congela la BD momentàniament mentre es copia
- LVM snapshot + copia → còpia atòmica sense parar el servei (requereix LVM)

En el nostre cas actual (sense BD), el backup de `/home` és suficient.

---

## Automatització i verificació

### systemd timer

```ini
# p1-backup.timer
[Unit]
Description=P1 Backup Timer — daily at midnight

[Timer]
OnCalendar=daily
Persistent=true             # Si el sistema estava apagat, executa en tornar
RandomizedDelaySec=300      # Evita sincronització perfecta (salt de fins a 5 min)

[Install]
WantedBy=timers.target
```

`Persistent=true` és clau: si el servidor estava apagat a mitjanit (manteniment, fallada elèctrica), el backup s'executa en el proper arrencament.

### Test de restauració

```bash
# Restaurar l'últim backup a un directori temporal
LATEST=$(ls -1t /mnt/storage/backups/backup_*.tar.gz.gpg 2>/dev/null | head -n 1)
RESTORE_DIR="/tmp/restore_test_$$"
mkdir -p "$RESTORE_DIR"

gpg --batch --yes \
    --passphrase-file /etc/backup.passphrase \
    --decrypt "$LATEST" \
  | tar --preserve-permissions --same-owner -xzf - -C "$RESTORE_DIR"

# Verificar contingut
find "$RESTORE_DIR" -type f | wc -l    # han d'existir fitxers
ls "$RESTORE_DIR/home/"                # ha de mostrar el directori home restaurat

rm -rf "$RESTORE_DIR"
```

El `verify_week5.sh` executa aquest test automàticament en cada run de verificació.

---

## Runbook de recuperació

### Escenari: restaurar des de backup xifrat

```bash
# 1. Identificar el backup a restaurar
ls -lt /mnt/storage/backups/         # o /var/backups/P1/
# Seleccionar: backup_2026-03-20_00-00-01.tar.gz.gpg

# 2. Verificar que la passphrase és accessible
cat /etc/backup.passphrase | wc -c   # ha de ser 32 (o el que sigui)

# 3. Restaurar a un directori temporal primer (no sobreescriure directe)
mkdir -p /tmp/restore_$(date +%F)
gpg --batch --yes \
    --passphrase-file /etc/backup.passphrase \
    --decrypt /mnt/storage/backups/backup_2026-03-20_00-00-01.tar.gz.gpg \
  | tar --preserve-permissions --same-owner -xzf - -C /tmp/restore_$(date +%F)

# 4. Verificar integritat
find /tmp/restore_$(date +%F) -type f | wc -l   # ha de ser > 0
ls /tmp/restore_$(date +%F)/home/

# 5. Restaurar al lloc definitiu (amb precaució)
# rsync és millor que mv per restauracions parcials
rsync -a --progress /tmp/restore_$(date +%F)/home/ /home/

# 6. Netejar
rm -rf /tmp/restore_$(date +%F)
```

**Temps estimat de restauració**: 5-10 minuts per a un backup de ~100 MB. Per a backups de GB, pot ser 30-60 minuts.

---

## Respostes a les preguntes de l'enunciat

**Si es fa backup de tot cada nit, l'overhead d'emmagatzemament és gran. Com reduir-ho?**

Opcions:
- **Incremental (rsync + hardlinks)**: rsync with `--link-dest` crea hardlinks per fitxers no modificats → saves espai (backup incremental en espai, full en accés)
- **Deduplicació**: eines com `borg backup` deduplicen blocs idèntics entre backups
- **Compressió**: ja fet (gzip dins del tar)

Trade-off: backup incremental és molt més complex de restaurar (necessites la base + tots els increments en ordre). En un entorn petit, la simplicitat del full backup justifica l'overhead.

**Si es perd el servidor principal, es perd? Es pot restaurar des de backup?**

Sí, es pot restaurar. Passos:
1. Instal·lar Debian nou (VM o físic)
2. `bash setup_all.sh` des del repositori Git
3. Restaurar dades des del backup xifrat (`restore.sh`)
4. Verificar amb `bash verify_all.sh`

**Temps estimat total: 30-60 minuts** per a una infraestructura d'aquest tamany.

**Quan trigaria la recuperació? És acceptable?**

Per a una startup de 4 developers: 30-60 minuts d'RTO és acceptable (no és e-commerce 24/7). L'RPO és 24h (perdem com a màxim les dades del dia si el backup de nit és el previ).

Per a un sistema productiu crític, caldria: snapshots cada hora, replica de BD, failover automàtic (HA clustering). Fora de l'abast d'aquest projecte.

**Si una ubicació de backup és corrupte, hi ha una altra còpia?**
Amb la configuració actual: backups al disc secundari (/dev/sdb) + fallback a /var/backups/P1/ al disc principal. La 3a còpia offsite és la pendent. Amb les 2 actuals, una fallada de disc sencera (_un_ dels dos) deixa una còpia intacta.

**Com gestionar una base de dades que s'està escrivint activament?**

Veure secció "Backup de bases de dades" a dalt. Per al nostre cas (sense BD activa en `\home`), `tar` de `/home` és segur.

---

## Reflexió

La lliçó crítica és que **un backup que no s'ha provat restaurar no és un backup — és una esperança**. El `verify_week5.sh` executa una restauració real en cada verificació, no únicament comprova que el fitxer existeix. Això és la diferència entre un pla de desastre i una il·lusió de pla de desastre.
