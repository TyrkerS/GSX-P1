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
-   Disc: 20 GB (dinàmic)
-   Instal·lació: **Unattended Install**
-   Usuari: `gsx`
-   Password coneguda
-   Hostname: `debian-gsx`

Finalitzar instal·lació.

------------------------------------------------------------------------

##  Configurar port forwarding

Amb la VM apagada:

VirtualBox → Configuració → Xarxa → Adaptador 1

Mode: NAT\
Reenvío de puertos:

  Nom   Protocol   Port host   Port convidat
  ----- ---------- ----------- ---------------
  SSH   TCP        2222        22

------------------------------------------------------------------------

##  Instal·lació mínima inicial (únic pas manual)

Entrar a la VM per consola i executar:

    su -
    apt update
    apt install -y git

Només es necessita Git per poder clonar el repositori.

------------------------------------------------------------------------

##  Clonar el repositori al servidor

    git clone https://github.com/usuari/GSX-P1.git
    cd GSX-P1/scripts
    ./bootstrap.sh

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

    ./verify_setup.sh

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

El sistema crea un directori dedicat:

    /var/backups/P1/

El script `backup.sh` empaqueta dades preservant permisos.

------------------------------------------------------------------------

##  Flux complet resumit

1.  Crear VM
2.  Configurar port forwarding
3.  Instal·lar Git
4.  Clonar repositori
5.  Executar `swtup_server.sh`
6.  Executar `verify_setup.sh`

Tot el sistema queda configurat automàticament.

------------------------------------------------------------------------

## 🧠 Principis aplicats

-   Infrastructure as Code
-   Idempotència
-   Principle of Least Privilege
-   Hardening per defecte
-   Separació clara entre sistema i projecte
-   Reproduïbilitat total
