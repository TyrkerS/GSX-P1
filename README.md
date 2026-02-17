# Pràctica 1 --- Gestió de Sistemes i Xarxes

------------------------------------------------------------------------

##  Objectiu

Aquest projecte configura un servidor Debian de forma automatitzada

Tot el sistema es construeix mitjançant scripts.

------------------------------------------------------------------------

##  Requisits previs

-   VirtualBox instal·lat
-   ISO de Debian (amd64 netinst o full)
-   Connexió a Internet
-   Accés a terminal al sistema host (Linux o Windows amb SSH)

------------------------------------------------------------------------

##  Crear la màquina virtual

-   Nom: `debian-gsx`
-   2 GB RAM
-   1 CPU
-   Disc 20 GB (dinàmic)
-   Instal·lació **Unattended Install**
-   Usuari: `gsx`
-   Password coneguda
-   Hostname: `debian-gsx`

Finalitzar instal·lació.

------------------------------------------------------------------------

##  Configurar port forwarding (OBLIGATORI)

Amb la VM apagada:

1.  VirtualBox → Configuració
2.  Xarxa → Adaptador 1
3.  Mode: NAT
4.  Reenvío de puertos

Afegir:

  Nom   Protocol   Port host   Port convidat
  ----- ---------- ----------- ---------------
  SSH   TCP        2222        22

Això permet connectar des del host al servidor.

------------------------------------------------------------------------

##  Instal·lar i activar SSH dins la VM

 La instal·lació Unattended no instal·la OpenSSH ni afegeix al usuari a sudo.

Caldrà entrar a la VM.

Convertir-se en root:

    su -

Després executar:

    apt update
    apt install openssh-server -y
    systemctl enable ssh
    systemctl start ssh

------------------------------------------------------------------------

##  Provar connexió des del sistema host

    ssh gsx@localhost -p 2222

Si demana password i entra → correcte.

------------------------------------------------------------------------

##  Generar clau SSH al host

    ssh-keygen

Acceptar opcions per defecte (ENTER a tot).

Copiar la clau al servidor:

    ssh-copy-id -p 2222 gsx@localhost

Provar connexió:

    ssh gsx@localhost -p 2222

------------------------------------------------------------------------

##  Enviar el repositori a la VM

    scp -P 2222 -r nom-repo gsx@localhost:/home/gsx/

------------------------------------------------------------------------

##  Executar configuració automatitzada

    ssh gsx@localhost -p 2222
    cd nom-repo/scripts
    su -
    ./setup_server.sh

Aquest script:

-   Instal·la paquets necessaris
-   Configura sudo
-   Endureix SSH
-   Crea estructura administrativa

------------------------------------------------------------------------

##  Verificar la configuració

    ./verify_setup.sh

Si retorna:

    === Verification Successful ===

i `echo $?` retorna `0`, la configuració és correcta.

------------------------------------------------------------------------

##  Executar backup

Com a root:

    ./backup.sh

Els backups es guarden a:

    /opt/P1/backups

------------------------------------------------------------------------

##  Estructura final del sistema

    /opt/P1/
        scripts/
        backups/
        logs/
        docs/

------------------------------------------------------------------------

##  Configuració de seguretat aplicada

El bootstrap aplica:

-   `PermitRootLogin no`
-   `PasswordAuthentication no`
-   `PubkeyAuthentication yes`
-   Usuari `gsx` dins del grup `sudo`

------------------------------------------------------------------------

##  Principis aplicats

-   Infraestructura com a codi
-   Idempotència
-   Principi de mínim privilegi
-   Automatització
-   Separació entre sistema base i configuració del projecte

------------------------------------------------------------------------

##  Flux complet resumit

1.  Crear VM (Unattended)
2.  Configurar port forwarding
3.  Instal·lar OpenSSH manualment
4.  Provar connexió SSH
5.  Generar i copiar clau
6.  Enviar repositori
7.  Executar `setup_server.sh` com a root
8.  Executar `verify_setup.sh`
9.  Executar `backup.sh`

------------------------------------------------------------------------

##  Resultat

El sistema queda:

-   Reproduïble
-   Segur
-   Automatitzat
