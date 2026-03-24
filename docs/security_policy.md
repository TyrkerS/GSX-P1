# Política de Seguretat — GreenDevCorp

Aquest document estableix les normes, polítiques i procediments de seguretat obligatoris per a tota la infraestructura de GreenDevCorp.

---

## 1. Regles d'Accés i Autenticació

- **Privilegis de Mínim Accés**: Els usuaris només han de disposar dels permisos estrictament necessaris per fer la seva feina. Ningú (excepte `gsx` pel setup) té drets d'administrador per defecte.
- **Root Login Prohibit**: L'accés directe com a root via SSH està estrictament prohibit (`PermitRootLogin no`). Tot accés privilegiat s'ha de fer a través de `sudo` per garantir traçabilitat.
- **Claus SSH Obligatòries**: L'autenticació per contrasenya via SSH està deshabilitada (`PasswordAuthentication no`). Tots els usuaris han d'autenticar-se usant parells de claus assimètriques (preferiblement ED25519).
- **Gestió de Claus SSH**: Si un usuari perd la seva clau privada o sospita que ha estat compromesa, s'ha de notificar immediatament per eliminar-la de `authorized_keys`.
- **Contrasenyes Temporals**: Els nous usuaris reben una contrasenya aleatòria xifrada de 16 caràcters que caduca automàticament en el primer login obligant al canvi (`chage -d 0`).

---

## 2. Polítiques de Retenció i Backups (3-2-1)

- **Periodicitat**: Els backups es realitzen de forma automàtica i diària a la mitjanit.
- **Abast**: Es realitza un procés de **full backup** del directori `/home` de tots els usuaris per protegir el codi font i dades crítiques no replicables.
- **Xifratge Obligatori**: Tots els arxius de backup estan xifrats de forma simètrica amb GPG (algoritme AES-256). L'accés a l'arxiu tar.gz sencer sense la passphrase és impossible.
- **Retenció Local**: Es manté una pràctica de rotació — 7 còpies diàries i 4 còpies setmanals (als diumenges).
- **Aïllament**: El destí del backup ha de ser sempre un disc separat i independent `/dev/sdb` muntat a `/mnt/storage` per evitar problemes on la fallada de la partició principal n'esborri les dades.
- **Tercera Còpia (Pendent d'establir-se fora)**: D'acord amb la llei 3-2-1, els backups seran traspassats periòdicament a un servidor extern (ex: NFS compartit).

---

## 3. Gestió de Dades Sensibles i Passphrases

- **Passphrase de Backup**: La contrasenya (`/etc/backup.passphrase`) té establert chmod 600 i està owned pel root. 
- Aquesta clau mai no s'envia a cap repositori públic ni s'inclou al Git (`.gitignore` actiu). Cap altre usuari pot accedir a aquest fitxer.
- **Recuperació per Ransomware**: Com a prevenció, si un ransomware ataca o corromp el servidor i entra al `/home`, l'acció destructiva queda registrada gràcies als snapshots diaris i rotació de backup intacta (el software maliciós no tindria permisos de root per destruir la carpeta `/mnt/storage/backups` ni les còpies anteriors xifrades a menys que escali privilegis).

---

## 4. Polítiques de Serveis i Processos

- **Restricció de Recursos**: S'apliquen límits rígids via PAM per als developers:
    - Màxim 200 processos simultanis per evitar fork bombs.
    - Sessió de CPU lmitada a 120 minuts de càlcul (Hard).
    - Límits d'ús de RAM per unitats de servei aïllades amb `cgroups`.
- **Auditoria Permanent**: Qualsevol activitat feta pels serveis (`p1-backup`, `nginx`) queda emmagatzemada per sempre o dins del curs dels darrers 30 dies per `journald` assegurant l'anàlisi retrospectiu sense esgotar el disc dels servidors.

---

## 5. Cicle de Vida i Escalada d'Incidències

Tota fallada crítica ha de ser revisada seguint el troubleshooting del `runbook.md`. Cap servei base (ex: sistemes web) ha de ser operat amb intervenció manual si pot recaure la responsabilitat en `systemd` (`Restart=on-failure`). Les alertes s'han de revisar als *logs* emesos cada hora si cal.
