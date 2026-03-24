# Pràctica 1 --- Gestió de Sistemes i Xarxes

------------------------------------------------------------------------

##  Requisits previs

-   VirtualBox instal·lat
-   ISO Debian (amd64 netinst o full)
-   Connexió a Internet
-   Accés a terminal al sistema host

------------------------------------------------------------------------

##  Crear la màquina virtual

Configuració:

-   Nom: `debian-gsx`
-   2 GB RAM
-   1 CPU
-   Disc 1 (OS): 20 GB (dinàmic)
-   Disc 2 (Storage): 10 GB (dinàmic) — **CRÍTIC**: Aquest segon disc s'ha d'afegir físicament als paràmetres de *VirtualBox* en crear la màquina. Els scripts particionaran automàticament `/dev/sdb` per als Backups de la Setmana 5, però el hardware virtual ha d'existir prèviament o tot el sistema donarà error.
-   Instal·lació: **Unattended Install**
-   Usuari Principal: `gsx`
-   Password coneguda
-   Hostname: `debian-gsx`

Finalitzar instal·lació.

------------------------------------------------------------------------

##  Configurar port forwarding

Amb la VM apagada:

VirtualBox → Configuració → Xarxa → Adaptador 1

Mode: NAT\
Reenvío de puertos:

- **Nom**: SSH
- **Protocol**: TCP
- **Port host**: 22222
- **Port convidat**: 22

------------------------------------------------------------------------

##  Instal·lació mínima inicial (únic pas manual)

Entrar a la VM per consola i executar:

    su -
    apt update
    apt install -y git

Només es necessita Git per poder clonar el repositori.

------------------------------------------------------------------------

##  Clonar el repositori al servidor

    git clone https://github.com/TyrkerS/GSX-P1.git
    cd GSX-P1/scripts
    sudo bash ./setup_all.sh

Aquest script configura completament el sistema.

------------------------------------------------------------------------

##  Configuració aplicada pel bootstrap

### Hardening

-   Instal·lació de sudo
-   Usuari `gsx` afegit al grup sudo
-   Instal·lació i configuració d'OpenSSH
-   `PermitRootLogin no`
-   `PasswordAuthentication no`
-   `PubkeyAuthentication yes`
-   Canvi del port SSH a `22222`
-   Activació d'`unattended-upgrades`

### Estructura administrativa

    /opt/P1/
        scripts/
        docs/
        logs/

    /var/backups/P1/

    /etc/P1/

### Control de versions

-   Inicialització de Git dins `/opt/P1`
-   Creació de `.gitignore`
-   Primer commit: **Baseline administrative structure**

------------------------------------------------------------------------

##  Verificació del sistema

Executar:

    cd GSX-P1/scripts
    sudo bash ./verify_all.sh

El script comprova:

-   Estat del servei SSH
-   Port configurat correctament
-   Hardening aplicat
-   Usuari dins del grup sudo
-   Actualitzacions automàtiques actives
-   Estructura de directoris
-   Inicialització del repositori Git
-   Existència del baseline commit

Retorna:

-   `0` → Sistema correcte
-   `1` → Errors detectats

------------------------------------------------------------------------

##  Backup

El sistema fa còpies diàries automàtiques amb:

-   Preservació de permisos (`--preserve-permissions`, `--same-owner`)
-   Xifrat GPG AES-256 (fitxers `.tar.gz.gpg`)
-   Rotació: 7 còpies diàries + 4 setmanals
-   Execució via `p1-backup.timer` (systemd, `Persistent=true`)
-   Restauració: `scripts/Week_5_backup/restore.sh <fitxer> [destí]`

------------------------------------------------------------------------

##  Flux complet resumit

1.  Crear VM
2.  Configurar port forwarding
3.  Instal·lar Git
4.  Clonar repositori
5.  Executar `sudo bash ./setup_all.sh`
6.  Executar `sudo bash ./verify_all.sh`

Tot el sistema queda configurat automàticament des de la setmana 1 fins a la 5.

------------------------------------------------------------------------

## Documentació

| Fitxer | Contingut |
|--------|-----------|
| `docs/week1.md` | SSH, sudo, idempotència, flock, reflexió |
| `docs/week2.md` | Nginx, systemd, journald, observabilitat |
| `docs/week3.md` | Senyals, cgroups, diagnosi, troubleshooting |
| `docs/week4.md` | Usuaris, ACLs, PAM limits, entorn compartit |
| `docs/week5.md` | Storage, backup, xifrat, NFS, recovery |
| `docs/runbook.md` | **Operations runbook**: 7 procediments operatius |
| `docs/architecture.md` | **Arquitectura**: diagrames, decisions, escalabilitat |
| `docs/security_policy.md` | **Security Policy**: access rules, retenció de backup |

------------------------------------------------------------------------

## Principis aplicats

-   Infrastructure as Code
-   Idempotència
-   Principle of Least Privilege
-   Hardening per defecte
-   Separació clara entre sistema i projecte
-   Reproduïbilitat total
-   3-2-1 Backup principle
