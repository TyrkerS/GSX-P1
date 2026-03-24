# Operations Runbook — GreenDevCorp

> Document per als administradors del sistema. Procediments pas a pas per a les tasques operatives més comunes.
> Última actualització: Març 2026

---

## 1. Com afegir un nou developer

**Temps estimat: 5 minuts**

```bash
# 1. Crear l'usuari (genera contrasenya aleatòria)
sudo ./scripts/Week_4/setup_users.sh
# Si l'usuari ja existeix, el script el salta. Per crear un de nou individualment:
sudo useradd --create-home --gid greendevcorp --shell /bin/bash devNOU
PASS=$(tr -dc 'A-Za-z0-9!@#%^&*' < /dev/urandom | head -c 16)
echo "devNOU:$PASS" | sudo chpasswd
sudo chage -d 0 devNOU   # força canvi de contrasenya al primer login

# 2. Aplicar ACLs al nou usuari si necessita accés a shared/ (dev1/dev2 level)
sudo setfacl -m "u:devNOU:rwx" /home/greendevcorp/shared
sudo setfacl -d -m "u:devNOU:rwx" /home/greendevcorp/shared

# 3. Comunicar les credencials de forma segura (mai per email en clar)
echo "Usuari: devNOU | Contrasenya temporal: $PASS"

# 4. Verificar que tot és correcte
sudo ./scripts/Week_4/verify_setup.sh
```

---

## 2. Com revocar l'accés d'un developer que marxa

**Temps estimat: 3 minuts**

```bash
# 1. Bloquejar el compte immediatament (evita noves sessions)
sudo usermod --lock devNOU
sudo usermod --expiredate 1 devNOU   # data d'expiració al passat

# 2. Matar sessions actives
sudo pkill -u devNOU   # envia SIGTERM a tots els processos de l'usuari
sleep 5
sudo pkill -9 -u devNOU   # força si alguna segueix activa

# 3. Revocar claus SSH
sudo rm -f /home/devNOU/.ssh/authorized_keys

# 4. Eliminar o arxivar el compte (escollir una opció)
# Opció A: arxivar les dades i eliminar
sudo tar -czf /var/backups/P1/user_devNOU_$(date +%F).tar.gz /home/devNOU
sudo userdel --remove devNOU   # elimina home també

# Opció B: desactivar sense eliminar dades
sudo usermod --lock devNOU
sudo usermod --shell /sbin/nologin devNOU

# 5. Verificar
id devNOU   # ha de seguir existint si opció B, o donar error si opció A
```

---

## 3. Comprovar si els serveis estan actius

```bash
# Vista ràpida de tots els serveis rellevants
./scripts/Week_2/status-week2.sh

# Per servei individual:
systemctl status nginx
systemctl status p1-backup.service
systemctl status p1-backup.timer

# Timers actius i pròxima execució:
systemctl list-timers --all

# Logs dels últims 30 minuts:
journalctl --since "30 minutes ago" -p err
```

**Codis de sortida:**
- `active (running)` → OK
- `active (waiting)` → timer actiu, esperant execució → OK
- `inactive` → aturat manualment → verificar si és esperat
- `failed` → ha fallat → veure logs immediatament

---

## 4. Diagnosticar un sistema lent

```bash
# Pas 1: Snapshot general (càrrega, memòria, disc, CPU)
./scripts/Week_3/diagnose.sh snapshot

# Pas 2: Identificar el procés culpable
./scripts/Week_3/diagnose.sh top 10

# Pas 3: Inspeccionar el procés sospitós
./scripts/Week_3/diagnose.sh pid <PID>

# Pas 4: Accions correctores
# CPU alta → reduir prioritat:
sudo renice +10 -p <PID>

# Memòria alta → matar graciosament:
kill -SIGTERM <PID>
sleep 5
kill -SIGKILL <PID>   # si no ha mort

# Disc ple → netejar logs antics:
journalctl --vacuum-size=100M
df -h   # verificar

# I/O alta → identificar quin procés escriu:
sudo iotop -b -n 1 | head -20
```

---

## 5. Restaurar des d'un backup

**Temps estimat: 10-20 minuts**

```bash
# Pas 1: Identificar el backup a restaurar
ls -lht /mnt/storage/backups/

# Pas 2: Test de restauració (SEMPRE fer primer en directori alternatiu)
sudo ./scripts/Week_5_backup/restore.sh /mnt/storage/backups/backup_YYYY-MM-DD_HH-MM-SS.tar.gz.gpg /tmp/restore_test

# Pas 3: Verificar el contingut restaurat
ls -lR /tmp/restore_test
# Comprovar que els fitxers crítics hi són

# Pas 4: Restauració real (amb precaució)
# ATENCIÓ: només si el test ha estat satisfactori
sudo ./scripts/Week_5_backup/restore.sh /mnt/storage/backups/<fitxer> /

# Pas 5: Verificar el sistema
sudo ./scripts/Week_1/verify_setup.sh
sudo ./scripts/Week_2/verify_week2.sh
sudo ./scripts/Week_4/verify_setup.sh
```

**Si el servidor s'ha perdut completament:**
```bash
# 1. Crear nova VM des de zero (README.md)
# 2. Muntar el disc de backups (/dev/sdb → /mnt/storage)
# 3. Restaurar des del backup més recent
# 4. Executar tots els scripts de setup en ordre:
sudo ./scripts/Week_1/setup_server.sh --ssh-pubkey "$(cat ~/.ssh/id_ed25519.pub)"
sudo ./scripts/Week_2/week2_setup.sh
sudo ./scripts/Week_3/setup_week3.sh
sudo ./scripts/Week_4/setup_users.sh && sudo ./scripts/Week_4/setup_directories.sh
sudo ./scripts/Week_4/setup_acl.sh && sudo ./scripts/Week_4/setup_pam_limits.sh
sudo ./scripts/Week_4/setup_environment.sh
sudo ./scripts/Week_5_backup/setup_passphrase.sh
```

---

## 6. Guia de troubleshooting ràpid

- **SSH rebutjat**: Clau no instal·lada. Acció: `cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys`
- **Nginx no respon**: Servei caigut. Acció: `sudo systemctl restart nginx`
- **Backup no s'ha executat**: Timer inactiu. Acció: `sudo systemctl start p1-backup.timer`
- **Disco ple**: Logs o backups. Acció: `journalctl --vacuum-size=100M` + rotar backups
- **Usuari no pot accedir fitxer**: Permisos/ACL incorrectes. Acció: `getfacl <fitxer>` + `id <usuari>`
- **Servidor lent**: Procés runaway. Acció: `./scripts/Week_3/diagnose.sh snapshot`
- **Backup falla en restaurar**: Passphrase incorrecta. Acció: Verificar `/etc/backup.passphrase`

---

## 7. Procediments d'escalada

- **Servei caigut, auto-restart no funciona**: Reiniciar manualment → si persisteix, obrir incident
- **Disc >90% ple**: Netejar logs + notificar equip
- **Backup no executat >2 dies**: Executar manual + investigar causa
- **Compromís de seguretat sospitós**: Bloquejar accés extern (`ufw deny`) + notificar responsable
- **Pèrdua de dades**: Restaurar des de backup + documentar incident
