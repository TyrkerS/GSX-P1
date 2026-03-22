# Week 5 — Storage, Backup & Recovery

## Objectiu

Garantir que les dades de GreenDevCorp no es perden mai. Això implica:

- Afegir disc nou sense interrompre serveis
- Dissenyar una estratègia de backup que sobrevisqui fallades
- Verificar que els backups funcionen **abans** de necessitar-los
- Compartir emmagatzematge per xarxa (NFS)

---

## Arquitectura d'emmagatzematge

```
Servidor principal
├── /          (disc OS, 20 GB, /dev/sda)
└── /mnt/storage   (disc dades, 10 GB, /dev/sdb1, UUID en fstab)
    └── backups/
        ├── backup_2026-03-19_10-00-00.tar.gz.gpg   ← encriptat
        ├── backup_2026-03-18_10-00-00.tar.gz.gpg
        │   ... (màx 7 còpies diàries)
        └── weekly/
            ├── backup_2026-03-15_10-00-00.tar.gz.gpg
            │   ... (màx 4 còpies setmanals, cada diumenge)
```

**Per què UUID i no `/dev/sdb1`?**
Els noms de dispositiu poden canviar en arrencar si s'afegeixen més discos. UUID és permanent i identifica inequívocament la partició.

---

## Estratègia de backup

### Principi 3-2-1 aplicat

| Còpies | Suports | Offsite |
|--------|---------|---------|
| 3 còpies | Disc OS + disc /mnt/storage + NFS client VM | NFS client (VM diferent) |

### Política de retenció

- **7 còpies diàries**: Es fa backup cada dia. Es conserven els últims 7.
- **4 còpies setmanals**: Cada diumenge, la còpia del dia es guarda a `weekly/`. Es conserven les últimes 4.

**Per què full backup i no incremental?**
Per a la mida de dades d'un startup petit, el full backup és més simple, més ràpid de restaurar i no requereix cadena de dependències. Un incremental tindria sentit si la font superés els 50-100 GB.

### RTO i RPO

- **RPO (pèrdua màxima de dades acceptable)**: 24 hores (una còpia diària)
- **RTO (temps màxim de recuperació)**: <30 minuts (desxifrar + descomprimir + verificar)

---

## Xifratge dels backups

S'utilitza **GPG simètric amb AES-256**. La passphrase es genera aleatòriament i s'emmagatzema a `/etc/backup.passphrase` (propietat de root, permisos 600).

**Per què xifratge?**
Les còpies estan fora del control directe del sistema principal (p.ex. NFS client VM). Si algú accedeix al disc físic o a la VM client, les dades estarien exposades sense xifratge.

**Configuració inicial:**
```bash
sudo ./setup_passphrase.sh
```

> ⚠️ **Important**: Guardar la passphrase en un gestor de contrasenyes fora del servidor. Sense ella, els backups xifrats NO es poden restaurar.

---

## Scripts implementats

| Script | Funció |
|--------|--------|
| `setup_storage.sh` | Particiona, formata, munta i afegeix a fstab (idempotent) |
| `setup_passphrase.sh` | Genera i emmagatzema la passphrase de xifratge |
| `setup_nfs.sh server` | Configura NFS server per compartir backups (read-only) |
| `setup_nfs.sh client <ip>` | Munta el NFS de forma persistent al client |
| `backup.sh` | Fa el backup amb xifratge, `--preserve-permissions`, `--same-owner` i rotació |
| `restore.sh` | Restaura a directori alternatiu (suporta `.tar.gz` i `.tar.gz.gpg`) |
| `verify_week5.sh` | Verifica storage, xifratge, timer systemd i test de restauració |

---

## Automatització amb systemd

El backup s'executa automàticament via:
- **`p1-backup.service`**: executa `backup.sh` com a root, logs a journald
- **`p1-backup.timer`**: dispara el servei cada dia (`OnCalendar=daily`, `Persistent=true`)

`Persistent=true` garanteix que si el sistema estava apagat a l'hora programada, el backup s'executarà en tornar a arrencar.

**Verificació:**
```bash
systemctl list-timers p1-backup.timer
journalctl -u p1-backup.service --since "yesterday"
```

---

## NFS (compartició de backups per xarxa)

L'script `setup_nfs.sh` configura el servidor principal com a NFS server i una VM client (snapshot de la VM principal) com a NFS client.

La compartició és **read-only** des del client: segueix el principi de mínim privilegi.

```bash
# Al servidor:
sudo ./setup_nfs.sh server

# A la VM client (amb la IP del servidor):
sudo ./setup_nfs.sh client 10.0.2.15
```

---

## Procediment de restauració

### Test de restauració (verificació)
```bash
sudo ./restore.sh /mnt/storage/backups/backup_2026-03-19_10-00-00.tar.gz.gpg
```

### Restauració real en cas de desastre
```bash
# 1. Muntar el disc de backups (si no està muntat)
mount -a

# 2. Identificar el backup a restaurar
ls -lht /mnt/storage/backups/

# 3. Restaurar a localitat alternativa per verificar
sudo ./restore.sh /mnt/storage/backups/<fitxer> /tmp/restore_verify

# 4. Verificar contingut
ls -lR /tmp/restore_verify

# 5. Restaurar a localitat definitiva (amb cura!)
sudo ./restore.sh /mnt/storage/backups/<fitxer> /
```

**Temps estimat de recuperació**: 5-15 minuts per a dades de mida típica d'un equip de 4-10 persones.

---

## Respostes a les preguntes de l'enunciat

**Si fas backup de tots els fitxers cada nit, tindràs backups massius. Com reduiries l'overhead?**

Amb backups incrementals (rsync amb `--link-dest` o `duplicati`). El trade-off: la restauració és més complexa (cal la còpia base + tots els incrementals). Per a la mida actual, full backup és la solució correcta. A partir de ~50 GB s'hauria de reconsiderar.

**Si perds el servidor principal, pots restaurar des del backup? Ho has provat?**

Sí: `verify_week5.sh` fa una restauració real a `/tmp/restore_verify_$$` en cada execució i compta els fitxers restaurats. La restauració s'ha provat manualment amb `restore.sh`.

**Com es gestionaria un backup d'una base de dades activa?**

No es pot copiar el fitxer directament (dades inconsistents). Les opcions correctes:
- **PostgreSQL/MySQL**: `pg_dump` / `mysqldump` creen un snapshot consistent, llavors es fa backup del dump.
- **LVM snapshot**: Pausa les escriptures, fa snapshot, reprèn escriptures, fa backup del snapshot.

En GreenDevCorp (sense BD per ara), el backup de `/home` és suficient.

**Si una ubicació de backup es corromp, tens una altra còpia?**

Sí. El principi 3-2-1 aplica: disc OS (`/var/backups`), disc de dades (`/mnt/storage/backups`), i VM client NFS. Un ransomware o corrupció d'un dels tres no afecta els altres.
